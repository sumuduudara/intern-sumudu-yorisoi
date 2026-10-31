# Yorisoi Testing Commands

Run these commands in macOS Terminal. They use the existing root Flutter app.
Stop a running Flutter app with `q` or `Control+C` before starting another run.

## 1. Open the project directory

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
```

If dependencies have not been downloaded, or `pubspec.yaml` has changed, run:

```sh
flutter pub get
```

Keep the existing local `lib/firebase_options.dart`. Do not replace it or paste
its configuration values into Terminal commands.

## 2. Run the Home Screen preview on Chrome

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter run -d chrome --target lib/home_preview.dart --web-port 8879
```

This entrypoint opens Home without Firebase login. The microphone uses the real
speech-recognition service: allow microphone access and speak Japanese. Review
and edit the recognized text before submitting.

The analysis/loading screen is a UI preview. It stays visible until you press
「入力に戻る」; this preview does not call Gemini or recommend a Pet Room.

If port `8879` is already in use, stop the previous preview or use another port.

## 3. Open the iPhone Simulator

```sh
open -a Simulator
```

If no iPhone is running, select an installed iPhone in Simulator's
**File > Open Simulator** menu. Wait for it to boot before running Flutter.

## 4. List Flutter devices

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter devices
```

Find the booted iPhone Simulator and copy its device ID. Device IDs vary between
Macs; do not use the Chrome or macOS device ID for the next command.

## 5. Run Home / Voice Input on the iPhone Simulator

First run this block. At the prompt, paste the iPhone Simulator device ID from
`flutter devices`, then press Enter.

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
printf 'Paste the iPhone Simulator device ID, then press Enter: '
read -r YORISOI_IOS_DEVICE_ID
```

After entering the ID, run this command in the same Terminal tab:

```sh
flutter run -d "${YORISOI_IOS_DEVICE_ID:?An iPhone Simulator device ID is required}" --target lib/home_preview.dart
```

This uses the same Home preview as Chrome and does not require Firebase login.
Allow microphone and speech-recognition permissions when requested. Tap the
microphone to start/stop Japanese recognition, then check that the text appears
in the existing input field and remains editable after recognition finishes.
Existing typed text should be preserved.

Simulator behavior does not prove that voice input works on a physical iPhone
or Android device. Recognition availability depends on the OS/service and
environment; text input remains the fallback.

## 6. Run the Issue #9 live Firebase Gemini AI tests

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter test --no-pub --dart-define=RUN_LIVE_EMOTION=true test/emotion_analysis_live_test.dart --reporter expanded
```

Run `flutter pub get` first if dependencies are not ready. The existing local
`lib/firebase_options.dart`, a working Firebase AI configuration, and internet
access are required. This command makes real AI requests and uses the project's
available API quota; it does not change Firebase settings or enable billing.

The three existing examples check:

| Input | Expected main emotion |
| --- | --- |
| 今日はひとりで寂しいです | 寂しい |
| 明日のことが心配です | 不安 |
| 今日はとても楽しいです | 嬉しい |

Only Firebase Core's native bootstrap is replaced by a test host. The AI SDK,
network request, model response, and JSON validation are real. This is a host
test using the existing Web Firebase options, not a Chrome UI or native iOS
end-to-end test. Home's preview button does not run this service.

## 7. Run all Flutter tests

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter test --reporter expanded
```

This runs the root app's `test/` suite. The three live AI tests are skipped unless
`RUN_LIVE_EMOTION=true` is explicitly supplied. The local Firebase options file
is still needed because the live test file imports it, even when those tests
are skipped.

## 8. Run Flutter analysis

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter analyze
```

Analysis checks Dart code statically. It does not confirm microphone recognition,
real Firebase responses, or visual appearance. Read the actual command output
before reporting a test or analysis result as successful.
