# Android日本語音声入力：2026-10-31の詳細診断

## 現在の結論

**Android日本語音声認識は引き続きFAIL・未解決。音声→Share→実Gemini→結果の一連のAndroid試験も未完了。**
日本語モデルが未インストールという環境問題は確認して修正したが、その後の利用者による実発話でも認識結果は空だった。
このため、モデルのインストール成功を音声入力の成功として扱わない。利用者は現時点で実機Androidを用意できないと回答した。
Issue #10は開始しない。

## 対象と保護した範囲

- `emulator-5554`、Android 17 / API 37、arm64 Google APIs Play Store image。
- Emulator 37.2.12.0、`speech_to_text` 7.5.0、認識要求は`ja-JP`。
- 本体は既存の`lib/main.dart`。元のFigma、認証、Gemini、マイク画像/clip/色、音声の既存修正を変更しない。
- `lib/firebase_options.dart`、依存関係、Android/iOS設定、`docs/testing_commands.md`を保持。Git操作なし。
- Androidネイティブの診断APKとMac診断コードは`/tmp`内で作成した。別のFlutterプロジェクトや製品機能は追加していない。

## 1. 確認した環境問題と実際の修正

| 確認対象 | 修正前の実測 | 対応・修正後 |
| --- | --- | --- |
| host microphone forwarding | Emulatorの公式`getMicrophoneState`でON | reboot後もhost入力をONに設定 |
| Mac入力デバイス | MacBook Air内蔵マイク、muteなし、input gain約0.278 | デバイス/gainは変更しない |
| macOSのEmulatorマイク許可 | 利用者がONと確認 | 勝手に権限/TCC設定を変更しない |
| Android `RECORD_AUDIO` | Yorisoiに許可あり、foreground、録音は`not silenced`、system mic mute=false | manifest/権限コード変更なし |
| 認識サービス | Google `GoogleTTSRecognitionService`あり、初期化成功、`ja_JP`を一覧表示 | locale一覧だけではモデルの準備完了と判断しない |
| 日本語モデル | nativeログ`Failed to get language pack of required locale: error 13` | Google公式の51.53 MB日本語モデルをdownload/install |
| Android `checkRecognitionSupport` | installed=`[en-US]`、Japanese downloadable=true、installed=false、online=false | reboot後はinstalled=`[ja-JP, en-US]`、installedJapanese=trueを確認 |

### 日本語モデルの入手経路

リポジトリ外の小さなnative診断Activityから、Androidの`checkRecognitionSupport`と`triggerModelDownload`を呼んだ。
Google serviceのdownload確認画面は最初`Background activity launch blocked`で開かなかった。
内部・非exportedのsettings Activityへの直接起動は拒否され、その保護は回避していない。
次の公開download actionをforegroundで開いたところ、Googleの「Download 日本語（日本） update」「51.53 MB」の確認が表示された。
Downloadを選択し、nativeログで`Installation finished for ja-JP_v3059`と完全downloadを確認した。

```sh
/Users/sumuduudara/Library/Android/sdk/platform-tools/adb -s emulator-5554 shell am start \
  -a com.google.recognition.action.DOWNLOAD_LANGUAGE \
  -p com.google.android.tts \
  --es android.speech.extra.LANGUAGE ja-JP
```

これは今回のGoogle speech packageで確認した経路であり、他のメーカー/サービスに同じActivityがあるとは保証しない。
通常アプリへこの診断処理や依存関係を追加していない。Firebase設定・billingは変更しない。

## 2. モデル修正後の実際の発話結果

利用者にHomeの既存マイクから「今日はとても寂しいです」と話すよう依頼した。
利用者は引き続きうまく動かないと報告した。同時のnativeログでは次を確認した。

```text
RecognitionService#logStartListening: callingApp: dev.yorisoi.yorisoi, locale: ja-JP
Offline recognizer - start listening
RecognitionService#onMicrophoneOpened
Initialize Soda with language pack directory
Offline recognizer - start detection
Audio process finished, transcription completed.
#onResults empty final recognition results
Speech recognition error type NO_SPEECH_DETECTED with error code -1
```

- 日本語モデル取得エラーはこの試行では消えた。約5秒の録音を2回確認したが、認識した文章はない。
- microphone openや過去の音量callbackは、実際の日本語の波形が正しく届いた証拠にはならない。
- 現段階では**日本語音声がnative engineへ確実に届いているかは未確認**。Googleの無音判定だけからアプリ、ホスト入力、認識精度のどれか1つに断定しない。
- 元のAndroid短時間timer解除、native終了後の遅延イベント待ち、途中文字保持、実statusによる色解除は維持する。さらに秒数を増やす、自動再起動する、停止中もpinkを表示する変更はしない。
- 認識文章がないためShareへ偽の音声結果を渡していない。手入力のAI試験を音声end-to-endの代わりにしない。

## 3. Emulator自体の診断上の制限

### 音声注入APIのnative crash

macOSで「今日はとても寂しいです」の合成音声を2.38秒のlocal control WAVとして用意した。
Emulatorの公式・実験的な`injectAudio` APIで既知の音声を試したところ、Emulator process自体がSIGSEGVで終了した。
macOS crash reportの先頭symbolは次のとおり。

```text
EXC_BAD_ACCESS / SIGSEGV
audio_forwarder_enable
android::qemu::QemuAudioInputEngine::start
android::emulation::control::QemuAudioInputStream::QemuAudioInputStream
android::emulation::control::EmulatorControllerImpl::injectAudio
```

これはFlutter/Dart例外ではない。このcontrol音声がnative recognizerへ届いた、または認識されたとは報告しない。
同じ注入は再試行していない。既存AVDをwipeせずcold bootして、host microphoneをONへ戻した。
モデルのインストールとYorisoiの既存ログインが残り、Homeを再表示できたことを確認した。

### native PCM計測を阻んだAndroid systemの問題

Google認識処理と分離するため、録音内容を保存せず6秒のPCM sample数/RMS/peakだけを測るnative診断を用意した。
しかし診断APK更新時、Android 17の`PackageUpdateActivity`が「Updating...」で停止し、後に次のsystem serviceエラーが発生した。

```text
cmd: Failure calling service package: Broken pipe (32)
cmd: Can't find service: package
cmd: Can't find service: activity
```

PCM測定は完了していない。ゼロ波形、正常波形、正しい日本語が取得されたなどの測定結果を作らない。
この環境でnative診断/更新処理が不安定という証拠であり、通常の音声失敗の全原因がEmulatorにあると断定するものではない。
既存AVDのuserdata、Googleモデル、ログインを消す処理は行わない。

## 4. 自動テスト（今回実行）

- `flutter analyze --no-pub`：**No issues found**。
- `flutter test --no-pub --reporter expanded`：**276 PASS / 3 skipped**。
- skipは任意実行のライブAI tests。上記PASSは実Android音声の成功やvoice→実AIの証明ではない。
- 今回アプリソースを変更していない。既存の認証、音声状態、Chrome相当の最終結果補完、Gemini/画面、画像の回帰testsを含む。

## 5. 次の検証：実機Android

現時点では実機がないため、この確認がブロックしている。実機を用意できた時に実施する。

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter devices
flutter run -d <接続した実機Androidのdevice-ID>
```

1. USB debuggingを有効化し、Macからのdebug接続を実機で許可する。既存アカウントでログインし、Homeを開く。
2. 端末の日本語recognition modelとマイク許可を確認する。初回はOSの許可を選ぶ。英語へ無断切替しない。
3. マイクが実際のlistening状態になったら短く日本語を話し、同じボタンで停止する。
4. 実認識文章が既存欄に残ること、青/pinkの復帰、編集、連打抑止を確認する。
5. その認識文章を使ってShareし、実Geminiのloading→主感情/副感情の結果→Home復帰を確認する。認識文章・結果・実機環境・日時を記録する。
6. 無音、拒否、認識エラーでは文字入力へ戻ることも確認する。音声認識が失敗した試行を成功としない。

実機が用意できない場合の別案は、既存API 37 AVDを保持したまま、安定版API 34/35の別AVDを承認後に用意し、同時には起動せず比較すること。
今回は新しいAVD、system image download、Issue #10、Git操作を開始していない。
