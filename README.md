# Yorisoi

Yorisoiの**メインFlutterアプリはこのrepository root**に置きます。
最初に読むコードは [`lib/main.dart`](lib/main.dart) です。
`pubspec.yaml`は依存関係とassets、`android/`・`ios/`・`web/`は各platformのrunnerです。

このbranchはアプリ基盤と静的な起動画面を準備したものです。認証、感情入力・AI、
音声認識、story再生、Issue #5/#6の画面/機能はまだ実装していません。
テストprojectの成功をmain appへの統合成功として扱いません。

## Directory map

```text
.
├── lib/
│   ├── main.dart                         # entrypoint → runApp
│   ├── app/
│   │   ├── yorisoi_app.dart               # MaterialApp / startup screen
│   │   └── theme/app_theme.dart           # shared colors / typography
│   └── presentation/screens/
│       └── welcome_screen.dart           # static, responsive startup shell
├── pubspec.yaml                          # package name, SDK, dependencies, assets
├── pubspec.lock                          # resolved dependency versions
├── android/                              # Android runner / Gradle
├── ios/                                  # iOS runner / Xcode
├── web/                                  # browser bootstrap / manifest
├── test/app_startup_test.dart             # entrypoint and small-screen tests
├── assets/README.md                       # product asset origin/license policy
├── docs/app_spec.md                       # existing product specification
├── analysis_options.yaml                 # Dart lint configuration
├── .metadata                             # Flutter-managed project metadata
├── .gitignore                            # build output and local config exclusions
└── .github/                              # existing Issue / PR templates
```

`build/`、`.dart_tool/`、IDE設定、local signing/config filesは生成物で、commitしません。
今はruntime assetsを使用しません。実際のassetを追加した時にpubspecへ登録します。

## App startup

1. Flutterが`lib/main.dart`の`main()`を実行します。
2. `runApp(const YorisoiApp())`がwidget treeを作ります。
3. `YorisoiApp`がMaterialAppと共通themeを設定します。
4. `WelcomeScreen`にYorisoiの静的なwelcome textを表示します。

起動時のFirebase initialization、API呼び出し、録音、Storage accessはありません。
credentials、Firebase project、Billingなしで起動できます。
今後のservice統合は別の変更としてレビューし、secret/private configをcommitしません。

## Setup (Mac)

確認用SDKは **Flutter 3.47.5 stable / Dart 3.13.4**。
Flutter SDKとChromeを用意し、native実行時はXcode/Android SDK等を準備してください。
このREADMEがあるdirectoryで実行します（temporary runner生成は不要）。

```sh
flutter --version
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Flutter runを終了してから別deviceを起動してください。重いSimulatorはWeb開発時に不要です。

```sh
flutter devices
flutter run -d DEVICE_ID
# Emulatorを起動しない軽量なcompile確認:
flutter build web
```

Android minSdkは24、iOS deployment targetは15.0。
Native tooling・device signingは各Macで必要です。アプリIDは開発用の
`dev.yorisoi.yorisoi` / `dev.yorisoi.yorisoi`（Android/iOS）で、公開用IDと署名は未決定。
生成templateのdebug signingはストア公開用ではありません。
Web runnerは開発確認用で、MVPの正式対応platform追加を決定するものではありません。

## Existing verification projects (not the main app)

PR #22/#23は2026年10月15日にdevelopへマージ済みです。
このfoundation branchはマージ前のdevelopをベースにしているため、
検証用projectの取り込みはまだ行っていません。

| Purpose | Code / instructions | PR |
| --- | --- | --- |
| Issue #3: development environment / 8 SDK compile sample | [examples/flutter_setup_check on feature/flutter-setup](https://github.com/sumuduudara/intern-sumudu-yorisoi/tree/feature/flutter-setup/examples/flutter_setup_check) | [#22](https://github.com/sumuduudara/intern-sumudu-yorisoi/pull/22) |
| Issue #4: Gemini / STT / asset MP3 verification | [tools/issue4_package_check on feature/api-service-policy](https://github.com/sumuduudara/intern-sumudu-yorisoi/tree/feature/api-service-policy/tools/issue4_package_check) | [#23](https://github.com/sumuduudara/intern-sumudu-yorisoi/pull/23) |

これらは検証専用projectです。main appとは異なるentrypoint/pubspecを持ち、
各READMEの手順で実行します。PR #22/#23はdevelopにマージ済みです。
このfoundationの作業では検証用projectの移動や統合は行っていません。

Issue #3のJapanese Material UI検証とSDK/platform条件、Issue #4のconfig分離方針は
参照しました。固定promptを使う検証画面、test tone、native未検証のservice codeを
製品画面としてコピーせず、main appのservice dependenciesは統合承認後に追加します。

## Security and scope

- personal Firebase config、API/server keys、service-account JSON、debug tokensはcommitしない。
- Firebase client configが必要になった場合もlocal configurationとして管理する。
- Billingは有効化しない。現在のmain appにFirebase dependencyはない。
- Issue #2の仕様、PR #22/#23の内容とbranch、既存のuncommitted editsは変更しない。
- このbranchのcommit/push/新PRは、構成レビューと承認後に行う。

## Verification status

2026年10月14日、Flutter 3.47.5 / Dart 3.13.4でこのroot appに対して実行：

| Check | Result |
| --- | --- |
| `flutter pub get` | PASS |
| `flutter analyze` | No issues found |
| `flutter test` | 2 passed（実entrypointの起動、320×480 / 2×文字サイズのoverflowなし） |
| `flutter build web` | PASS（`build/web`、Web release compile） |

最初のbuildで出たCupertino font不足warningは、標準の`cupertino_icons` dependency追加で解消。
Android/iOSの今回のnative build・実機/Simulator動作は未検証。Emulatorは起動していません。
以前のtest projectsのPASSをこのroot appのnative/service動作確認として流用しません。
root analyzerは独立verification packagesの`examples/**` / `tools/**`を除外します。
将来merge後も、それらは各packageのREADMEに従って別途解析・テストしてください。
