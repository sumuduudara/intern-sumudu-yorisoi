# Home → Firebase Gemini → 感情結果の実接続

更新日：2026-10-27。Issue #7の入力UI、Issue #8の音声入力、Issue #9の分析サービスを接続する。
過去の仕様・検証記録にある「Home未接続」は当時の状態である。

## 現在の動作

1. 通常の`lib/main.dart`で既存のFirebase初期化・ログイン状態確認を行い、認証後にHomeへ進む。
2. 手入力と確定した日本語音声の文章を、既存の`TextEditingController`で編集できる。音声処理中はShareを無効にする。
3. Shareで前後の空白を除いて確認する。空なら日本語の入力案内を表示し、AIを呼ばない。画面の元の文章は書き換えない。
4. 通常のHomeは`EmotionAnalyzer`境界から実`EmotionAnalysisService`を呼ぶ。既定のモデル実装は`FirebaseEmotionModel`。
5. 実リクエストの待機中だけ、既存のFigma素材・配置の`AnalysisLoadingView`を表示する。実経路に3秒の演出待機はない。
6. 既存の`FirebaseAI.googleAI()` / `gemini-3.5-flash-lite`と日本語prompt・JSON schemaを使用する。
7. 既存のadapterでblock・候補数・STOPを確認し、service/parserでJSON・日本語8カテゴリ・主副の整合を検証する。
8. 検証した`EmotionAnalysisResult`を`EmotionAnalysisResultScreen`へ渡す。主感情と、存在する場合だけ副感情を表示する。
9. 「入力に戻る」またはシステムの戻る操作で、元のHomeと編集可能な文章へ戻る。

結果画面は既存の背景・ロゴ・ペット集合画像・書体・白いカード・pink gradientを再利用した追加画面。
新しいFigma結果frameを取得・完全再現したものではない。元のHome・03-A素材やmicrophoneの色・透明度処理は変更していない。

## エラー・重複・取消し

- 空入力、無効JSON、未知カテゴリ、timeout、Firebase設定、権限、quota、blocked、通信等の失敗を既存の安全な日本語案内へ変換する。
- 生のSDK例外、API key、response本文をUIへ表示しない。未知の例外は一般的な通信案内にする。
- 失敗しても元の文章を保持し、編集または「再試行」を選べる。自動再送はしない。
- 同じ処理の待機中にShareを繰り返しても、追加のrequestを開始しない。
- Loadingの「入力に戻る」またはシステムの戻る操作は、表示待ちを取り消してHomeへ戻す。
- request番号と`mounted`で、取消し・新しいrequest・画面破棄後の古い成功/失敗を無視する。
- **SDKにHTTP中断APIは接続していない。** 取消しは送信済みの通信やserver側処理を止めない。画面にもその制限を表示する。
  取消し後に再送すると別requestとなり、以前の処理もquotaを使う可能性がある。serviceの既存timeoutは30秒。

## データと将来の推薦

- 文章はHomeのcontroller内の一時メモリに保持する。実分析時はFirebase AIへ送信する。
- 本実装はFirestore、端末ファイル、preferences等へ文章を保存しない。画面破棄・アプリ終了後の文章復元はない。
- AI事業者側の保持方針について、この実装から「保存されない」と保証しない。
- 結果画面は型付きの主感情・任意の副感情だけを受け取る。将来のPet Room側もこの型を受け取れる。
- Pet Room推薦・検索・遷移は未実装。架空のroom、pet選択、成功したように見える「次へ」は追加していない。
- 分析結果はAIの推定であり医療診断ではない旨を表示する。

## 起動コマンド

通常の認証を含むアプリ：

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter run -d chrome --web-port 8879
```

既存のローカルFirebase optionsが必要。新しいアカウントを作らず実Homeを確認する開発専用入口：

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter run -d chrome --target lib/home_live.dart --web-port 8884
```

`home_live.dart`はFirebaseを実初期化し、同じHome・実serviceを使う。画面上のログイン導線だけを省く検証用入口であり、
本番の`main.dart`やFirebaseの認証・権限設定を変更しない。認証を要求するbackendでは未ログインのため失敗する場合がある。
API key、billing、Console設定を変更して起動する手順ではない。既存serverが同じportを使用中なら先にそのrunを終了する。

`lib/home_preview.dart`は以前からのFigma/voice確認専用入口として残す。
明示した`previewOnly: true`だけが旧visual preview処理を使い、実AIの成功とは扱わない。
`docs/testing_commands.md`のHome previewコマンドも、この旧previewを開く。
**実AIを確認する場合は上記の通常入口か`home_live.dart`を使う。**

## 手動確認

1. 空のままShareを押す。入力案内が表示され、分析を開始しないことを確認する。
2. 「今日はひとりで寂しいです」を入力してShareを押す。実待機中の03-A表示から、主感情「寂しい」へ進むか確認する。
3. 「入力に戻る」で文章が保持され、編集・再送できることを確認する。AIは推定なので毎回同じ分類になる保証はない。
4. マイクをONにし、日本語を話し、再度押してOFFにする。確定した文章を修正してからShareする。
5. 通信失敗時に日本語案内と元の文章が残ること、取消し後に古い結果が表示されないことを確認する。

## 検証範囲・残る制限

- 自動testsはfake analyzerの入力記録・Future・例外を使い、実経路のloading、主副表示、戻る、重複防止、取消し、破棄、再試行を確認する。
- 実`EmotionAnalysisService`へモデルfixtureを渡し、正しいJSONと壊れたJSONがUIまで正しく扱われることも確認する。
- fake/fixtureによる日本語例はAI精度の証明ではない。実Chromeの記録は下記に別記する。
- 登録・ログイン・セッション・ログアウト・パスワード再設定の既存testsを含む全suiteを再実行する。
- 新しい結果画面単体は320×480、2倍文字でもoverflowしないことをtestする。
  既存HomeのShare行はアプリ全体の2倍文字設定でoverflowする範囲があり、元UI保護のため本変更では修正していない。
- 実機iOS / Android、本変更のSimulator実行、実音声→実AIまでの一連の手動検証は別途必要。Web Firebase optionsの成功をnative設定の成功と扱わない。
- 新しい結果画面のPet Room接続は未実装。

### 今回の実行結果

- `flutter analyze`：No issues found（最終コードの再確認も実施）。
- `flutter test --reporter expanded`：**232 passed / 3 skipped**。今回のHome分析testsは24件追加。
  skipの3件は既存の任意実行ライブSDK tests。全suiteには認証・音声・microphoneの透明度回帰testも含む。
- macOSの**Google Chrome headless、390×844**で、実Flutter Web UIから既存のFirebaseへ接続した。
  `home_live.dart`を使用し、analyzer、Firebase初期化、SDK、通信、モデル応答、parserのmockは使っていない。
- 空Shareで入力案内が出ること、実request待機中のloading、AI endpointのHTTP **200**、
  「今日はひとりで寂しいです」→結果画面の主感情 **「寂しい」**、Homeへ戻って文章を編集するためfocusした時に元の文章があることを確認した。
- Chrome automationでは、Flutter accessibilityのmerged text・live announcementの重複・routeのtransition待機を考慮してlocatorを修正した。
  入力値の確認は戻るtransitionを待ち、入力欄をfocusして行った。過去のSDK testだけを今回のUI成功として扱ったものではない。
- Chrome screenshotで新しい結果labelsの日本語font fallback不足を確認したため、結果画面の全テキストに既存のbundled Zen Maru Gothicを明示した。
  bundled font使用はwidget assertionでも確認する。
- 通常のログイン操作から実AIまでの手動再検証、実音声から実AIまでの手動確認、iOS/Android実行は今回行っていない。
  現在のローカルFirebase optionsに設定されているplatformはWebのみ。nativeのlive動作を確認済みとは報告しない。


## 2026-10-31 Android音声の残存問題とIssue #9の確認事項

### Android音声：Issue #8の未解決事項

最新音声修正後も、利用者はAndroid 17 / API 37の`emulator-5554`で日本語認識失敗を報告した。**Android voiceはFAIL・未解決であり、PASSではない。** 診断・残る原因の不確実性は[音声仕様の最新記録](voice_input_spec.md)を参照。
音声を文字へ変換する段階の問題として管理し、Geminiの分析失敗と混同しない。文字入力からの分析経路は保持する。Emulatorだけの問題と断定する証拠はない。

### Chrome voice / 実Geminiへの影響

- 音声修正中もGemini service/model、Homeの実分析接続、結果画面、Firebase optionsは変更していない。保存済みの修正前ハッシュとも一致した。
- Chrome固有の言語指定・pause指定なし・最終結果補完経路を維持し、直前の自動回帰確認は276 PASS / 3 skip。今回testsは再実行しない。
- 上記の既存Chrome実Gemini確認（`home_live.dart`、HTTP 200、日本語入力→「寂しい」）は維持する。今回ライブAPIやChrome音声の再試験はしておらず、新しい手動PASSは追加しない。
- 以前の「Firebase optionsはWebのみ」は当時の記録。現在は承認済みのAndroid optionsが追加され、Android起動済み。ただしnativeの実Gemini成功とは区別する。今回その設定は変更しない。

### Issue #9固有の残る確認事項・制限

- **今回、新しいGemini固有の不具合は確認していない。** Android音声の失敗だけを根拠に、既存Chromeの実分析成功を取り消したり、Geminiの不具合と判定したりしない。
- 通常の`main.dart`認証からHome→実Gemini→結果→Homeまでの一連のChrome再確認は、上記の開発入口の確認と区別する。この記録には新しい完了証拠がないため、未確認として残す。
- 現在の本体でAndroid/iOSの実AI end-to-endと実機確認は未確認。Issue #4の独立実験やAndroid起動成功をその代わりにしない。
- 音声→実AIの一連のAndroid手動確認は、まず音声認識の解決が必要。これは入力機能との結合確認の保留事項であり、テキスト→AIの実装欠落ではない。
- 取消しは表示待ちだけで、送信済みHTTP/server処理を中断しない。2倍文字での既存Home表示、運用時のApp Check/quotaも既存の制限・確認事項として残る。
- Pet Room推薦/遷移は将来のIssue #10以降の対象。Issue #9の完了を装うために追加しない。今回はIssue #10を開始せず、Git操作も行わない。


### 同日・Android詳細診断後の状態

日本語モデルの環境問題は修正したが、実発話の認識は引き続き失敗。詳細・native crash証拠・実機での一連の確認手順は[Android詳細診断](android_voice_diagnostics.md)へ分離した。
**Androidの音声→Share→実Gemini→結果は未完了**。既存Chrome実AI結果は保持し、今回新たなChrome/native AI成功を主張しない。今回のanalysisはNo issues、全suiteは276 PASS / 3 skip。Gemini/Auth/Figma/アプリsource/Firebase設定は変更していない。Issue #10は未着手。
