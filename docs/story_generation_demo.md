# Issue #10 開発者用・実Gemini物語生成デモ

このデモは**制作担当者がTerminalで一話を生成するもの**です。アプリ利用者向けのruntime生成ではありません。
既存の[仕様](emotion_pet_story_spec.md)の対応表・安全方針を守り、[共通Prompt](story_generation_prompt.md)を制作上の原本として使います。
現在のPromptはv4です。コードとrecord templateの版を同期しています。v3以前の実生成記録は下記の履歴として保持します。一回限定retry、承認gate、対応表は変更しません。
main.dart、認証、Home、音声入力、感情分析、Figma assetsには接続・変更しません。追加packageはありません。

## 1. 実行前提と起動

### App Checkが必須のproject：localhost Web demo（推奨）

2026-11-07、hostの一回限りの実SDK診断で、基になる例外が
`ServerException: Firebase App Check token is invalid.`であることを確認しました。
生のSDK例外全体やcredentialsは出力せず、既知の固定error文字列の一致だけを検証しました。
host harnessはApp Checkを初期化せず、Chromeの登録済みdebug tokenを引き継ぎません。

既存のアプリ/Figma UIを変更せず、別の開発専用entrypointを使用できます：

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter run -d web-server --target lib/story_generation_web_demo.dart \
  --web-hostname localhost --web-port 8886 \
  --dart-define=YORISOI_APP_CHECK_DEBUG=true \
  --dart-define=STORY_EMOTION=lonely --dart-define=STORY_PET=cat
```

1. 既存のChromeで`http://localhost:8886`を開きます。8879の既存アプリは停止・変更しません。
2. 「1. App Check接続を確認」を押します。実`getToken(true)`のserver exchangeが成功するまで生成buttonは無効です。
3. 初回に失敗した場合、DevTools ConsoleにSDKが表示するdebug tokenを、Firebase Console →
   `yorisoi-emotion-test` → App Check → Apps → 同じWeb app → Manage debug tokensへ直接登録します。
   tokenをchat・source・dart-defineへ貼らないでください。別origin/ブラウザープロファイルのため、Issue #9とは別tokenになる場合があります。
4. 同じブラウザー・originのまま「1」を再度押し、server token exchange成功の表示を確認します。
5. 「2. 実Geminiで一話生成」を一回押します。Prompt v4、実Firebase AI SDK、同じschema・validation・最大一回のlength retryを使用します。
6. タイトル・本文・文字数・warnings・`status: draft` / `human_approved: false`を確認します。
   App Check確認成功だけではGemini生成成功とは扱いません。結果本文が表示された場合のみ実生成成功です。
7. 終了時はrunのTerminalで`q`または`Ctrl+C`。demoはFirestore/Storageへ書き込まず、原稿を承認・公開しません。

このentrypointはexplicit flag付きのlocalhost Web debug以外では起動しません。
実App CheckをAI client作成より先にactivateし、tokenそのものはアプリUIや独自ログへ出しません。
本番attestation実装ではありません。Console設定・enforcement・billingを自動変更しません。
promptは既存MarkdownをFlutter assetとして読み、別のprompt本文を複製しません。

今回の新しい自動testsを含む3 filesは**106 passed**（fake-based）、Web demoのlive生成は利用者による確認待ちです。
host診断は失敗であり、過去の実生成履歴やfake testsを今回のlive成功として扱いません。

### 従来のhost harness（実行方法。App Check認可には未対応）

- 既存Flutter環境と取得済みdependenciesが必要です。初回だけ必要なら`flutter pub get`を行います。
- 既存のignored `lib/firebase_options.dart`のWeb optionsと、既存projectのFirebase AI Logic利用権限・利用枠・ネットワークが必要です。設定値をTerminalや説明資料へ貼らないでください。
- この一回の実行は**実際のGemini API requestを1回、文字数調整が必要なら最大2回**発生させます。モデルは既存の`gemini-3.5-flash-lite`、providerは`FirebaseAI.googleAI()`。課金や設定を変更するコマンドではありません。

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter test --no-pub --concurrency=1 --reporter expanded \
  --dart-define=RUN_LIVE_STORY=true \
  --dart-define=STORY_EMOTION=lonely \
  --dart-define=STORY_PET=cat \
  tool/story_generation_demo.dart
```

別の組は`STORY_EMOTION`と`STORY_PET`を両方変更します。日本語名も受け付けます。

| emotion | pet |
| --- | --- |
| sad / 悲しい | cat / 猫 |
| lonely / 寂しい | cat / 猫 |
| anxious / 不安 | rabbit / うさぎ |
| stressed / ストレス | rabbit / うさぎ |
| angry / 怒り | dog / 犬 |
| happy / 嬉しい | dog / 犬 |
| calm / 安心 | dolphin / イルカ |
| other / その他 | dolphin / イルカ |

組が不正ならAIを呼ぶ前に失敗します。`RUN_LIVE_STORY=true`なしではskipし、通常の`flutter test`はこのtoolを自動実行しません。

## 2. なぜflutter testでdemoを動かすか

### 起動エラーの区別（2026-11-07確認）

- `dart run tool/story_generation_demo.dart`は使用しません。このfileは`flutter_test`、Firebase Flutter SDKをimportするFlutter test harnessです。通常のDart VMには`dart:ui`がないため、`TextBox`、`Offset`、`Canvas`等のframeworkコンパイルエラーになります。Flutterの内部fileを修正したり、別packageで型を補ったりしないでください。
- `flutter test --no-pub tool/story_generation_demo.dart`だけでは、実APIの誤実行を防ぐ`RUN_LIVE_STORY`がfalseのため全skipになります。生成成功ではありません。第1節のcommandを、三つの`--dart-define`を含めて使ってください。既存harnessの変更は不要です。
- 第1節のcommandを実行するとskipを解除して実SDK requestへ進みますが、backendの認可成功を保証するcommandではありません。

今回、第1節の`lonely / cat` commandはコンパイルして実行されましたが、実requestは
`StoryGenerationException(permissionDenied): AIの利用権限・App Check設定を確認してください。`
で失敗しました。原稿は生成・表示されていません。追加生成段階にも進んでいません。
adapterは権限/App Checkを同じsafe codeへ変換するため、この結果だけでraw backend errorの詳細までは断定しません。

このhost harnessはFirebase Coreの初期化channelだけを置換し、App Check provider/tokenを初期化しません。
Chromeで登録したdebug tokenは、そのブラウザー内に保持されるもので、このhost実行へ自動共有されません。
`--dart-define=YORISOI_APP_CHECK_DEBUG=true`を本commandに足すだけでも解決しません。このentrypointはWeb bootstrapを呼ばず、Web環境でもないためです。
App Check enforced projectでのhost用attestationは未対応です。認可された開発用attestation経路の追加が別途必要で、
tokenのソース埋込み・chatへの送信・enforcement解除・billing変更は行いません。
したがって、現時点でこのhost demoの実Gemini成功を再現できたとは扱いません。

同日の軽量確認：`flutter analyze --no-pub`はNo issues、
`test/story_generation_service_test.dart`と`test/firebase_story_model_test.dart`は**104 passed**。
この104件はfake-based testsであり、実API成功の証拠ではありません。下記の過去の実生成記録とは区別してください。

Firebaseの既存Flutter SDKを使い、SimulatorやWeb buildを起動せずに実requestを確認するためです。
既存の`test/emotion_analysis_live_test.dart`と同じく、**Firebase Coreのnative初期化channelだけをhost用に置換**します。
AI adapter、SDK、HTTP、Geminiの応答、原稿validationは本物です。モデル応答をfakeに置換するdemoではありません。
これはhostでの実API確認であり、Chrome UI・iOS・Androidのend-to-end成功を証明しません。`dart run`単独では実行しません。

## 3. コードと出力

- `tool/story_generation_demo.dart`：opt-in、組の指定、Core host初期化、表示。文字数調整を含めAI requestは最大2回です。
- `StorySelection`：許可8組のみ。未知の値や対応外の組を拒否します。
- `StoryGenerationService`：共通Prompt v4のtext blockをそのまま抽出して2項目を置換。各requestは90秒で待機を打ち切り、文字数調整は一回だけ追加できます。
- `FirebaseStoryModel`：既存Firebase options/provider/modelで別の物語requestを行います。出力はtitle/story_textのJSON、4096 output tokens。感情分析のpromptや設定は変更しません。
- `StoryDraft`：厳密な2キー・文字列、日本語文字の存在、一人称「ぼく」、基本長さ、禁止パターンを確認します。

成功時は未承認DRAFT、感情/ペット、モデル、Prompt版、UTC日時、本文文字数、`length_target_met`、`generation_attempts`、`length_retry_error`、注意点、タイトル、物語本文をTerminalへ表示します。
文字数は`story_text`だけからUnicode空白・改行を除いたUnicode code point数です。句読点は含み、タイトル・JSON記号・metadata・warningは含めません。表示書記素数やtoken数ではありません。
600〜900文字・タイトル8〜24文字を外れたdraftには修正の注意を表示します。本文100文字未満・2000文字超、空/不正JSON/余分なfield等は失敗です。
日本語文字の存在や「ぼく」の確認は、全文が自然な日本語・正しい動物視点であることの保証ではありません。
URL、email、一部の医療/否定/依存表現、HTML等を検出して拒否しますが、これは限定的なチェックであり、すべての危険表現を検知できません。

**人の全文・安全性・権利・読み上げ確認は必須です。** statusは常にdraft、human_approvedは常にfalse。
原稿ファイルの保存・承認・公開・catalog登録・Firestore/Storage書込みはしません。テンプレートの完全なrecord、Prompt/body hash、原稿版の管理は制作レビュー時に別途記入します。
Terminal出力は例文用の制御された条件から新規生成した創作本文だけです。ユーザーの入力・account・credentialsは生成素材にしません。

## 4. 失敗と制限

- 初回が設定/権限/App Check/quota、安全block、STOP以外の終了、不正JSON・基本安全性違反、timeout等で失敗した場合は、安全な日本語とcodeで終了します。この種類の失敗を理由に自動再送しません。raw backend responseや設定値は表示しません。
- `genaiConfigurationMissing`は既知の`Firebase AI Logic genai config not found`を意味します。設定確認が必要ですが、demoがConsoleやcredentialsを変更することはありません。
- `requestFailed`だけでは通信・provider内部等の詳細原因を断定できません。危険な生ログを出す代わりに、承認済みの開発環境で原因を調べてください。
- timeoutやTerminal停止は送信済みserver処理を中断する保証がありません。再実行は別request・別quota消費になり得ます。
- 応答は非決定的です。一回の成功は8組全体の品質・安全性・本番運用の成功ではありません。音声時間は未測定、TTSと再生は未実装です。

### 文字数だけを対象にした追加生成（最大一回）

1. 初回が基本形式・安全gateを通り、本文が600〜900文字ならそのdraftを表示します。追加requestはありません。
2. 基本gateを通ったdraftが600文字未満または900文字超なら、**追加生成を一回だけ**行います。共通Prompt v4に、前回draftのJSON、実測文字数、600/900境界までの不足/超過文字数、中心目標750文字までの加筆/削減量、具体的な指示を末尾へ追加します。前回本文は参考データとして扱い、指示として実行しないよう明示します。
3. 追加結果にも同じJSON・形式・安全gate・文字数検証を適用します。範囲内なら2回目のdraft、範囲外でも基本gateを通れば2回目のdraftと明示warningを表示します。3回目は呼びません。
4. 追加requestが通信・quota・timeout等で失敗した場合や、追加出力が不正JSON・安全gate違反の場合は、**初回の検証済みdraftを保持**します。元の長さwarningに加え、追加失敗と安全なerror codeを表示します。失敗した/安全性を確認できない本文へ置き換えません。
5. `generation_attempts`は1または2、`length_retry_error`は追加失敗のsafe code（成功時はnull）です。どの場合も`status: draft`と`human_approved: false`を維持します。推奨文字数に収まることは承認条件の一つにすぎません。

本文100文字未満・2000文字超等は既存の基本gateで不正出力として扱い、文字数調整の対象draftにはしません。
本文の反復や無関係な出来事での水増しは禁止したままです。追加生成は同じFirebase provider/modelを使い、モデル切替はしません。
長さ調整の一回は追加の利用枠を消費します。初回と追加requestにそれぞれ90秒の待機上限があるため、全体は約180秒までとなり、demo runnerのtimeoutは余裕を含め4分です。初回がtimeoutした場合は追加requestを行いません。これはserver処理の中断保証ではありません。

## 5. fakeを使う自動テスト

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded \
  test/story_generation_service_test.dart test/firebase_story_model_test.dart
```

この2ファイルはfakeモデル/SDK応答を使い、ネットワークを呼びません。許可8組/禁止24組、Prompt一致、JSON、draft、文字数、限定安全gate、timeout、SDK失敗の変換を確認します。
文字数調整では、初回成功、短い/長い→改善、2回目も範囲外、方向が逆になる場合、quota/timeout/不正JSON/安全違反、初回draft保持と最大2回を確認します。
成功しても実Geminiの成功として扱いません。実行結果の確認には第1節のopt-in demoを使います。

## 6. 検証履歴（2026-10-31）

### 6.1 初版v1の記録

- `flutter analyze --no-pub`：No issues found。
- 上記2ファイルのfake-based tests：**83 passed**。実AI成功の証拠ではありません。
- 第1節のhost demoを`lonely / cat`で一回実行：**実Firebase AI SDK → Gemini → JSON検証 → draft表示に成功**。AIの応答はmockしていません。
- 実モデル`gemini-3.5-flash-lite`、Prompt版`yorisoi-story-v1`、返却タイトル「午後の日だまりと静かな窓辺」。本文は**371文字**でした。
- 推奨600〜900文字に満たないため、加筆・修正が必要というwarningを実際に表示しました。生成リクエストと基本validationの成功であり、推奨長さの達成や制作物の採用成功とは扱いません。
- 表示は`status: draft` / `human_approved: false` / `audio_status: not_generated`。本文の独立したhuman review、権利確認、音声生成、実測時間は未実施です。
- ほかの7組の実AI生成、Chrome/native UI、iOS/Android実行は未検証。自動再送や、長さを満たすまでの繰り返し生成はしていません。
- 元の4仕様ファイル・既存アプリ・Firebase optionsは変更せず、Git操作・課金変更・公開・Storage保存は行っていません。

### 6.2 長さ改善：Prompt v2 → v3

旧版の371文字はadapterが`FinishReason.stop`を確認して受け取った完了応答です。4096 token上限による打切りではありません。
旧Promptには「短い」物語と「600〜900文字を目安」という緩い指定があり、構成ごとの分量もありませんでした。
これが短くまとまる要因だった可能性がありますが、モデル内部の生成理由を断定するものではありません。モデル・output budget・Firebase設定は変更していません。

| 実request | Prompt変更 | 実測本文文字数 | 600〜900文字 |
| --- | --- | --- | --- |
| 今回1回目・v2 | あらすじではないこと、720〜820字の中心目標、6段落と具体的な展開を指定 | 966 | 未達（長すぎる） |
| 今回2回目・v3 | 650〜780字の中心目標、5段落に整理し、重複する情景描写の簡潔化を指定 | **667** | **達成** |

両方とも`lonely / cat`の**実Gemini request**で、fixture応答ではありません。二回で停止し、追加の再生成は行っていません。
v3のタイトルは「午後の窓辺と静かな足音」、生成日時は`2026-10-31T11:28:33.612500Z`。
`length_target_met: true`、`status: draft`、`human_approved: false`、`audio_status: not_generated`を表示しました。

簡易な編集所見：猫の一人称で、窓辺の待ち時間→クッションの匂い→夕空→帰宅の足音がつながります。
同一文を繰り返す水増しや医療・行動指示は見当たりません。ただし「静か」等の表現はやや定型的で、読み上げ時の自然さ・余韻は人が再確認する必要があります。
これは独立した人による採用承認や、権利・安全性の完全確認ではありません。
残ったwarningは「人の全文・安全性・権利・読み上げ確認と承認」「音声未生成・2〜3分は未測定」の2件で、長さwarningはありません。

この時点のfocused testsは**87 passed**。599/600/900/901文字の境界、タイトル/metadataを加算しないこと、本文内部のUnicode空白を除くこと、Prompt版同期を確認しました。
当時の`flutter analyze --no-pub`もNo issues found。fake testsと上記実requestは別の検証です。
この一回の達成から次回も同じ長さになるとは保証しません。この時点の実装では自動再送せず、短い/長い応答はdraftの修正対象として表示していました。現在の一回だけの長さ調整は第4節を参照してください。自動承認は追加していません。

### 6.3 一回限定の長さ調整

利用者の追加試験で547文字だったとの報告を受け、第4節の最大一回の長さ調整を追加しました。Prompt v3・Gemini adapter・対応表は変更していません。
この変更の検証はfake-based testsのみで行い、実Gemini APIは再実行していません。過去の667文字の成功を、新しいretry機能のlive成功として扱わないでください。
最新の`flutter analyze --no-pub`はNo issues found、focused testsは**104 passed**でした。追加17件で初回の600/750/900文字、547/966文字からの修正成功、二回目も範囲外、追加生成の各種失敗と初回draft保持、最大2回を確認しています。

## 7. MVP Story Libraryの制作に使う場合（2026-11-01）

- 各感情2〜3本、合計16〜24本を**コンテンツ準備中に**作ります。今回まとめて生成する処理や、アプリsession中の生成は追加しません。
- demoの結果は毎回draftです。[record template](story_record_template.json)へ移すときに、編集者が`story_id`（例：`lonely_cat_001` / `002`）、独立した`revision`、`display_order`を付けます。異なるIDでも同じ話の言い換えだけなら別の一本と数えません。
- 人の全文確認・承認後にだけStory Libraryへ保存します。元のdraftや例文を自動で`human_approved: true`にしません。
- [library template](story_library_template.json)は空のdraftです。公開catalog・Story List・音声参照の実読込は未実装です。
- 後続実装では、主感情に合う人の承認済み・音声readyの2〜3本を表示し、利用者が選んだ事前生成音声を再生します。詳細は[生成仕様・第8節](emotion_pet_story_spec.md#8-story-libraryと将来のstory-list契約)を参照してください。

本更新の確認：record/library templateのJSON、8組の対応、16本/24本を識別するIDと音声予定pathの一意性、相対リンクを検証しました。
`flutter analyze --no-pub`はNo issues found、既存のStory focused testsは104 passedです。アプリのlibrary読込・一覧filter動作を実行したという意味ではありません。実Gemini呼出し・本番story作成・human approval・音声生成は行っていません。

### 2026-11-07：v3の452文字の実結果とv4の再確認待ち

利用者がlocalhost Chromeで実Gemini成功を確認：悲しい×猫、452文字、
`length_target_met: false`、`generation_attempts: 2`、`length_retry_error: null`、
`status: draft`、`human_approved: false`、Prompt v3。
これは二回目の出力が形式/safety gateを通ったものの長さが不足したことを示します。
一回目の文字数や本文は提供されておらず、両応答が何文字だったかは復元しません。
adapterはSTOPで終わった応答だけを受け付けるため、今回の受理済みdraftをmaxOutputTokens打切りとは判断しません。
model内部の理由は不明です。文字数counterは本文のみを数え、validation不具合という証拠はありません。

v4では五段落・約20文の具体的な分量配分と720〜800文字の中心帯を示し、
retryは境界までの不足だけでなく750文字までの必要量も伝えます。452文字なら約298文字の加筆です。
単なる言い換えではなく、同じ出来事の未描写の行動・結果・動物の反応を描くよう求め、
反復、水増し、医療助言等の禁止を維持します。数値配分は執筆指針であり、自動承認条件ではありません。
600〜900文字validation、最大二requests、retry失敗時の初回draft保持は変更しません。
452→750と452→452のfake regressionを追加し、後者は警告付き未承認draftのまま終了することを確認します。

**v4の実Gemini文字数適合は未確認です。** 既存Web demoをfull restartしてprompt assetとコードを更新し、
同じChrome/originで悲しい×猫を一回生成してください。起動commandの`STORY_EMOTION=sad`、`STORY_PET=cat`を使います。
新しい結果で`prompt_version: yorisoi-story-v4`と`character_count: 600〜900`、
`length_target_met: true`が確認されるまで、長さ問題が解決したとは報告しません。
