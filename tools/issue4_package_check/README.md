# Issue #4 reproducible service test package

This is a standalone Dart/Flutter source package. Generate disposable platform
runners with the script below; no dependency on the author's temporary project.
No personal Firebase configuration, API secrets, recordings, or encoder binaries
are included. The old third-party audio has been replaced by an original tone.

## Mac prerequisites and fresh runner

Tested with **Flutter 3.47.5 stable / Dart 3.13.4**. Use that version for the
closest reproduction; the pubspec accepts newer compatible Dart 3.x. Install
Python 3.9+ and Chrome, then run `flutter doctor`. Native tests additionally require
Xcode/iOS tooling or Android tooling; follow Flutter's official installation
instructions. CocoaPods is required if your Flutter runner uses it. Dependencies
are pinned in pubspec/lock; no Firebase Storage dependency or billing setup.

From the repository root, choose a destination that does not exist:

```sh
python3 tools/issue4_package_check/tool/prepare_project.py /tmp/yorisoi_issue4_mine
cd /tmp/yorisoi_issue4_mine
flutter analyze
flutter test
python3 -B -m unittest discover -s test_python -v
```

The script invokes `flutter create --empty --platforms=android,ios,web`, copies
this package and runs `flutter pub get`. It refuses to overwrite an existing
destination. It supplies:

- Android `INTERNET`, `RECORD_AUDIO` and RecognitionService package visibility;
  minSdk 24, using Flutter's current compile/target SDK settings.
- iOS microphone and speech-recognition purpose strings, deployment target 15.0.
- Web runner. Voice/audio entrypoints need no Firebase initialization.

The generated Android ID is `dev.yorisoi.issue4.yorisoi_package_check` and the
iOS bundle ID is `dev.yorisoi.issue4.yorisoiPackageCheck`;
verify Android applicationId and iOS bundle ID in the generated project before
registering Firebase apps. Do not commit the disposable runner or generated
Firebase configuration. `lib/main.dart` is the non-secret Gemini UI entrypoint.

To run without Firebase, quit each run before starting another:

```sh
flutter run -d chrome -t lib/voice_test.dart
flutter run -d chrome -t lib/audio_test.dart
flutter devices
# Native device IDs are listed above. No emulator launch is required by setup.
flutter run -d DEVICE_ID -t lib/voice_test.dart
flutter run -d DEVICE_ID -t lib/audio_test.dart
```

Voice: press Start Japanese Voice, allow microphone/speech access if prompted,
then speak and record Status/Recognized. Web requests `ja-JP` directly; its locale
list is not a supported-language catalogue. Native selects installed Japanese.
Text input is the fallback when the OS/browser recognizer is unavailable.

Audio: Play MP3 loads the bundled original one-second 440 Hz tone. Use moderate
speaker volume. Record Playing/Completed or failure; hearability and native
playback must be assessed separately. Provenance is in [audio README](assets/audio/README.md).

## Firebase configuration (local only)

Use your own Firebase **Spark** test project. In Firebase Console → AI Services
→ AI Logic, complete the **Gemini Developer API** guided setup, not the billed
Agent Platform provider. Register apps matching your generated native IDs (and
a Web app if testing Gemini on Web). Obtain each app's Firebase client config
from the console/FlutterFire CLI. Do not put Gemini server API keys or service
account credentials in this app. Firebase client identifiers differ from server
secrets; keep even the client config local for this test package.

Create a JSON file **outside the repository**, e.g.
`~/yorisoi-config/android.local.json`, containing your app-specific values:

```json
{
  "FIREBASE_API_KEY": "YOUR_FIREBASE_CLIENT_API_KEY",
  "FIREBASE_APP_ID": "YOUR_REGISTERED_APP_ID",
  "FIREBASE_MESSAGING_SENDER_ID": "YOUR_PROJECT_NUMBER",
  "FIREBASE_PROJECT_ID": "YOUR_TEST_PROJECT_ID"
}
```

For iOS also supply `FIREBASE_IOS_BUNDLE_ID`; for Web supply
`FIREBASE_AUTH_DOMAIN` from its configuration. Use a separate JSON for each
platform. This implementation passes FirebaseOptions explicitly and does not
require committing google-services.json, GoogleService-Info.plist or
firebase_options.dart. Do not publish builds containing your local configuration.

```sh
flutter run -d DEVICE_ID -t lib/main.dart --dart-define-from-file="$HOME/yorisoi-config/android.local.json"
python3 tool/probe_gemini.py --config "$HOME/yorisoi-config/android.local.json"
flutter test test/gemini_sdk_live_test.dart --dart-define=RUN_LIVE_GEMINI=true --dart-define-from-file="$HOME/yorisoi-config/android.local.json"
```

Use the iOS/Web JSON for the matching device/browser. The live SDK test replaces
only the native Firebase Core bootstrap with a test host; HTTP/model response is
real. It is skipped by default and sends the fictional Japanese sentence only
when explicitly enabled. Run it alone (app_test's missing-config check expects
no runtime configuration). Expect `lonely` for
「今日は友達と会えなくて、とても寂しいです。」.

If App Check is enforced, register the appropriate debug provider/token for your
local native app, then add `--dart-define=ENABLE_APP_CHECK=true` to `flutter run`.
For Web configure reCAPTCHA and supply `RECAPTCHA_SITE_KEY` in local JSON.
Debug tokens are credentials: never commit them. The raw REST probe cannot
mint an App Check token; if required, supply a valid token only in the
`FIREBASE_APP_CHECK_TOKEN` environment variable. The host-substituted SDK test
cannot attest a native device, so use the real app for enforced native tests.
Do not disable security or enable billing to make a test pass. Production App
Check remains a separate verification task.

The former `genai config not found` error was resolved by initializing the
missing `generativeLanguageConfig` backend submessage. Model/provider were kept.
No repair is performed by these scripts. API enablement alone is not proof of
provider setup. Do not blindly reapply the historical repair to another project.
The probe now exits nonzero for HTTP/network/config/validation failures; PASS
requires HTTP 200, STOP, and a single valid `lonely` output. It never prints
keys, full raw responses, or backend errors that could echo credentials.

## Automated and experimental tests

`flutter test` runs offline widget/validation/locale tests. The live cloud test
is skipped by default. `dart_test.yaml` excludes the `experimental` tag, keeping
the historical browser asset-loading timeout out of the passing suite.
To investigate that optional harness explicitly:

```sh
flutter test --platform chrome --tags experimental --exclude-tags none test/audio_browser_test.dart
```

That command is not a passing check: the previous harness timed out while loading
rootBundle, separately from actual-app playback. No claim of a fix is made.
Use the real Flutter audio app for the replacement tone playback check.

## Verification history — October 13, 2026

| Item | Verified scope |
| --- | --- |
| Gemini REST / Dart SDK | PASS, HTTP 200 / 1 live test, `lonely` |
| Gemini Android Emulator / iOS Simulator | User-verified PASS, `lonely` |
| Chrome/macOS STT | User-verified exact spoken-content match, 「とても寂しいです。」 → 「とても寂しいです」 (punctuation excluded), `done` |
| iOS Simulator STT | User-verified PASS, `done`, 「今日はとても寂しいです」 |
| Previous third-party MP3, Chrome | Historical PASS, Playing → Completed; recording no longer included |
| Previous third-party MP3, iOS Simulator | Historical user-verified audible PASS; recording no longer included |
| Replacement original tone | Actual Flutter Web app in the in-app browser reached Completed (PASS for playback lifecycle); audible quality and iOS/Android tone playback unverified |
| Android STT / MP3 | No successful verification; STT previously timed out, MP3 not tested |

The historical iOS device was iPhone 18 Pro Simulator / iOS 27.0. These passes
are not physical-iPhone verification, all-eight-emotion accuracy, production
App Check, quota or end-to-end STT→Gemini→audio integration verification.
Historical results used the earlier harness; the new reproducible package's
checks must be distinguished from those results.

See [service policy](../../docs/api_service_policy.md) for backend history and
remaining scope. This relative link targets the repository copy of this package;
when using a disposable runner, read the policy in the original checkout.


## Checks performed on the packaged version

- Fresh runner preparation succeeded at `/tmp/yorisoi_issue4_pr_check`; Android
  and iOS permissions/minimum targets and bundled asset bytes checked.
- `flutter analyze`: no issues. `flutter test`: 5 passed, 1 live test skipped;
  experimental browser test excluded by tag.
- Python probe tests: 5 passed. Actual revised probe: HTTP 200 / lonely / exit 0.
- Packaged opt-in live SDK test: 1 passed / lonely using local config outside Git.
- Generated runner's Gemini Web entrypoint build succeeded (no local Firebase
  values supplied; compile check only, not Gemini Web runtime verification).
- Original tone regenerated twice with identical SHA-256 on this Mac. Actual
  Flutter Web audio app loaded and reached Completed in the in-app browser.
  This is independent of the old Chrome recording pass. No new native emulator
  was launched. New tone audible quality / iOS / Android remain unverified.

The fresh native project generation was exercised, but fresh Android/iOS builds
and production App Check were not tested. Existing native results above belong
to the previous test app. Emulator memory use was deliberately avoided.
