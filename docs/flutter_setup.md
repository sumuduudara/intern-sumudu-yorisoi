# Yorisoi Flutter開発環境・採用ライブラリ仕様

## 1. 目的

YorisoiをiOS / Androidの両方で開発できるように、
Flutterの開発環境とMVPで採用するpackage・Firebaseサービスを定義する。

新しい開発者がこのドキュメントを確認することで、
必要なツールを判断し、同じ開発環境を構築できる状態を目標とする。

このドキュメントではpackageの固定バージョンは記載せず、
実装開始時にpub.devおよび公式ドキュメントで最新Stable版を確認する。

確認日: 2026-10-08

---

## 2. 対象プラットフォーム

Yorisoi MVPでは以下を対象とする。

- iOS
- Android

Flutterの現在のサポート範囲を基準として、
iOS 15以上、Android API 24以上を基本対象とする。

Web / Windows / macOS向けアプリはMVP対象外とする。

---

## 3. 開発環境

### OS

macOSを基本の開発環境とする。

### 必須ツール

- Flutter SDK（Stable channel）
- Dart SDK（Flutterに含まれるものを使用）
- VS Code
- Flutter Extension
- Dart Extension
- Git
- SourceTree
- Xcode
- iOS Simulator
- Android Studio
- Android SDK
- Android Emulator
- FlutterFire CLI
- Firebase CLI
- CocoaPods（Flutter pluginのiOS側依存関係で必要な場合）

### 環境確認

開発開始前に以下を実行する。

```bash
flutter --version
dart --version
flutter doctor -v
```

`flutter doctor -v` にiOS / Android開発を妨げるエラーがないことを確認する。

iOS確認にはXcode Simulator、
Android確認にはAndroid Emulatorまたは実機を使用する。

---

## 4. 採用package

### firebase_core

用途:
Firebaseの初期化。

理由:
Firebase Authentication、Firestore、Storage、AI Logicなど
他のFirebase機能をFlutterから利用するための基本package。

---

### firebase_auth

用途:
ユーザー登録・ログイン。

MVPでは以下を使用する。

- Email / Password登録
- Email / Passwordログイン
- ログアウト
- 認証状態確認

---

### firebase_ai

用途:
ユーザーが入力した文章の感情分析。

YorisoiではFirebase AI Logic経由でGemini APIを利用する候補とする。

入力例:

「今日は少し寂しくて、誰かの声を聞きたい」

出力例:

```json
{
  "main_emotion": "寂しい",
  "secondary_emotion": "悲しい"
}
```

モデル名は利用可能なモデルが変更される可能性があるため、
アプリ内に長期間固定せず、実装時に公式ドキュメントで確認する。

---

### firebase_app_check

用途:
FirebaseおよびFirebase AI Logicへの不正アクセス対策。

本番ではApp Checkを有効化する。

開発中のSimulator / Emulatorでは
Debug Providerを使用する。

本番用Provider候補:

- Android: Play Integrity
- iOS: App Attest / DeviceCheck

---

### speech_to_text

用途:
ホーム画面でユーザーの音声をテキストへ変換する。

Yorisoiでは長時間の連続録音ではなく、
「今の気持ち」を短く入力する用途で使用する。

ユーザーがマイク権限を拒否した場合は、
テキスト入力を使用できるようにする。

#### iOS

`Info.plist` に以下の権限説明が必要。

- NSSpeechRecognitionUsageDescription
- NSMicrophoneUsageDescription

#### Android

`AndroidManifest.xml` に以下を設定する。

- RECORD_AUDIO
- INTERNET

Androidのバージョンに応じて
Speech Recognition Serviceのqueries設定も確認する。

Bluetoothマイクを使用する場合は、
Androidバージョンに応じてBluetooth権限も確認する。

---

### cloud_firestore

用途:
アプリ内の構造化データを管理する。

保存候補:

- ユーザー設定
- ニックネーム
- Story metadata
- emotion
- petType
- title
- description
- audioPath
- duration
- isActive
- createdAt

ユーザーが入力した感情文章は、
MVPでは必要がない限り長期保存しない方針とする。

---

### firebase_storage

用途:
Pet Radio / Podcastで使用するMP3ファイルなどを保存する。

保存対象候補:

- Story MP3
- Pet image
- 必要なaudio asset

音声ファイル例:

```text
audio/sad/cat/sad_cat_001.mp3
audio/lonely/cat/lonely_cat_001.mp3
audio/anxious/rabbit/anxious_rabbit_001.mp3
```

FlutterアプリではStorage上のファイルを取得し、
再生可能なURLをjust_audioへ渡す。

注意:
Cloud Storage for Firebaseは現在Blazeプランが必要となるため、
Firebase project作成時にBilling設定と予算アラートを確認する。

---

### just_audio

用途:
Pet Radio / PodcastのMP3再生。

MVPで必要な機能:

- MP3読み込み
- Play
- Pause
- Seek
- 現在の再生位置取得
- 全体時間取得
- 再生終了検知

Firebase Storageから取得したURLを再生する。

---

## 5. package追加コマンド

Flutter project作成後、
project rootで以下を実行する。

```bash
flutter pub add firebase_core
flutter pub add firebase_auth
flutter pub add firebase_ai
flutter pub add firebase_app_check
flutter pub add speech_to_text
flutter pub add cloud_firestore
flutter pub add firebase_storage
flutter pub add just_audio
```

実行前に各packageの最新Stable版と
現在のFlutter SDKとの互換性を確認する。

追加後は以下を実行する。

```bash
flutter pub get
```

`pubspec.lock` をGit管理し、
チーム内で同じdependency versionを使用できるようにする。

---

## 6. Firebase初期設定

FlutterFire CLIを使用する。

FlutterFire CLIが未導入の場合:

```bash
dart pub global activate flutterfire_cli
```

Firebase projectとFlutter appを接続:

```bash
flutterfire configure
```

この処理でiOS / Androidを同じFirebase projectへ登録する。

生成された`firebase_options.dart`を使用して、
アプリ起動時にFirebaseを初期化する。

基本例:

```dart
WidgetsFlutterBinding.ensureInitialized();

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

Firebase初期化後にApp Checkを有効化する。

---

## 7. Yorisoi内の役割分担

```text
ユーザー
   ↓
Text / Voice入力
   ↓
speech_to_text
   ↓
入力文章
   ↓
firebase_ai
   ↓
感情カテゴリ
   ↓
cloud_firestoreからStory情報を取得
   ↓
firebase_storageからMP3を取得
   ↓
just_audioで再生
```

Firebase Authenticationは
ユーザー登録・ログイン状態の管理に使用する。

---

## 8. 感情分析AI

MVPでは以下の8カテゴリを使用する。

- 悲しい
- 寂しい
- 不安
- ストレス
- 怒り
- 嬉しい
- 安心
- その他

AIは診断を行わず、
入力文章から最も近いカテゴリを分類する。

基本Prompt:

```text
あなたはYorisoiの感情分類AIです。
次のユーザー文章を定義済み感情カテゴリから分類してください。
診断はせず、最も強い感情をmain_emotion、
必要ならsecondary_emotionとしてJSONのみ返してください。

ユーザー文章:{user_text}
```

---

## 9. セキュリティ方針

以下を必須とする。

- private API keyやservice account keyをGitHubへcommitしない
- Firebase Authenticationを使用する
- Firestore Security Rulesを設定する
- Storage Security Rulesを設定する
- Firebase App Checkを有効化する
- 本番環境でDebug App Check Providerを使用しない
- ユーザーの感情文章を不要に保存しない

Firebase client configurationはFlutterFire CLIで管理する。

秘密情報が必要な場合は
ソースコードへ直接記述しない。

---

## 10. Free / Paidについて

Flutter SDKおよび採用するFlutter package自体は、
基本的にライブラリ利用料金なしで使用できる。

ただしFirebase / Gemini APIは
利用量や選択するサービスによって料金が発生する可能性がある。

### Firebase AI Logic

Firebase AI Logic自体の利用料金とは別に、
使用するGemini APIのモデル・使用量によって料金が決まる。

Gemini Developer APIには
利用可能なFree Tierがあるが、
モデルや機能によってBillingが必要な場合がある。

### Cloud Storage for Firebase

Cloud Storage for Firebaseを利用するには
Blaze（従量課金）プランが必要。

無料利用枠が適用される場合でも、
Billing accountと予算アラートを設定して
想定外の費用を防ぐ。

本番公開前にFirebase Consoleで
最新料金・Quotaを再確認する。

---

## 11. エラー時の基本Fallback

音声入力が使用できない:
→ テキスト入力へ切り替える。

マイク権限が拒否された:
→ 権限が必要な理由を表示し、テキスト入力を提供する。

AI感情分析に失敗:
→ Retryを表示する。
→ 必要に応じて「その他」として処理する。

Firestore取得失敗:
→ Retry表示。

MP3取得失敗:
→ 再読み込みを表示する。

Audio再生失敗:
→ Playボタンを再度使用可能にし、エラーメッセージを表示する。

---

## 12. Version管理方針

package versionはこの仕様書へ固定値として書かず、
実装開始時に最新Stable版を確認する。

確認先:

- Flutter公式Documentation
- Firebase公式Documentation
- pub.dev

導入後は`pubspec.yaml`と`pubspec.lock`により
実際に使用したversionを管理する。

packageをupgradeする場合は、
iOS / Android両方で動作確認を行う。

---

## 13. 完了条件

Issue #3は以下を満たした時点で完了とする。

- Flutter Stable環境が定義されている
- iOS / Androidの開発ツールが定義されている
- 必要なFlutter packageが定義されている
- 各packageの用途が説明されている
- Firebase初期設定方法が定義されている
- iOS / Androidの音声権限が定義されている
- Storage / Firestore / AI / Audioの役割が明確になっている
- Free / Paidの注意事項が記載されている
- Securityの基本方針が記載されている
- package versionの管理方法が定義されている
- 新しい開発者がこのドキュメントを読んで同じ環境を構築できる

---

## 14. 開発環境の検証結果

確認日: 2026-10-09

### 14.1 検証環境

以下の環境で開発ツールの動作を確認した。

- OS: macOS 26.6.2（Apple Silicon）
- Flutter: Stable 3.47.5
- Dart: 3.13.4
- Xcode: 27.0
- CocoaPods: 1.17.0
- Homebrew: 7.0.8
- FlutterFire CLI: 1.4.1
- Firebase CLI: 15.32.1
- Android SDK Platform: 36 / 37
- Android SDK Build-Tools: 36.0.0
- Android NDK: 28.2.13676358

`flutter doctor -v` の実行結果:

```text
No issues found!
```

### 14.2 iOS Simulator確認

- Device: iPhone 18 Pro
- OS: iOS 27.0
- Simulator起動成功
- Home Screen表示確認

結果: 成功

### 14.3 Android Emulator確認

- Device: Medium Phone API 37.0
- OS: Android 17（API 37）
- Emulator起動成功
- Home Screen表示確認
- `flutter devices` で認識成功

結果: 成功

### 14.4 Flutter package依存関係検証

本番用Yorisoi repositoryとは別に、
一時的なFlutter projectを作成した。

検証用project:

`/tmp/yorisoi_package_check`

検証時のpackage version:

| Package | Version |
|---|---|
| firebase_core | 4.15.0 |
| firebase_auth | 6.7.0 |
| firebase_ai | 4.0.0 |
| firebase_app_check | 0.4.8 |
| speech_to_text | 7.5.0 |
| cloud_firestore | 6.10.0 |
| firebase_storage | 13.6.0 |
| just_audio | 0.10.6 |

8つのpackageの依存関係解決に成功した。

`flutter pub outdated` を実行し、
更新可能な間接依存関係などを確認した。

### 14.5 Flutter Static Analysis

検証用projectで以下を実行した。

```bash
flutter analyze
```

結果:

```text
No issues found!
```

### 14.6 Android Build Test

検証用projectで以下を実行した。

```bash
flutter build apk --debug
```

初回はSDK Managerの接続エラーで失敗した。

Android SDK Platform 36を追加し、
再実行した。

再実行時も一時的なGradle依存関係の
ダウンロードエラーが発生したが、
自動リトライ後にBuildが成功した。

結果:

```text
Built build/app/outputs/flutter-apk/app-debug.apk
```

結果: 成功

注意:
Kotlin Gradle Pluginの将来的な互換性警告が
表示されたため、package更新時に再確認する。

### 14.7 iOS Build Test

検証用projectで以下を実行した。

```bash
flutter build ios --simulator
```

Swift Package Managerの依存関係取得後、
Xcode Buildが成功した。

結果:

```text
Built build/ios/iphonesimulator/Runner.app
```

結果: 成功

### 14.8 Firebase CLI検証

以下のコマンドを確認した。

```bash
firebase --version
flutterfire --version
flutterfire configure --help
```

確認結果:

- Firebase CLI: 15.32.1
- FlutterFire CLI: 1.4.1
- FlutterFire configureのHelp表示成功

Firebase projectへの実際の接続は未実施。

### 14.9 未実施項目

以下は今後の実装段階で確認する。

- Firebase projectとの実際の接続
- Firebase Authenticationの動作
- Firestore / Storageの読み書き
- Firebase AI Logicによる感情分析
- 音声認識とマイク権限の動作
- MP3ファイルの取得と再生
- iOS / Androidでのアプリ機能動作

今回のBuild成功は検証用Flutter projectでの
コンパイル成功を示すものであり、
Yorisoiアプリ全体の動作を保証するものではない。

今後の実装Issueで段階的に検証する。
