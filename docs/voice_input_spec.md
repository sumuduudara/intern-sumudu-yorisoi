# Issue #8 音声入力機能の仕様

## 1. 目的・対象・成果物

利用者が「今日はどんな気分ですか？」への短い回答を話し、認識した日本語を確認・修正してから、感情分析へ渡せるようにする。

- 要件：[Issue #8「音声入力機能の仕様作成」](https://github.com/sumuduudara/intern-sumudu-yorisoi/issues/8)。2026-10-22にGitHub APIから本文と達成目標を確認した。
- 関連仕様：[`app_spec.md`](app_spec.md)、[`home_emotion_screen_spec.md`](home_emotion_screen_spec.md)、サービス選定・実験履歴：[`api_service_policy.md`](api_service_policy.md)。
- **元のIssue #8の成果物は仕様書。追加依頼により、2026-10-22に本体Homeへ音声認識コードとnative権限設定を追加した。** コード・偽サービスによる自動テストと、実際の端末での認識成功は区別する。本体のライブ音声テストはまだ未確認。
- Flutterの **`speech_to_text` を第一候補** とし、iOS / Androidの端末音声認識を使う。独自の録音・音声アップロードサービスは追加しない。
- 音声入力は任意。音声が使えなくても、既存のテキスト入力と手動送信を継続できる。

## 2. 現在の実装と接続する場所

| 現在のファイル | 確認した状態・将来の接続点 |
| --- | --- |
| [`home_screen.dart`](../lib/presentation/screens/home_screen.dart) | 同じ入力controllerへ認識結果を反映。マイクの開始・停止、状態表示、背景移行・設定・画面離脱時の取消を接続 |
| [`feeling_input_view.dart`](../lib/presentation/widgets/home/feeling_input_view.dart) | 元の`home-microphone`画像・位置を保持。同じ欄に結果を表示し、聞き取り中だけ編集と送信を抑止 |
| [`analysis_loading_view.dart`](../lib/presentation/widgets/home/analysis_loading_view.dart) | 分析中のUI。音声の聞き取り中画面として流用しない |
| [`pubspec.yaml`](../pubspec.yaml) | 本体へ`speech_to_text: 7.5.0`を固定で追加 |
| [`AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml) | `RECORD_AUDIO`、`INTERNET`、認識サービスqueryを追加。nativeビルド・実機未確認 |
| [`Info.plist`](../ios/Runner/Info.plist) | マイク・音声認識の日本語利用目的を追加。nativeビルド・実機未確認 |
| [`voice_test.dart`](../tools/issue4_package_check/lib/voice_test.dart) | Issue #4の独立実験。Homeには接続されていない。20秒の短い認識、日本語locale選択を試している |
| [`voice_locale_test.dart`](../tools/issue4_package_check/test/voice_locale_test.dart) | locale選択の純粋なテスト。マイクや認識精度を検証するテストではない |

Issue #4実験は`speech_to_text: 7.5.0`を使用する。実験の依存関係や画面を本体へ丸ごとコピーしない。
本体では[`speech_to_text_service.dart`](../lib/services/voice/speech_to_text_service.dart)に音声APIと日本語locale・エラー文を分離した。
[`voice_input_controller.dart`](../lib/presentation/controllers/voice_input_controller.dart)が元の入力・認識状態・短時間タイマー・古いcallbackの無効化を管理する。
Homeは既存の入力controllerを渡す。Firebase認証サービスは変更しない。

## 3. デザインを変えない操作仕様

原本Figmaの`03 - Home / Feeling Input`とIssue #7のCSS参照を維持する。
背景・ペット・ロゴ・書体・配置・入力カード・送信ボタン・設定アイコンは変更しない。
マイクは現在の原本画像、54 × 54、色`#7E9BCB`を維持し、新しいボタンや別のイラストへ置換しない。

| 状態 | 同じマイクボタンの動作 | 入力欄・送信 |
| --- | --- | --- |
| 待機 | 押すと利用可否と権限を確認し、日本語認識を開始 | テキスト編集・手動送信が可能 |
| 初期化・権限確認中 | 連打による重複開始を受け付けない | 既存テキストを保持。分析送信は開始しない |
| 聞き取り中 | もう一度押すと`stop()`で停止し、最終結果を待つ | 同じ欄に認識途中の文を仮表示。上書き競合を防ぐため編集・送信を一時停止 |
| 停止・結果待ち | 重複操作を受け付けない | 入力を保持し、終了を待つ |
| 終了・失敗 | 再度押すと、利用可能なら新しい1回の認識 | 編集と手動送信へ戻る |
| 分析中・ログアウト中 | 認識を開始しない | 既存の重複操作防止を維持 |

聞き取り中は既存の補助文の領域で「聞き取り中です。もう一度押すと停止します。」と案内する。
準備中は「音声入力を準備しています。」、停止待ちは「音声を確認しています。」とする。
表示状態に合わせてアクセシビリティ名も「音声入力を開始」「音声入力を停止」に切り替える。
表示のために原本の要素を動かしたり、音声用の全画面ローディングを作ったりしない。
補助文・エラーは読み上げ可能とし、色だけで状態を伝えない。これらの状態表示は実装後に視覚確認する。

## 4. 認識言語・短時間利用・初期化

1. 対象言語は **日本語（`ja-JP`）**。初回マイク操作時にサービス初期化と権限確認を行う。Home表示・アプリ起動だけで録音しない。
2. 初期化成功後はアプリ内で1つの認識インスタンスを共有し、結果・状態・エラーを現在の利用画面へ安全に配送する。
   `initialize()`を押すたびに呼んでcallbackが置き換わると想定しない。失敗後の再試行は利用者操作によるものだけとする。
3. nativeでは`locales()`から取得したIDの`_`と`-`・大文字小文字を正規化し、`ja-JP`相当を選ぶ。
   APIへは返された実際のID（例：`ja_JP`）を渡す。日本語がなければ英語・端末既定言語へ無断で切り替えない。
4. `SpeechListenOptions`で短い文章向けの`ListenMode.dictation`、`partialResults: true`、`cancelOnError: true`を指定する方針。
   `listenFor: 20秒`を上限とし、nativeでは`pauseFor: 3秒`を希望値とする。20秒は既存実験の設定、3秒は本仕様の初期案で、実機検証済みの値ではない。
   Chromeでは初回許可待ちを3秒の無音扱いにしないため`pauseFor`を指定しない。ブラウザの一覧に頼らず`ja-JP`を直接指定する。
5. OSが無音などで先に終了することがある。指定秒数の継続を保証しない。録音開始後の上限監視でも停止を要求し、再起動を自動ループさせない。
   権限ダイアログを待っている時間を「20秒の録音」とは数えない。継続録音、バックグラウンド録音は対象外。
6. 手動停止は`stop()`で最終結果を要求する。画面離脱・バックグラウンド移行は`cancel()`で終了する。
   初期化成功前に認識用メソッドを呼ばず、開始失敗・例外でも録音状態を解除する。
7. `listen()`から戻っても開始通知がない場合は30秒の開始監視で取消し、文字入力へ戻す。
   nativeの初期化・OS許可待ち自体にはこの監視をかけない。Chromeの許可待ちは`listen()`後のため上限の対象になり得る。許可操作後に再度マイクを押せる。

初期化1回・端末の短い認識制限は[パッケージ作者の説明](https://pub.dev/packages/speech_to_text)、
オプションの指定方法は[`listen()` API](https://pub.dev/documentation/speech_to_text/latest/speech_to_text/SpeechToText/listen.html)と
[`SpeechListenOptions`](https://pub.dev/documentation/speech_to_text/latest/speech_to_text/SpeechListenOptions-class.html)を参照。
今回7.5.0のローカルソースでAPIを確認し、本体へ接続した。バージョン更新時にもAPI・OS最低要件との互換性を再確認する。

## 5. 権限とプラットフォーム設定（宣言追加済み・native未検証）

### iOS

本体の`ios/Runner/Info.plist`へ次の利用目的を追加した。OSの許可ダイアログの実機確認は今後行う。

| キー | 追加した利用目的 |
| --- | --- |
| `NSMicrophoneUsageDescription` | 「今の気持ちを音声で入力するために、マイクを使用します。」 |
| `NSSpeechRecognitionUsageDescription` | 「話した日本語を文字に変換するために、音声認識を使用します。」 |

### Android

本体の`android/app/src/main/AndroidManifest.xml`に`android.permission.RECORD_AUDIO`を宣言し、SDK初期化で実行時許可を扱う。
認識サービスが通信する構成に備え、release用main manifestにも`android.permission.INTERNET`を追加した。
Android 11以降のqueryとして`<queries>`内のintentに`android.speech.RecognitionService`を追加した。
既存の`PROCESS_TEXT` queryや他のアプリ設定は残す。Bluetooth入力は今回の必須対象にせず、不要なBluetooth権限を追加しない。
Issue #4実験と同様に`androidNoBluetooth`を指定した。7.5.0のソースに存在することを確認したが、native実行は未検証。

両OSの設定項目は[パッケージのプラットフォーム設定](https://pub.dev/packages/speech_to_text)を参照。
Androidの認識API要件・端末依存性は[公式SpeechRecognizer資料](https://developer.android.com/reference/android/speech/SpeechRecognizer)も参照する。

### 許可状態の扱い

- 未要求：利用者のマイク操作を契機にOSの許可ダイアログを出す。アプリ独自の文言だけで許可済み扱いにしない。
- 許可済み：日本語・サービスの利用可否も確認して開始する。許可だけで認識成功とはしない。
- マイク拒否：文字入力へ戻し、同じ操作を自動反復しない。
- iOS音声認識の拒否・制限：マイク許可済みでも開始せず、文字入力を案内する。
- 再要求不可・制限状態：端末設定で許可を変更できる場合の案内を表示する。設定へ強制遷移しない。
- `initialize()`が`false`：拒否と断定しない。拒否・サービスなし等を判別できなければ「音声入力を利用できません」と案内する。
- 設定変更後の再試行は明示操作で行い、録音を自動再開しない。拒否中も既存テキストを保持し編集できる。
- 実装の拒否表示は、OSとChrome共通で「音声入力が許可されていません。端末やブラウザの設定を確認するか、文字で入力してください。」とする。
  初期化が`false`だけの場合は原因不明の一般案内を使う。許可状態を細かく管理する別パッケージや設定画面の自動起動は追加していない。

## 6. 認識結果を入力欄へ反映する規則

```text
マイクを押す → 権限・日本語対応を確認 → 短い音声を認識
  → 同じ入力欄へ表示 → 停止・確定 → 利用者が確認・修正
  → 「気持ちを伝える」 → 既存の空入力検証 → 感情分析への接続境界
拒否・失敗・非対応 → 元のテキストを保持 → 文字入力／明示的な再試行
```

1. 認識開始前の入力文字列を保持する。前後の空白、既存の改行を勝手に削除しない。
2. 途中結果は**今回の音声分の仮表示を置換**する。callbackごとに末尾追加して同じ文を重複させない。
3. 既存文があれば、その末尾に改行を1つ挟んで今回の文を表示する。すでに改行で終わる場合は余分な改行を追加しない。
   例：既存「今日は学校へ行きました。」＋認識「とても寂しいです」→「今日は学校へ行きました。\nとても寂しいです」。
4. 最終結果の空白を除いた内容が空でなければ、今回の認識結果を**一度だけ**確定する。句読点の自動追加や意味の変更は行わない。
5. `notListening`だけで全結果到着と判断しない。最終結果と`done`を扱い、`done`や複数callbackで二重追加しない。
   パッケージは最終結果が来ない場合に最後の途中結果を最終扱いする場合があるため、「確定」は認識内容の正しさの保証ではない。
6. `stop()`後も無期限に待たない。SDKの`finalTimeout`（既定2秒）を考慮し、停止後3秒を初期の画面側監視値として扱う。
   これは未検証の設計値。監視時間内に完了しなければ取消・エラー復帰し、実機で値を調整する。
7. 無音・失敗・取消では元のテキストへ戻す。未確定の仮表示を成功として残さない。確定済みの過去の入力は消さない。
8. 終了後は編集可能にし、必要に応じて入力末尾へカーソルを移す。ユーザーが誤認識を修正できる。
9. 入力を認識しただけで分析・送信・画面遷移をしない。「気持ちを伝える」の明示操作で、Issue #7と同じ空白のみの検証と重複送信防止を行う。
10. 認識セッションIDと画面の生存確認を使い、取消済み・破棄後・前回セッションの遅延callbackが入力や画面を変更しないようにする。

状態通知の意味と最終結果の待ち方は[`initialize()`](https://pub.dev/documentation/speech_to_text/latest/speech_to_text/SpeechToText/initialize.html)、
停止・取消の違いは[`stop()`](https://pub.dev/documentation/speech_to_text/latest/speech_to_text/SpeechToText/stop.html)と
[`cancel()`](https://pub.dev/documentation/speech_to_text/latest/speech_to_text/SpeechToText/cancel.html)を参照する。

## 7. エラー・代替動作・ライフサイクル

| 条件 | 日本語の案内 | 回復動作 |
| --- | --- | --- |
| マイクの許可拒否を確認できた | 「マイクの利用が許可されていません。文字で入力してください。」 | 元の入力を保持し、文字入力へ |
| 音声認識の許可拒否・制限を確認できた | 「音声認識が許可されていません。文字で入力してください。許可する場合は端末の設定を確認してください。」 | 同上。自動で許可要求を繰り返さない |
| 日本語サービスなし・日本語localeなし | 「この環境では日本語の音声入力を利用できません。文字で入力してください。」 | 英語に切り替えず文字入力へ |
| 初期化失敗・原因を特定できない | 「音声入力を利用できません。文字で入力してください。」 | 文字入力、利用者による再試行 |
| 無音・no match・speech timeout | 「音声を認識できませんでした。もう一度話すか、文字で入力してください。」 | 元の入力を保持。短い文で再試行可能 |
| 通信失敗・認識サービスの障害 | 「音声入力に失敗しました。もう一度お試しください。文字でも入力できます。」 | 入力へ戻す。自動再送・自動録音しない |
| サービス使用中・二重開始 | 「今は音声入力を開始できません。少し待つか、文字で入力してください。」 | 現セッションを整理してから明示再試行 |
| 停止後に完了しない・想定外の例外 | 「音声入力を終了できませんでした。文字で入力してください。」 | 認識を取消し、元の入力と操作可能状態へ戻す |
| 画面離脱・アプリが背景へ移動 | エラーダイアログは出さない | `cancel()`、仮表示を破棄、再録音は利用者操作から |

エラーコードはOS・認識サービスで異なるため、判別できるものだけ上記へ対応づけ、残りは一般エラーにする。
SDKの生の例外や入力文をそのまま表示・ログ出力しない。
設定画面を開く・ログアウト・戻る操作では先に音声を取消す。確定済み入力の保持は既存のHomeの画面内保持に従う。
プロセス終了後の入力復元は追加しない。登録・ログイン・保存セッション・ログアウト・パスワード再設定の既存処理を変更しない。

## 8. データ・非対象・分析との境界

- アプリ側で生の録音ファイルを保存・アップロードしない。入力した気持ち、認識結果、認証情報をデバッグログへ残さない。
- 端末の認識サービスがネットワークや提供元のサーバーを使う場合がある。「完全に端末内」「必ずオフライン」とは案内しない。
  `onDevice`のみを必須にすると対応しない端末で失敗するため、今回はオフライン動作を保証しない。
- 長時間録音、常時待受、自動再開、録音ファイル管理、Bluetooth周辺機器対応保証は対象外。
- Chromeは今回の手動確認用にも使うが、ChromeだけでiOS / Android要件を検証済みにしない。
- 本体の分析は現在UIプレビュー。音声接続後も、AI・推薦画面の別の接続作業なしに実分析が動くとはしない。
- 分析後の遷移先についてIssue #7と全体仕様の相違は既存Home仕様第7節に記録済み。本仕様では勝手に解決せず、音声から編集可能テキストへの受け渡しを定義する。
- Firebase設定、認証アカウント、課金設定は今回変更しない。

## 9. 受け入れ基準との対応

| Issue #8本文・達成目標／依頼項目 | 仕様の定義 | 実装・端末検証の状態 |
| --- | --- | --- |
| `speech_to_text`を第一候補にする | 第1・2・4節 | 本体へ7.5.0を追加 |
| iOS / Androidで日本語`ja-JP` | 第4・5節 | locale選択を実装。native実行は未確認 |
| 初回のマイク・音声認識権限 | 第5・7節 | 本体のnative宣言とSDK初期化を接続。許可ダイアログ実機未確認 |
| マイクの開始・停止、短い回答限定 | 第3・4節 | 20秒上限・停止・取消の実機確認は今後 |
| 音声→テキスト→確認・修正→感情分析 | 第6・8節 | Home音声コードを接続。AIは未接続のプレビューのまま |
| 認識結果を既存欄に表示し編集可能 | 第6節 | 元文保持・途中結果置換・最終結果の一度だけの反映を実装 |
| 権限拒否・認識失敗・利用不可の代替動作 | 第5・7節 | 日本語案内と文字入力への復帰を実装。実機確認は今後 |
| Figmaと既存認証を維持 | 第2・3・7節 | 原本画像・位置・寸法を維持。認証サービスと設定を変更しない |

**Issue #8の「仕様作成」の達成目標は上記で定義する。これは音声機能の実装完了・実機PASSの宣言ではない。**

## 10. 検証記録と今後の確認

### 過去の単体実験（2026-10-13、利用者からの確認報告）

| 環境 | 記録された結果 | この記録の限界 |
| --- | --- | --- |
| Chrome / macOS | 「とても寂しいです。」を話し、「とても寂しいです」、Status: done。発話内容一致PASS（句点を除く） | Home接続・native対応の証明ではない |
| iPhone 18 Pro Simulator / iOS 27.0 | 「今日はとても寂しいです」を認識、Status: done、PASS | 実機iPhoneの検証ではない |
| Android Emulator | `error_speech_timeout`の既存記録 | 成功未確認。今回エミュレータの再調査は行わない |
| 実機iOS / Android | 成功確認なし | 両方で確認が必要 |

元の記録はサービス方針と[Issue #4 README](../tools/issue4_package_check/README.md)を参照。今回これらの手動音声テストを再実行していない。

### 音声接続前の仕様レビュー・回帰確認（2026-10-22、過去の段階）

- Issue #8の本文・達成目標を第9節と照合。Home仕様の追記方針・空入力・手動送信と整合させた。
- 本体で`flutter analyze --no-pub`：**No issues found**。
- 本体で`flutter test --no-pub`：**83 tests passed**。既存の認証・Homeの回帰確認であり、新しい音声実装のテストではない。
- `tools/issue4_package_check/`で`flutter test --no-pub test/voice_locale_test.dart`：**2 tests passed**。
  Webの`ja-JP`指定とnativeの日本語locale選択を確認。実際の認識・権限・マイクは使っていない。
- 追加した本書のローカル参照先の存在とMarkdownのコードフェンスを確認した。
- 作業前に記録した既存103ファイルのSHA-256と照合し、変更・欠損なし。本体ソース、既存テスト、既存仕様、素材、Firebase設定を保持した。
- 依存関係追加・`pub get`・nativeビルド・エミュレータ起動・実機音声テストは行っていない。Git操作も行っていない。
- 以上は仕様と既存コードの確認であり、本体マイク動作の成功とはしない。

### 音声接続後の自動確認と手動確認の区別

- `flutter pub get`：成功。`speech_to_text`は7.5.0に固定。他の依存パッケージの任意アップグレードは行っていない。
- `flutter analyze --no-pub`：**No issues found**。
- `flutter test --no-pub --reporter expanded`：**117 tests passed**（既存83件＋音声用34件）。
- 音声用34件はcontroller 25件、Home widget 7件、SDK adapter 2件。日本語locale、開始・停止・重複防止、文字の保持・編集・手動送信、拒否・無音・失敗、取消・遅延callback、20秒上限・3秒終了待ち・30秒開始待ちを確認した。
- SDK adapterでは実際の7.5.0 Dartコードと模擬platform channelを使い、初期化1回・callbackの再接続、`ja-JP`と20秒設定、途中結果が2秒後に最終結果となる経路を確認した。
- 最初のテストで、背景移行を模擬するstateの順序と、Bluetooth無効化オプションの送信キーに誤りがあり、テストを修正した。最終の全件実行は成功。
- 原本画像を含むassetsとFirebase設定が作業前のハッシュと一致することを確認。widget testで390 × 844のカード・送信・54pxマイクの位置とasset参照を確認した。ブラウザのスクリーンショット比較は未実施。
- `flutter build web --no-pub --target lib/home_preview.dart`：**成功**。本体Homeプレビューのrelease Webビルドが完了した。
- ビルド済みプレビューを`http://127.0.0.1:8878/`で配信し、HTTP 200を確認した。ページ配信の確認であり、Chromeでの画面・認識の成功ではない。サーバー終了後は次節のFlutterコマンドで起動できる。
- nativeビルド、エミュレータ起動、実機・Chromeでのライブ認識は行っていない。Git操作は行っていない。

自動テストは偽の認識サービスとSDKの模擬platform channelを使う。マイク・実認識・実Firebaseを使った成功の証拠ではない。

### 自動テストの対象と今後の実機確認

1. 自動確認済み：偽の音声サービスで開始・停止、連打抑止、途中結果の置換、最終結果の一度だけの反映、既存文と改行の保持。
2. 自動確認済み：編集してから手動送信できること、音声結果だけでは分析を呼ばないこと、空結果・空白入力を送らないこと。
3. 自動確認済み：拒否・初期化失敗・日本語なし・通信失敗・無音・停止待ちタイムアウトで入力を失わず、文字入力へ戻れること。
4. 自動確認済み：画面破棄・背景移行・設定・偽のログアウト時の取消、古いcallbackの無視、聞き取り中に手入力を止めること。
5. **実機iPhone / Android各1台以上**で日本語の短い発話、初回許可・拒否・設定変更後の再試行、手動停止・無音停止・20秒上限を確認する。
6. 実機で認識終了後の編集、再録音、別画面へ移動してマイクが終了すること、ネットワーク不調時の文字入力を確認する。
7. Figmaの原本マイク・入力カードを保持し、状態文が重ならないことを確認する。音声接続後に既存認証・Homeテストも再実行する。

実機のOS・端末・認識サービス・locale・結果を記録し、認識内容や個人情報を公開のテストログへ貼らない。

## 11. Chromeで利用者が行う手動テスト（本体のライブ認識は未確認）

repository rootで次を実行する。既存のHomeプレビュー入口を使い、新しいテストアプリは作らない。

```sh
flutter pub get
flutter run -d chrome --target lib/home_preview.dart --web-port 8879
```

この入口はFirebaseを初期化しない。**マイクは実際の認識サービスを使うが、感情分析・推薦はプレビュー**である。
`localhost`で開く。別端末からのHTTP LANアドレスは使わず、公開する場合はHTTPSが必要。

1. 入力欄に「今日は学校に行きました。」と入力する。マイク画像を1回押す。
2. Chromeのマイク許可が表示されたら許可し、「聞き取り中です。」を確認する。
3. 「とても寂しいです。」と短く話す。必要なら同じマイクをもう一度押して停止する。
4. 「音声を入力しました。確認・修正できます。」になり、元の文と認識文が改行で区切られることを確認する。
   結果が出るまで最大数秒待つ。読み違い・句読点差は実際の結果として記録し、成功を自動で仮定しない。
5. 入力欄を編集し、再録音しても元の文が消えず、途中結果が重複しないことを確認する。
6. 録音だけでは分析画面へ進まないことを確認する。「気持ちを伝える」は依然として分析UIプレビューで、AIへ送信しない。
   このプレビュー入口では「入力に戻る」を押すまで分析待機画面を表示する。
7. 許可拒否・無音・ネットワーク不調時に日本語案内が出て、元の入力が残り、文字入力へ戻れることを確認する。
8. 必要な場合だけChromeのアドレスバーのサイト設定からマイク許可を変更して再読み込みする。拒否状態で無限に押し続けない。
9. 聞き取り中の設定表示・タブ背景移行・画面離脱で録音が終わり、勝手に再開しないことを確認する。

通常の認証経由で確認する場合は`flutter run -d chrome --web-port 8879`で起動し、既存アカウントでHomeへ進む。
ローカルFirebase設定が必要。この依頼のために新しいアカウントは作らず、設定値も変更しない。
同じportで2つのFlutter実行を同時起動しない。

ビルド済みプレビューを配信している場合はそのURLをChromeで開くだけでも確認できる。
`flutter run`を同じportで開始する前に、既存のプレビューサーバーを停止するか別のportを指定する。

実機iOS / Androidでは第10節の許可・拒否・言語・停止・上限・背景移行を別途確認する。
nativeビルド、署名、各端末の認識サービスが必要。Chromeの成功だけではこれらをPASSにしない。

## 12. 今回変更・追加したファイル

| 分類 | ファイル |
| --- | --- |
| 追加：音声サービス | `lib/services/voice/speech_to_text_service.dart` |
| 追加：音声状態管理 | `lib/presentation/controllers/voice_input_controller.dart` |
| Homeへの接続 | `lib/presentation/screens/home_screen.dart` |
| 既存UIへの状態・操作接続 | `lib/presentation/widgets/home/feeling_input_view.dart` |
| AI未接続という案内の整合 | `lib/presentation/widgets/home/analysis_loading_view.dart` |
| 既存プレビュー入口の説明コメント | `lib/home_preview.dart` |
| 依存関係 | `pubspec.yaml`、`pubspec.lock` |
| native権限宣言 | `android/app/src/main/AndroidManifest.xml`、`ios/Runner/Info.plist` |
| 追加：controllerテスト | `test/voice_input_controller_test.dart` |
| 追加：Homeテスト | `test/home_voice_input_test.dart` |
| 追加：SDK adapterテスト | `test/speech_to_text_service_test.dart` |
| 追加：偽サービス | `test/support/fake_voice_recognition.dart` |
| 更新：旧マイクplaceholderテストと案内文 | `test/home_emotion_screen_test.dart` |
| 仕様・確認手順 | `docs/voice_input_spec.md`、`docs/home_emotion_screen_spec.md` |
| Flutterが依存追加に伴い自動更新 | `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`、`ios/Runner/GeneratedPluginRegistrant.m` |

生成されたregistrantは手で編集していない。`build/`・`.dart_tool/`等の生成物を配布用ソースへ加えない。
登録・ログイン・セッション・パスワード再設定の実装、Firebase設定、Issue #4実験の元ファイルは変更していない。
