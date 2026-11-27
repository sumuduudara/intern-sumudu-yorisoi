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


## Issue #9 — Gemini Emotion Analysis

**Real Home → Gemini → Result demo (Chrome, developer-only):**

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter run --no-pub -d chrome --web-port 8879 --target lib/home_live.dart
```

This opens the existing Home with the real Firebase/Gemini analyzer, bypassing
login only for this developer entrypoint. Type Japanese and press
「気持ちを伝える」. Unlike `lib/home_preview.dart`, this calls the real AI.
Stop the previous server/app using port 8879 before launching it.

| Sample input | Expected result |
| --- | --- |
| 今日はひとりで寂しいです | Main emotion: 寂しい |
| 明日のことが心配です | Main emotion: 不安 |
| 今日はとても楽しいです | Main emotion: 嬉しい |
| Empty or whitespace-only input | 「今の気持ちを入力してください。」; no AI request |

These are expected classifications, not guaranteed deterministic AI output.
`secondary_emotion` is optional: a distinct Japanese category or `null`.
The result screen displays secondary only when present. Room/Story List
navigation is not implemented in this flow; returning to Home preserves input.

**Real Gemini host tests (three existing Japanese inputs, no browser):**

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter test --no-pub --concurrency=1 --reporter expanded \
  --dart-define=RUN_LIVE_EMOTION=true \
  test/emotion_analysis_live_test.dart
```

Uses the exact three sentences above and asserts their main emotions. The real
AI SDK/network/model are used; only native Firebase Core bootstrap is replaced
for the host runner. This consumes API quota. It does not prove that a mixed
emotion input produces a non-null secondary. Without the define, live tests skip.

**Automated regression tests (fakes; no real Gemini calls):**

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter test --no-pub --concurrency=1 --reporter expanded \
  test/emotion_analysis_result_test.dart \
  test/emotion_analysis_service_test.dart \
  test/firebase_emotion_model_test.dart \
  test/home_emotion_analysis_test.dart
```

Checks eight categories, required `main_emotion`, nullable/missing secondary,
JSON rejection, prompt/schema configuration, loading, errors and typed-result
navigation. Expected: all listed tests pass; fake tests are not live AI evidence.

## Issue #10 — Gemini Story Generation

**Real Japanese story generation: Terminal demo, not a Chrome screen.**
The actual file is **`tool/story_generation_demo.dart`**. Run it with
**`flutter test`**, not `dart run` or `flutter run`. It uses Flutter test/Core
host support while keeping the Gemini request real.

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter test --no-pub --concurrency=1 --reporter expanded \
  --dart-define=RUN_LIVE_STORY=true \
  --dart-define=STORY_EMOTION=lonely \
  --dart-define=STORY_PET=cat \
  tool/story_generation_demo.dart
```

Sample input: **lonely × cat** (寂しい × 猫). The demo reads Prompt v3 from
`docs/story_generation_prompt.md`, inserts the selected emotion/pet, and prints
the generated Japanese title, story body and metadata in Terminal.

Expected metadata:

```text
status: draft
human_approved: false
audio_status: not_generated
character_count: actual story-body character count
length_target_met: true if the body is 600–900 characters; otherwise false
```

The count excludes metadata and whitespace. Output is nondeterministic: do not
promise an exact story or character count. If the first validated draft is
outside 600–900 characters, at most ONE extra real generation is attempted
(maximum two requests). If length still fails, or retry fails, the output remains
an unapproved draft with warnings. A passing runner test asserts draft status;
it does **not** by itself prove the length target or human approval.

Only these approved pairs are accepted:

| `STORY_EMOTION` | `STORY_PET` |
| --- | --- |
| `sad`, `lonely` | `cat` |
| `anxious`, `stressed` | `rabbit` |
| `angry`, `happy` | `dog` |
| `calm`, `other` | `dolphin` |

This command generates content during development only. It does not publish,
write to Firestore, generate MP3s or change billing. It uses the current API
quota; do not repeatedly run it during the meeting. Without
`RUN_LIVE_STORY=true`, the demo test is skipped.

**Automated story-generation tests (fakes; no real Gemini calls):**

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter test --no-pub --concurrency=1 --reporter expanded \
  test/story_generation_service_test.dart \
  test/firebase_story_model_test.dart
```

Checks approved pairs, Prompt v3 substitution, JSON/safety validation,
body-length counting, the single-retry limit, retry failures and always-draft
output. Expected: tests pass without creating an actual story via the API.

## Issue #11 — Firestore Story Data Management

**Real Firebase Auth + Firestore read-only demo (open manually in Chrome):**

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter run --no-pub -d web-server --web-hostname localhost --web-port 8879 \
  --target lib/story_firestore_demo.dart
```

Open **http://localhost:8879** in the same browser profile/origin used for login.
Stop the previous app/server on port 8879 first. The `web-server` device lets you
use your existing Chrome profile instead of a new temporary browser profile.
Click 「認証と実Firestore接続を確認」. Only if the demo says you are not signed
in, use 「既存のログイン画面を開く」, log in with your existing account, and
reload the same URL after Home appears. Never paste credentials into commands.

Current sample: `storyLibraries/current` in `yorisoi-emotion-test`, default
database, with `publicationStatus: draft`, `language: ja-JP`,
`schemaVersion: yorisoi-story-data-v1`.

Expected successful result (also available as a safe `STORY_FIRESTORE_CHECK`
diagnostic in the console/debug output):

```text
authServerVerified: true
librarySource: server
libraryPath: storyLibraries/current
publicationStatus: draft
language: ja-JP
schemaVersion: yorisoi-story-data-v1
storyQueries: 0
storyCount: 0
outcome: draft_expected_empty
```

This real Chrome outcome was confirmed by the user on 2026-11-03. A draft
library correctly returns zero stories without querying `stories`; it is not a
connection failure. Published story retrieval, production composite-query/index
use and real MP3 playback remain unverified. **Do not change the library to
approved just to demonstrate this test.** Missing/invalid metadata now reports
specific safe diagnostics instead of confusing it with an Auth failure.

**Local JSON fixture demo (no Firebase, no real MP3):**

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
dart run tool/story_data_demo.dart happy
```

Sample: `happy` (嬉しい). Expected ordered IDs:
`happy_dog_002`, `happy_dog_001`, `happy_dog_003`. Shows matching eligible dogs
and excludes unrelated, inactive, draft, invalid and audio-unready records.
Approval/audio availability are explicitly simulated fixture values, not
production approval or real playback.

**Empty-result fixture example:**

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
dart run tool/story_data_demo.dart anxious
```

Sample: `anxious` (不安). Expected: 0 candidates and
「この気持ちの物語は準備中です。」. No unrelated emotion is substituted.

**Automated data/repository/demo tests (no live Firebase reads):**

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter test --no-pub --concurrency=1 --reporter expanded \
  test/story_data_test.dart \
  test/firestore_story_repository_test.dart \
  test/story_firestore_demo_test.dart
```

Checks model/JSON/Timestamp conversion, main-emotion filtering, up-to-three
ordering, approval/audio/draft gates, invalid metadata, error handling,
network-only fallback and demo Auth/busy-state recovery. Expected: tests pass.
These tests use fakes/test fixtures and do not prove production reads.

**Optional local Security Rules tests (Firestore emulator only, no mobile simulator):**
First-time test-tool dependencies live outside the repository:

```sh
npm install --prefix /tmp/yorisoi-firestore-rules-check --no-audit --no-fund \
  @firebase/rules-unit-testing@6.0.0 firebase@13.1.0
```

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
  JAVA_TOOL_OPTIONS='-Xmx256m -XX:ActiveProcessorCount=2' \
  NODE_PATH=/tmp/yorisoi-firestore-rules-check/node_modules \
  FIREBASE_EMULATORS_PATH=/tmp/yorisoi-firestore-rules-check/emulators \
  firebase emulators:exec --project demo-yorisoi-rules \
  --config firebase.story-rules-test.json --only firestore \
  'node --test tool/firestore_rules_test.cjs'
```

Uses this Mac's existing Android Studio JDK and Firebase CLI. The first run may
download the official emulator JAR. Test-only records are written solely to the
local `demo-yorisoi-rules` emulator, never the real Firebase project. Checks
allowed authenticated queries and denied unauthenticated/draft/client-write
cases. Expected for the current script: 26 tests pass; emulator shuts down.
This does not deploy rules/indexes or verify production indexes.

**Command verification note (2026-11-05):** file paths, entrypoints, define names,
fixture expectations and installed command prerequisites were checked against
the current repository. No live Gemini calls, browser runs, Firebase changes,
package installation or new test executions were performed for this documentation
update. Read the actual output before claiming a new test passed.
