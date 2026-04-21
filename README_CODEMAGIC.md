# Codemagic Setup Guide for PetTrack

This guide walks through connecting this repo to Codemagic and running your first iOS builds — first the unsigned simulator build (moment-of-truth), then the signed TestFlight build.

**Why Codemagic?** Local iOS builds on this Mac are blocked by a macOS Sequoia 15.5 codesign bug (`com.apple.provenance` xattr — see `SEQUOIA_XATTR_FIX.md`). Codemagic's managed Xcode 16.x runners don't exhibit that bug in practice (cleaner file environment, no accumulated provenance tags), so we build iOS there and use TestFlight for device testing.

---

## Prerequisites

- [x] GitHub account (you'll log into Codemagic with it)
- [x] The PetTrack repo pushed to GitHub (public or private)
- [ ] Apple Developer Program membership ($99/year) — required ONLY for TestFlight. The simulator workflow needs nothing.
- [ ] Access to [App Store Connect](https://appstoreconnect.apple.com) — same account as your Developer Program membership

---

## Part 1 — Sign up and connect the repo (~5 min)

### 1.1 Create the Codemagic account

1. Go to [codemagic.io](https://codemagic.io) and click **Sign up**.
2. Choose **Sign up with GitHub**.
3. On the GitHub authorization screen, click **Authorize codemagic-ci-cd**. Grant access to your repositories (you can choose "Only select repositories" and pick just `pettrack`, or grant access to all — up to you).
4. You'll land on the Codemagic dashboard.

### 1.2 Add the PetTrack application

1. On the dashboard, click **Add application**.
2. Select **GitHub** as the Git provider.
3. Pick the `pettrack` repository from the list. If you don't see it, click **Missing a repository?** and re-check the GitHub authorization scope.
4. When asked about the project type, select **Flutter App (via `codemagic.yaml`)**. **Do NOT** pick "Flutter Workflow Editor" — our YAML is checked in, we don't want to override it.
5. Click **Finish: Add application**.

Codemagic will read `codemagic.yaml` from the repo root and show the three workflows: `ios-simulator-debug`, `ios-testflight`, `android-debug`.

---

## Part 2 — Run the first iOS Simulator build (moment of truth, ~10 min)

This build **requires no credentials**. It's the test that tells us whether our Flutter + CocoaPods setup is clean on a vanilla CI environment.

1. In the Codemagic dashboard, open the PetTrack app.
2. Click **Start new build** (top right).
3. Choose:
   - **Branch:** `main`
   - **Workflow:** `ios-simulator-debug`
4. Click **Start new build**.

Watch the logs in real time. Expected duration: 5–10 min on a cold runner.

**If it succeeds:** 🎉 The pipeline is working. Move to Part 3.

**If it fails:** See the Troubleshooting section at the bottom.

---

## Part 3 — Set up App Store Connect for TestFlight (~20 min one-time)

This is the part with the most moving pieces. Take it slow.

### 3.1 Create the app listing in App Store Connect

You must register the app before TestFlight will accept builds for it.

1. Go to [App Store Connect → Apps](https://appstoreconnect.apple.com/apps).
2. Click the **+** button → **New App**.
3. Fill in:
   - **Platforms:** iOS
   - **Name:** PetTrack (or whatever display name you want)
   - **Primary Language:** Spanish (Colombia) or English — your choice
   - **Bundle ID:** `co.pettrack.pettrackApp`  
     ⚠️ If this bundle ID doesn't appear in the dropdown, you first need to register it in the [Apple Developer Portal → Identifiers](https://developer.apple.com/account/resources/identifiers/list). Click **+**, pick App IDs → App, description "PetTrack", Bundle ID `co.pettrack.pettrackApp` (explicit). Enable Push Notifications capability.
   - **SKU:** `pettrack-colombia` (any unique internal string)
   - **User Access:** Full Access
4. Click **Create**.

After creation, note the **Apple ID** shown on the App Information page. It's a 10-digit number like `6449123456`. **Copy this** — you'll paste it into Codemagic in a moment.

### 3.2 Generate an App Store Connect API key

Codemagic uses this to upload builds and auto-increment build numbers.

1. Go to [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api).
2. Click **Generate API Key** (or the **+** button).
3. Fill in:
   - **Name:** `Codemagic`
   - **Access:** `App Manager` (sufficient for TestFlight uploads; don't give Admin unless you want to)
4. Click **Generate**.
5. **Immediately download the `.p8` file** — Apple only lets you download it ONCE. If you lose it, you have to revoke and regenerate.
6. On the same page, copy these two values:
   - **Issuer ID** (a UUID at the top of the page, like `69a6de87-...`)
   - **Key ID** (a 10-char string next to your new key, like `ABCD123456`)

Apple's canonical docs for this: [Creating API Keys for App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi/creating_api_keys_for_app_store_connect_api).

### 3.3 Add the API key to Codemagic

1. In Codemagic, go to **Team settings** (top right, click your avatar) → **Integrations**.
2. Find **Developer Portal** → **App Store Connect** → **Connect**.
3. Fill in:
   - **Name:** `codemagic` ← must match the `integrations.app_store_connect: codemagic` value in `codemagic.yaml`. If you use a different name, update the YAML to match.
   - **Issuer ID:** paste from step 3.2
   - **Key ID:** paste from step 3.2
   - **API Key:** click upload, select the `.p8` file you downloaded
4. Click **Save**.

Codemagic will validate the key by pinging App Store Connect — you'll see a green check if it worked.

### 3.4 Set `APP_STORE_APPLE_ID` as an environment variable in Codemagic

Codemagic rejects empty-string env vars in committed YAML, so this value lives in the Codemagic UI instead. That's the cleaner path anyway — values that may change (or differ per environment) don't belong in committed YAML.

1. Codemagic dashboard → open the **PetTrack** app.
2. Click the **Environment variables** tab (in the sidebar or the app's settings).
3. Click **Add variable** and fill in:
   - **Variable name:** `APP_STORE_APPLE_ID`
   - **Variable value:** the 10-digit Apple ID you copied in step 3.1 (e.g. `6449123456`)
   - **Variable group:** leave default, or create a new group called `testflight` if you want to reuse it across workflows
   - **Secure:** unchecked (it's not a secret — it's a public app identifier)
4. Click **Add**.

The `ios-testflight` workflow will now pick it up automatically. If you skip this step, the build still works — it falls back to Codemagic's `$BUILD_NUMBER` for the build number instead of auto-incrementing from TestFlight. You can add the var later without changing any code.

---

## Part 4 — Run the first TestFlight build (~15 min)

1. Codemagic dashboard → PetTrack → **Start new build**.
2. Branch: `main`. Workflow: `ios-testflight`. Start.
3. Watch the logs. Expected stages:
   - `Set up code signing settings` — Codemagic auto-fetches or generates the distribution cert + provisioning profile
   - `Flutter pub get` / `pod install`
   - `Build signed IPA` — the long one (5–10 min)
   - `Publishing → App Store Connect` — uploads to TestFlight
4. On success, the IPA appears under Artifacts and TestFlight processing begins. TestFlight takes another 5–20 min on Apple's side to finish processing the build.

### Redeem on your iPhone

1. Install the **TestFlight** app on your iPhone (from the App Store).
2. Open TestFlight → Sign in with the same Apple ID that owns the App Store Connect account.
3. Under **Apps**, PetTrack will show up once Apple finishes processing. Tap **Install**.

If you want other people (co-founder, testers) to install, in App Store Connect → your app → TestFlight tab:
- Add internal testers (they must have App Store Connect access under your team), OR
- Create an external tester group and invite by email (requires a one-time Beta App Review from Apple, ~24h on the first build).

---

## Troubleshooting first-build failures

### `ios-simulator-debug` fails

| Symptom | Cause | Fix |
|---|---|---|
| `Unsupported Xcode version` / `No valid Xcode version found` | Codemagic deprecated the current 16.x minor | Update `xcode:` in `codemagic.yaml` to another Xcode 16.x option (16.0, 16.1, 16.3, 16.4) — check [Codemagic Xcode docs](https://docs.codemagic.io/specs/versions-macos/) for what's currently supported. Xcode 15.x is no longer available (Apple requires 16+ for App Store submissions since April 2025). |
| `flutter: command not found` | Version string wrong | Check `flutter: 3.41.3` is still available. `flutter: stable` is a safe fallback. |
| `pod install` hangs | CocoaPods CDN flake | Re-run the build. If it keeps failing, add `pod repo update` before `pod install` in the script. |
| Build succeeds but artifact missing | Simulator build produces `.app`, not `.ipa` — that's expected | Not a failure. The `build/ios/iphonesimulator/Runner.app` artifact is what you want. |

### `ios-testflight` fails

| Symptom | Cause | Fix |
|---|---|---|
| `No matching profiles found for bundle identifier "co.pettrack.pettrackApp"` | Bundle ID not registered in Apple Developer Portal, OR App Store Connect app not created | Repeat step 3.1. The bundle ID in `codemagic.yaml` must exactly match what you registered. |
| `Authentication failed` / `Invalid API key` | `.p8` file, Key ID, or Issuer ID pasted wrong | Re-check step 3.3. The Issuer ID is a UUID (with dashes), the Key ID is 10 chars (no dashes). |
| `distribution_type: app_store` but profile not found | Codemagic couldn't auto-generate a distribution profile | In Codemagic → app settings → **iOS code signing**, switch to manual signing and upload your own `.p12` certificate and `.mobileprovision` file. |
| `app-store-connect get-latest-app-store-build-number: no builds found` | First upload — nothing to increment from | Harmless. The script falls back to `$BUILD_NUMBER`. It uploads fine. |
| `Invalid build number: must be greater than previous` | Rebuilding with same version/build number | Delete the stuck draft in App Store Connect, or bump `--build-name=1.0.0` to `1.0.1`. |
| Upload succeeds but TestFlight says "Invalid Binary" | Usually a missing `ITSAppUsesNonExemptEncryption` in `Info.plist`, or missing push notification entitlement | Check the email App Store Connect sent — it names the exact issue. |

### Build takes >30 min

- Cold runners are slower. Back-to-back builds are much faster (Codemagic caches pods).
- Check `max_build_duration` — it's set to 120 min for `ios-testflight`. If you hit it, your build is probably stuck on codesigning — check logs for a hang.

### Codemagic says "Build limit reached"

- The free tier gives 500 build-minutes/month on macOS. An iOS release build uses ~15–20 min. You can run ~25 TestFlight builds/month free. After that, upgrade or wait for the quota to reset.

---

## Maintenance notes

- `codemagic.yaml` is checked into git. Any change you make in the Codemagic Web UI that's not reflected in the YAML will be **overwritten** on the next push. Treat the YAML as the source of truth.
- We run Xcode 16.x on Codemagic's Sequoia-based runners. Despite this matching Nicolás's local broken combo, Codemagic hasn't exhibited the `com.apple.provenance` xattr bug in practice — likely a cleaner build environment (fresh git clone, no DMG-origin xattrs, no accumulated provenance tags on the Flutter SDK cache). If the bug ever does appear on CI, port the patches from `SEQUOIA_XATTR_FIX.md` — start with an early `xattr -cr .` and `xattr -cr ~/.pub-cache` step at the top of the iOS workflows' scripts.
- The Flutter SDK patch (`native_assets_host.dart`) is **not in the repo** — it lives in the Flutter SDK install. Codemagic runs a fresh Flutter install on each build, so the patch doesn't travel. That's fine because CI hasn't needed it.
