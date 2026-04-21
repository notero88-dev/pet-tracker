# macOS Sequoia xattr Codesign Fix

## Problem

On **macOS Sequoia 15.5** with **Xcode 16.4** + **Flutter 3.41.3**, iOS builds fail with:

```
error: <path>/<framework>.framework: resource fork, Finder information,
or similar detritus not allowed
Command CodeSign failed with a nonzero exit code
```

### Root cause

macOS Sequoia attaches the extended attribute `com.apple.provenance` to newly-created files as a security mechanism. Apple's `codesign` tool refuses to sign any file carrying this xattr. The xattr cannot be removed reliably — even with root — because macOS re-applies it when files are copied or regenerated.

Flutter's iOS build pipeline codesigns many intermediate products (native_assets frameworks, Pod frameworks, embedded frameworks, the final app bundle), so codesign fails at multiple points during a single build.

---

## Patches applied

Listed in order of the build-time step they protect.

### 1. Flutter SDK patch — `native_assets_host.dart`

**File:** `/usr/local/share/flutter/packages/flutter_tools/lib/src/isolated/native_assets/macos/native_assets_host.dart`

**Change:** Added `xattr -cr <target>` before every call to `codesign` inside the `codesignDylib` function. This protects Flutter's internal `install_code_assets` step (which signs `build/native_assets/ios/<package>.framework`).

```dart
// macOS Sequoia fix: strip com.apple.provenance and other xattrs before codesign,
// otherwise codesign refuses with "resource fork, Finder information, or similar detritus not allowed".
await globals.processManager.run(<String>['xattr', '-cr', target.path]);
final codesignCommand = <String>[
  'codesign', ...
```

**⚠️ Will be lost on Flutter upgrade.** Re-apply after every `flutter upgrade` or Flutter SDK reinstall. The Flutter tool snapshot must also be invalidated:

```bash
rm -f /usr/local/share/flutter/bin/cache/flutter_tools.stamp \
      /usr/local/share/flutter/bin/cache/flutter_tools.snapshot
flutter --version   # rebuilds tool
```

---

### 2. Xcode project — `ios/Runner.xcodeproj/project.pbxproj`

#### 2a. Modified Flutter "Run Script" build phase (ID `9740EEB61CF901F6004384FC`)

**Change:** Strip xattrs from all source caches BEFORE `xcode_backend.sh build` runs (prevents Flutter from copying tagged files into `build/`), and AGAIN AFTER the build to clean newly-created frameworks before later Xcode phases touch them.

```bash
# BEFORE flutter build
xattr -cr "$FLUTTER_ROOT/bin/cache"
xattr -cr "$HOME/.pub-cache"
xattr -cr "${SRCROOT}/../build"
xattr -cr "${SRCROOT}/Pods"
/bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" build
FLUTTER_BUILD_RC=$?
# AFTER flutter build
xattr -cr "${SRCROOT}/../build"
exit $FLUTTER_BUILD_RC
```

#### 2b. Added new "Strip xattrs" build phase (ID `AA0000000000000000000001`)

**Position:** Between `Resources` and `Embed Frameworks` phases — runs right before Xcode copies & signs embedded frameworks.

```bash
xattr -cr "${SRCROOT}/../build"
xattr -cr "${SRCROOT}/Pods"
xattr -cr "${BUILT_PRODUCTS_DIR}"
xattr -cr "${TARGET_BUILD_DIR}"
xattr -cr "${CONFIGURATION_BUILD_DIR}"
```

---

### 3. Podfile — `ios/Podfile`

**Change:** Extended `post_install` hook to (a) patch CocoaPods' generated `*-frameworks.sh` scripts so each framework is xattr-stripped right before its codesign call, and (b) disable codesigning on all Pod targets (safe for simulator, and avoids Xcode's internal framework codesign step which we can't intercept).

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    # macOS Sequoia fix: disable codesigning on Pod frameworks
    target.build_configurations.each do |config|
      config.build_settings['CODE_SIGNING_ALLOWED']   = 'NO'
      config.build_settings['CODE_SIGNING_REQUIRED']  = 'NO'
      config.build_settings['CODE_SIGN_IDENTITY']     = ''
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = '-'
    end
  end

  # Patch CocoaPods frameworks.sh scripts to strip xattrs before codesign
  Dir.glob(File.join(File.dirname(__FILE__), 'Pods', 'Target Support Files', '*', '*-frameworks.sh')).each do |script|
    contents = File.read(script)
    unless contents.include?('# macOS Sequoia fix')
      patched = contents.sub(
        /(\s+)(local code_sign_cmd="\/usr\/bin\/codesign)/,
        "\\1# macOS Sequoia fix: strip com.apple.provenance before codesign\n\\1xattr -cr \"$1\" 2>/dev/null || true\n\\1\\2"
      )
      File.write(script, patched)
    end
  end
end
```

This patch is self-healing: every `pod install` re-applies the xattr strip to the regenerated `*-frameworks.sh` files.

---

## Status as of commit

- Flutter's internal `install_code_assets` codesign: ✅ patched (SDK + xcode_backend wrap)
- CocoaPods `Pods-Runner-frameworks.sh` embed-time codesign: ✅ patched via post_install
- Xcode's internal Pods framework codesign (simulator): ✅ disabled via `CODE_SIGNING_ALLOWED=NO`
- Xcode's final `Runner.app` codesign on device: ⚠️ **not yet reached** — local device builds still blocked in practice because we stopped before finishing an end-to-end run

## Known limitations

- **Flutter SDK patch is volatile.** Any `flutter upgrade`, SDK reinstall, or channel switch will revert it. Keep this document nearby.
- **Disabling Pod signing** is fine for simulator and debug builds but **App Store releases require signed frameworks**. Re-enable signing for `Release` configuration if/when archiving for TestFlight locally. (CI runners on older macOS versions avoid this entirely — see README recommendation to use Codemagic with a Sonoma runner.)
- **Tested on:** macOS 15.5 (Sequoia), Xcode 16.4 (16F6), Flutter 3.41.3, CocoaPods 1.16.2.

## Recommended alternative

Rather than fighting Sequoia locally, **build iOS artifacts on CI** (Codemagic, Xcode Cloud, GitHub Actions with `macos-14`/Sonoma). Those runners don't have the Sequoia provenance behavior and sign cleanly with no patches needed.
