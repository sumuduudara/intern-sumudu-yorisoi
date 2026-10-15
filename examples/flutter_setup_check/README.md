# Issue #3: Flutter開発環境チェックコード

レビュー対象は`lib/main.dart`（実行画面）、`lib/packages.dart`（選定した8 SDKの
型参照）、`test/setup_check_test.dart`、pubspec/lock、runner生成scriptです。
Flutter 3.47.5 stable / Dart 3.13.4で確認しました。

日本語テキスト入力と選定SDKのimport/compileを確認する小さなアプリです。
Firebase初期化、API通信、録音、音声再生、Storage操作は行いません。
API credentialsもBillingも不要です。Storageは候補のSDKとしてcompileするだけです。
Issue #4の感情分析/STT/MP3テストコードはこのPRに含めていません。

## 静的解析・widget tests（Simulator不要）

```sh
cd examples/flutter_setup_check
flutter pub get
flutter analyze
flutter test
```

## 実行用runner作成

MacにFlutterとPython 3.9+を用意し、`flutter doctor`で環境を確認してください。
元repositoryのrootから、まだ存在しないtemporary pathを指定します。

```sh
python3 examples/flutter_setup_check/tool/prepare_runner.py /tmp/yorisoi_issue3_mine
cd /tmp/yorisoi_issue3_mine
flutter run -d chrome
# iOS / Androidはflutter devicesで実際のIDを確認して指定:
flutter run -d DEVICE_ID
```

生成scriptはAndroid minSdk 24 / iOS deployment target 15.0を設定します。
実機/SimulatorビルドにはXcodeやAndroid SDK等が必要です。今回のappは録音を
使わないためmicrophone permissionsを追加しません。実音声機能を実装するときは
`docs/flutter_setup.md`のiOS purpose strings / Android RECORD_AUDIO・INTERNET・
RecognitionService queryを追加してください。
生成されたplatform projectはtemporary directoryに置き、Gitには含めません。
Webは軽量な開発確認用runnerであり、Yorisoi MVPの対象platform追加ではありません。

## 確認方法・範囲

アプリに「選定SDK: 8種類」が表示され、日本語を入力して「入力を確認」を押すと
同じ文章が表示されます。空入力には案内を表示します。
これらの成功はAPI接続/サービス動作の成功を意味しません。
以前のAndroid/iOSビルド結果は`docs/flutter_setup.md`の履歴に残し、今回の新しい
サンプルのnative build成功とは区別します。Simulator/Emulator起動は不要です。


## 2026年10月13日の実行結果

- `flutter pub get`：8 SDKを含む依存関係解決とlockfile生成に成功。
- `flutter analyze`：No issues found。
- `flutter test`：3 tests passed（8 SDK型参照、日本語入力、空入力案内）。
- READMEのfresh runner生成手順を新しいtemporary directoryで実行し成功。
- 生成runnerで`flutter build web`成功。Cupertino icon fontの不足warningは表示されたが、
  このサンプルはCupertino iconsを使用していない。ビルドエラーはない。
- Android/iOSの今回の新サンプルのnative build・実機動作は未検証。
  以前のtemporary projectのnative build成功を新サンプルのPASSとして流用しない。
