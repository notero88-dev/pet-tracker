import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/amplitude_service.dart';
import '../services/app_event_service.dart';
import '../services/firestore_service.dart';
import '../services/fcm_service.dart';
import '../services/provisioning_api.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();
  final FCMService _fcm = FCMService();

  /// Google Sign-In client. The OAuth scopes are the minimum needed to
  /// build a Firestore user profile from Google's id_token (email + name).
  /// `clientId` is omitted on iOS — the iOS plugin reads it from the
  /// REVERSED_CLIENT_ID URL scheme + GoogleService-Info.plist's CLIENT_ID
  /// at startup. On Android the plugin reads it from google-services.json.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
  );
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  User? get currentUser => _user; // Alias for compatibility
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<bool> checkAuthStatus() async {
    _user = _auth.currentUser;
    notifyListeners();
    return _user != null;
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = credential.user;

      if (_user != null) {
        AmplitudeService.instance.setUserId(_user!.uid);
        AmplitudeService.instance.track('User Signed In', properties: {
          'provider': 'email',
        });
      }

      // Fire-and-forget FCM init. Awaiting it deadlocks login on iOS release
      // builds when _messaging.getToken() hangs waiting for APN registration
      // that never completes (Petti/2026-05-06 incident — symptom: spinner
      // forever after Firebase Auth succeeds). FCM handlers are also wired
      // at app boot from main.dart so this re-init is best-effort.
      unawaited(_fcm.initialize());
      unawaited(AppEventService.fire('signed_in', metadata: {'provider': 'email'}));

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error inesperado. Inténtalo de nuevo.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await credential.user?.updateDisplayName(fullName);
      
      // Create Firestore profile
      if (credential.user != null) {
        await _firestore.saveUserProfile(
          userId: credential.user!.uid,
          email: email,
          displayName: fullName,
          phone: phone,
        );
      }
      
      _user = credential.user;

      if (_user != null) {
        AmplitudeService.instance.setUserId(_user!.uid);
        AmplitudeService.instance.track('User Signed Up', properties: {
          'provider': 'email',
        });
      }

      // Fire-and-forget — see signIn() for rationale.
      unawaited(_fcm.initialize());

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error inesperado. Inténtalo de nuevo.';
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Google via OAuth → Firebase Auth credential exchange.
  ///
  /// Flow:
  ///   1. `_googleSignIn.signIn()` opens Google's in-app account picker.
  ///      Returns null if the user cancels.
  ///   2. We pull the Google id_token + access_token from the chosen account.
  ///   3. Wrap them as a `GoogleAuthProvider` credential and pass to
  ///      Firebase Auth — this either creates a new Firebase user or signs
  ///      into an existing one matched by email.
  ///   4. On first-time sign-in, seed the Firestore user profile so the
  ///      rest of the app can read it like an email/password user.
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the OAuth sheet — not an error, just abort.
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      _user = userCredential.user;

      // First-time Google sign-in → seed Firestore profile so subsequent
      // reads (home screen, settings, etc.) find a user record. Skip on
      // subsequent sign-ins; profile is owned by the user from then on.
      if (userCredential.additionalUserInfo?.isNewUser == true &&
          _user != null) {
        await _firestore.saveUserProfile(
          userId: _user!.uid,
          email: _user!.email ?? googleUser.email,
          displayName: _user!.displayName ?? googleUser.displayName ?? '',
          phone: null,
        );
      }

      if (_user != null) {
        final isNew = userCredential.additionalUserInfo?.isNewUser == true;
        AmplitudeService.instance.setUserId(_user!.uid);
        AmplitudeService.instance.track(
          isNew ? 'User Signed Up' : 'User Signed In',
          properties: {'provider': 'google'},
        );
      }

      // Same fire-and-forget rationale as `signIn()` — avoid blocking on
      // FCM token registration which can hang on iOS release builds.
      unawaited(_fcm.initialize());
      unawaited(AppEventService.fire('signed_in', metadata: {'provider': 'google'}));

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'No pudimos completar el inicio con Google.';
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Apple via the native iOS ASAuthorizationController →
  /// Firebase Auth credential exchange.
  ///
  /// Apple's flow uses a one-time nonce to bind the OAuth response to
  /// THIS sign-in attempt (mitigates replay attacks). Pattern:
  ///   1. Generate a random raw nonce.
  ///   2. SHA-256 hash it. Pass the hash to Apple via `nonce:` (Apple
  ///      embeds it inside the signed identity token).
  ///   3. Pass the *raw* (un-hashed) nonce to Firebase via `rawNonce:` —
  ///      Firebase recomputes the hash and verifies it matches what's
  ///      inside Apple's id_token.
  ///
  /// Apple only returns the user's email + full name on the FIRST sign-in
  /// for a given Apple ID. Subsequent sign-ins only echo the user
  /// identifier, so we have to seed the Firestore profile on first use
  /// and rely on it from then on.
  Future<bool> signInWithApple() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final rawNonce = _generateNonce();
      final hashedNonce = _sha256Hex(rawNonce);

      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final OAuthCredential firebaseCred = OAuthProvider('apple.com').credential(
        idToken: appleCred.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(firebaseCred);
      _user = userCredential.user;

      // First-time Apple sign-in is the only time we see fullName / email
      // from Apple — seed Firestore now, otherwise the rest of the app
      // can't read a real display name.
      if (userCredential.additionalUserInfo?.isNewUser == true &&
          _user != null) {
        final fullName = [
          appleCred.givenName,
          appleCred.familyName,
        ].where((n) => n != null && n.isNotEmpty).join(' ');
        // Update Firebase user's display name (Apple's id_token doesn't set it).
        if (fullName.isNotEmpty) {
          await _user!.updateDisplayName(fullName);
        }
        await _firestore.saveUserProfile(
          userId: _user!.uid,
          email: _user!.email ?? appleCred.email ?? '',
          displayName: fullName.isNotEmpty
              ? fullName
              : (_user!.displayName ?? ''),
          phone: null,
        );
      }

      if (_user != null) {
        final isNew = userCredential.additionalUserInfo?.isNewUser == true;
        AmplitudeService.instance.setUserId(_user!.uid);
        AmplitudeService.instance.track(
          isNew ? 'User Signed Up' : 'User Signed In',
          properties: {'provider': 'apple'},
        );
      }

      unawaited(_fcm.initialize());
      unawaited(AppEventService.fire('signed_in', metadata: {'provider': 'apple'}));

      _isLoading = false;
      notifyListeners();
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      _isLoading = false;
      // Code 1000 = user canceled; treat as silent abort, not error.
      if (e.code == AuthorizationErrorCode.canceled) {
        notifyListeners();
        return false;
      }
      _errorMessage =
          'No pudimos completar el inicio con Apple (${e.code.name}).';
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'No pudimos completar el inicio con Apple.';
      notifyListeners();
      return false;
    }
  }

  /// 32-byte cryptographically random string used as the Apple Sign-In
  /// raw nonce. Hex-encoded so it survives URL encoding / Apple's payload.
  String _generateNonce({int length = 32}) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final rng = Random.secure();
    return List.generate(length, (_) => charset[rng.nextInt(charset.length)])
        .join();
  }

  String _sha256Hex(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.sendPasswordResetEmail(email: email);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error inesperado. Inténtalo de nuevo.';
      notifyListeners();
      return false;
    }
  }

  /// Delete the currently-signed-in user's account end-to-end:
  ///
  ///   1. Reauthenticate with the supplied password (Firebase requires
  ///      recent auth before `currentUser.delete()` — otherwise it
  ///      throws `requires-recent-login`). This also catches the wrong-
  ///      password case before we touch the server.
  ///   2. Call the backend `DELETE /api/users/me` which cascades
  ///      Postgres soft-delete + Traccar user delete + Firebase Auth
  ///      delete.
  ///   3. Sign out locally so the app drops to login.
  ///
  /// Returns null on success, a Spanish error message on failure
  /// (intended to be shown directly in the confirm dialog).
  Future<String?> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return 'No hay sesión activa.';
    }
    final email = user.email!;

    // 1) Reauthenticate.
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (_) {
      return 'No pudimos verificar tu contraseña. Inténtalo de nuevo.';
    }

    // 2) Backend cascade. The backend also calls Firebase Admin to
    //    delete the user, so by the time this returns the Firebase
    //    session is already invalid. We don't ALSO call
    //    `user.delete()` from the client because that would race
    //    the server-side deletion.
    try {
      final api = ProvisioningApi();
      final ok = await api.deleteAccount();
      if (!ok) {
        return 'No pudimos eliminar tu cuenta. Escríbenos a soporte@mybesti.co.';
      }
    } catch (e) {
      return 'Error de conexión. Inténtalo de nuevo.';
    }

    // 3) Local sign-out — the Firebase session is invalid anyway,
    //    but this ensures the app's auth state stream emits null
    //    so navigation drops back to the login screen.
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}
    _user = null;
    notifyListeners();
    return null;
  }

  Future<void> signOut() async {
    // Sign out of Google too so the next "Iniciar con Google" tap shows
    // the account picker again instead of silently re-auth'ing the same
    // Google account. Errors here don't matter — even if Google sign-out
    // fails, the Firebase sign-out is what gates app access.
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
    AmplitudeService.instance.reset();
    _user = null;
    notifyListeners();
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No se encontró una cuenta con este correo.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este correo.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'invalid-email':
        return 'Correo electrónico inválido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido desactivada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde.';
      default:
        return 'Error de autenticación. Inténtalo de nuevo.';
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
