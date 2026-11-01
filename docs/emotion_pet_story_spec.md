# Issue #10 感情×ペット用ストーリー生成仕様

作成日：2026-10-31 / 更新日：2026-11-01 / 仕様版：`yorisoi-story-library-v1`

**2026-11-01確定：** 感情ごとに異なる日本語storyを2〜3本、計16〜24本事前準備する。
人が確認・承認した原稿をStory Libraryへ保存し、将来のアプリは検出した主感情で2〜3本を絞り、利用者が選んだstoryの事前生成音声を再生する。
この更新は仕様・templateのみ。Story List、library loader、音声生成・再生は未実装。既存Gemini demo、Prompt v3、文字数検証・一回限定retryは維持する。

## 1. 目的・範囲・根拠

コンテンツ作成者が、同じ対応表・Prompt・確認手順で、日本語のPodcast用原稿を**事前に**追加できる仕様を定める。
利用者の操作ごとに物語を生成する機能ではない。音声化・再生・画面・Storageの実装は次のIssue以降で扱う。

根拠の優先順：

1. [アプリ全体仕様・第4節](app_spec.md#4-感情とペットの対応)：MVPは感情からペットを自動選択。ペット選択画面は対象外。
2. [サービス方針・第2/6/7節](api_service_policy.md)：事前生成した原稿を音声化し、初期MP3はFlutter assetsに同梱。課金・Firebase Storageは保留。
3. [Issue #9仕様・第2/9節](emotion_analysis_spec.md)：8カテゴリ、主感情必須、副感情任意、既存英語キー。
4. [GitHub Issue #10](https://github.com/sumuduudara/intern-sumudu-yorisoi/issues/10)：Geminiを候補に、Ollama/Qwenも選択可能。生成物は人が確認して採用する。本文・達成目標は作成日に読み取り確認した。

Issue本文の「ライブ配信/Podcast」は既存MVPの「事前作成MP3・ライブ配信なし」に合わせて解釈する。
今回の利用者確認を、以前の「各組1本」および「自動で一話を再生する」案より優先する。ペットの自動対応は変えず、storyは利用者が選ぶ。
以下の長さ・原稿管理・レビュー項目は本Issueで定義する制作ルールであり、過去に承認済みだったと主張しない。

## 2. 必要な組み合わせ：32ではなく8

| 日本語感情 | 既存感情キー | ペット | ペットキー | 1本目のstory ID例 | 初版の将来MP3名 |
| --- | --- | --- | --- | --- | --- |
| 悲しい | `sad` | Cat（猫） | `cat` | `sad_cat_001` | `assets/audio/sad_cat_001_r001.mp3` |
| 寂しい | `lonely` | Cat（猫） | `cat` | `lonely_cat_001` | `assets/audio/lonely_cat_001_r001.mp3` |
| 不安 | `anxious` | Rabbit（うさぎ） | `rabbit` | `anxious_rabbit_001` | `assets/audio/anxious_rabbit_001_r001.mp3` |
| ストレス | `stressed` | Rabbit（うさぎ） | `rabbit` | `stressed_rabbit_001` | `assets/audio/stressed_rabbit_001_r001.mp3` |
| 怒り | `angry` | Dog（犬） | `dog` | `angry_dog_001` | `assets/audio/angry_dog_001_r001.mp3` |
| 嬉しい | `happy` | Dog（犬） | `dog` | `happy_dog_001` | `assets/audio/happy_dog_001_r001.mp3` |
| 安心 | `calm` | Dolphin（イルカ） | `dolphin` | `calm_dolphin_001` | `assets/audio/calm_dolphin_001_r001.mp3` |
| その他 | `other` | Dolphin（イルカ） | `dolphin` | `other_dolphin_001` | `assets/audio/other_dolphin_001_r001.mp3` |

- MVPは上記8組に**各2〜3本の別の物語、合計16〜24本**を準備する。同じ話の言い換え・revision違いを別の一本として数えない。出来事・場面・小さな発見に違いを持たせる。現在16〜24本が生成・承認・音声化済みという意味ではない。
- `sad_dog`等、対応表にない24組は今回の制作対象外。英語キーの`calm`を`relieved`へ変更しない。
- 今回の確認により対象は8組とする。32組へ拡張しない。ペット選択画面も追加しない。
- 主感情をStory Libraryの検索キーにする。MVPでは副感情によって表示候補を減らしたり、別ペット・別感情へ切り替えたりしない。二感情の全組み合わせも生成しない。
- 正常な分類結果の「その他」には専用のイルカ原稿を用意する。API失敗や不正JSONを「その他」の物語で隠さない。
- 将来の検索境界は`main`→既存英語キー→上表のpet key→承認済みの対応story 2〜3本。詳細は第8節のStory Library契約に従う。今回は検索コードや画面を作らない。

## 3. 原稿の構成・長さ・語り口

### 3.1 標準の一話

| 順序 | 内容 | 目安 |
| --- | --- | --- |
| 1 | 動物のいる場所、光・音・匂いなどで静かに始める | 全体の約15% |
| 2 | その動物が経験する、小さな出来事と気持ちの揺れ | 約35% |
| 3 | 動物自身が見つける小さな変化・発見。問題の完全解決は不要 | 約35% |
| 4 | 余韻のある終わり。聞き手への指示や教訓で閉じない | 約15% |

- 推奨音声時間は**2〜3分**。初稿本文はおおむね**600〜900文字**を目安とする。タイトル、JSON記号、制作メモは文字数に含めない。句読点を含み、空白・改行を除いた本文のUnicode文字数で記録する。
- 文字数から時間を保証しない。音声化後に実際の秒数を測る。遅い読み・間で3分を超えたら、原稿を見直して再承認するか、長さの例外理由を承認者が記録する。
- 日本語、短めの文（原則一文20〜50文字程度）、読み上げやすい語彙。本文は一人称「ぼく」と、柔らかい「です・ます」調に統一する。性別・年齢を断定する設定は追加しない。
- タイトルは日本語8〜24文字程度。過度な感嘆符、難読語、URL、絵文字、箇条書き、Markdown、SSML、話者ラベルを本文へ入れない。
- 情景・行動・内心を動物の視点で語る。聞き手の感情を言い当てたり、「あなたは〜すべき」と助言する構成にはしない。
- 「嬉しい」は喜びを抑え込まず、「怒り」は怒ること自体を悪とせず、「その他」は隠れた病気や悩みを推測しない。

### 3.2 ペットの性格（本仕様の制作上の指針）

| ペット | 語りの特徴 | 小さな日常の例 | 避ける描写 |
| --- | --- | --- | --- |
| 猫 | 静か、観察好き、近さと距離を急いで決めない | 窓辺の日だまり、布の匂い、足音 | 孤独を罰とする、聞き手を依存させる約束 |
| 犬 | 素直、親しみやすい、元気さの中にも穏やかさ | 散歩の葉、玄関の音、日陰 | 怒りの否定、威嚇・攻撃の正当化、喜ぶ義務 |
| うさぎ | 慎重、小さな変化に気づく、自分の歩幅 | 草の影、耳に届く風、木陰 | 怖がりを弱さとする、危険への無理な挑戦 |
| イルカ | ゆったり、好奇心、広い海と小さな発見 | 水面の光、仲間との距離、浅い湾 | 長い潜水・呼吸の指示、万能な救済役 |

これはFigmaの絵・名前・色の変更指示ではない。動物の日常を借りた創作であり、生態学的な教材や人間のカウンセラー役として扱わない。

## 4. 安全性と個人情報

生成Promptと人の確認の両方で、次を確認する。

- 感情を否定・評価・比較しない。「気にしすぎ」「怒ってはいけない」「もっとつらい人がいる」「必ず元気になる」は不可。
- 病名の推定、診断、治療、服薬・受診中止、医学的助言、効果の保証をしない。物語は医療や相談の代替ではない。
- 自傷・他害・虐待・暴力の具体的描写、危険行動の勧め、恐怖をあおる展開を入れない。
- 人間の悩みを分析する相談員の会話、「ぼくだけを頼って」「ずっと見守っている」等の監視・排他的依存表現を避ける。
- 呼吸法、体調改善法、運動等を聞き手へ処方しない。動物自身の普通の行動描写と、利用者への指示を区別する。
- 実利用者の入力文章、音声、名前、email、Auth UID、token、Firebase設定を生成素材にしない。制御された感情名とペット名だけを使う。
- 有名作品・実在人物の模倣、既存作品の引用、声の無断複製を求めない。第三者の文章を流用した疑いがあれば採用を止め、出典・権利を確認する。AI生成だから権利確認不要とはしない。
- キーワード検査だけで安全と判定しない。皮肉、否定、文脈も人が全文を確認する。危機対応機能の実装は本Issueに含めない。

## 5. 生成候補と再現性

### Gemini（第一候補）

既存Issue #9の`FirebaseAI.googleAI()` / `gemini-3.5-flash-lite`を、事前の文章制作にも使う候補とする。
[Firebase公式モデル一覧](https://firebase.google.com/docs/ai-logic/models)で作成日に同IDを確認した。
既存の感情分類service・system prompt・1024 token上限は変更せず、制作demoの別serviceで**物語Prompt v3**を使用する。既存の長さ検証・最大一回の調整retryも維持する。
実行前にその時点のモデル提供、利用枠、プロジェクト権限、出力条件を確認する。課金を有効にせず、枠不足なら停止する。今回は生成APIを呼ばない。

### Ollama / Qwen（任意のローカル代替）

Ollamaに導入したQwen系モデルへ同じPromptを渡す方法を許容する。候補例は公式配布の`qwen3:4b`。
採用時にモデルtagだけでなくdigest、量子化、Ollama版、利用条件を記録する。日本語品質と安全性はGeminiと同じ基準で確認する。
8 GB Macでは余裕を保証しない。小型候補でもメモリ・発熱・速度を確認し、他の重い処理と並行実行しない。今回はインストール・download・推論を行わない。
ローカルに導入したモデルのlocalhost実行と、クラウドモデル呼び出しを区別する。ローカル代替だから生成物の権利確認が不要になるわけではない。

### 共通ルール

- 完全な文章の一致を再現性の条件にしない。同じ条件でもモデル更新や非決定性で文章は変わる。
- **再現するものは対応表、Prompt版、置換値、モデル/実行条件、レビュー基準、採用済み原稿そのもの。** 同一原稿が必要なら再生成せず、承認済みファイルを使う。
- [共通Prompt](story_generation_prompt.md)の指定blockだけをUTF-8/LFで保存し、`{emotion}`と`{pet}`を表の日本語値で一括置換する。Promptのその他の部分は変更しない。
- 置換済みPromptのファイルとSHA-256、実行日時、モデルID/版、provider、SDKまたはツール版、明示した生成parameters、停止理由をrecordへ残す。指定していないparametersは`null`または空objectとし、設定済みのように書かない。
- seed/temperature等は選んだAPI・モデルがサポートすると確認できた場合だけ指定する。未対応parameterや、他モデルと同じ値による同一出力を前提にしない。
- 一回につき一組・一話。Geminiの安全block、quota、通信失敗、途中打切りは失敗として記録し、本文を採用しない。自動大量再試行や無断モデル切替はしない。
- Ollamaの思考用出力は物語に混ぜず、完了応答から本文を取り出す。どちらも生成直後のJSONを検証し、人が読む前に壊れた出力を弾く。

## 6. 出力契約・原稿レコード

AI出力は次の2キーだけのJSON object。両方とも空でない日本語文字列とする。

```json
{"title":"窓辺に残った午後の光","story_text":"ぼくは、窓のそばの布に座っていました。"}
```

上は形式を示す短い例で、完成原稿ではない。JSON以外の囲み、説明、余分なキーは不可。
不正JSON、欠落、null、配列、空文字、途中打切りは差戻し。人が本文を書き直す場合も原稿版を記録する。
モデルに承認状態・レビュー結果・権利確認を書かせない。これらは人が管理する。

[story_record_template.json](story_record_template.json)はコピー用の未記入draft。現時点で採用済みstoryや実行結果ではない。
複数story対応のためrecord schemaをv2とする。旧`lonely_cat_v001`等は単一話の説明用IDだった。旧ファイルを自動改名・移行せず、新しい制作recordでは下記のIDと独立したrevisionを使う。

| 項目 | 必須ルール |
| --- | --- |
| `schema_version` | 本版は`yorisoi-story-record-v2` |
| `story_id` | `{emotion_key}_{pet_key}_NNN`。末尾は物語の識別番号。例：`lonely_cat_001` / `002` / `003`。全体で一意、削除・撤回後も別の話に再利用しない |
| `revision` | 正の整数。本文修正時に上げる。IDは維持し、過去のrecord・承認を上書きしない。公開catalogは同じIDのactive revisionを一つだけ含める |
| `emotion` / `pet` | 日本語値と英語キーが第2節と一致。対応外の組は不可 |
| `language` / `title` / `story_text` | `ja-JP`、表題と本文。空文字を許すのは記入前draftのみ |
| `content_sha256` | 確定本文をUTF-8/LF、末尾改行なしに正規化したbytesのSHA-256。本文変更で再計算 |
| `generation` | origin（`gemini` / `ollama_qwen` / `specification_example`）、モデル・Prompt・条件・時刻等。仕様の説明用例文と、記録のあるモデル実行を区別する |
| `character_count` / `target_duration_seconds` | 上記文字数、推奨120〜180秒。文字数から算出した実測時間は書かない |
| `status` / `human_approved` | 下記stateと人の承認boolean。template・demoは`draft` / `false`。人の承認情報と対象本文hashが揃うまでtrueにしない |
| `display_order` | 同じ主感情内の表示順。正の整数で重複不可。MVP初期は1・2、3本目がある場合は3。生成モデルではなく編集者が設定 |
| `review` | 確認者の内部ID、確認時刻、全確認項目、差戻し理由。email・個人情報は不要 |
| `approval` | 採用判断をする人の内部ID・日時・対象本文hash。生成者やAIが自動承認しない |
| `audio_handoff` | 承認後の原稿ID・本文hash、読み指定、予定asset path。音声未作成なら実測秒数と音声hashはnull |

時刻はISO 8601（UTCの`Z`、または明示offset）。未実施は空欄ではなく`null`、未確認のチェックは`false`。
生成/レビュー担当の役割は分ける。担当人数が少ない場合もメンター等の明示承認を採用gateとし、承認者未定ならdraftのままにする。

## 7. 生成→人の確認→承認→保存

```text
対応表から1組を選ぶ
  → 共通Promptを置換し、版・hash・実行条件を記録
  → 一話生成（または手書き例を明示） → JSON/対応/文字数を確認
  → draft → in_review → approved_text / human_approved=true
                         → Story Libraryへ保存 → 次Issueの音声化・聴取承認
                  ↘ needs_revision → 新しい原稿版 → 再レビュー
```

`rejected`は採用しない記録の終端。`in_review`には必須原稿・生成記録が揃っていることが必要。
`needs_revision`は直す理由を残す。`approved_text` / `human_approved: true`への遷移は全チェックと人の明示承認が揃った時だけ。
本文を変えたら同じIDのrevisionを上げ、`draft` / `human_approved: false`として作る。旧版の承認記録は消さない。
生成失敗・出力検証失敗はdraftに失敗メモを残し、`approved_text`へ進めない。

### 作成者が新しい話を追加する手順

1. 第2節から組を選び、その感情で異なる話が2〜3本になるよう計画する。ID・revision・display_orderの重複と、既存話との内容重複を確認する。対応表は変えない。
2. templateを新しいrecordへコピーし、ID・感情・ペットを設定する。
3. Prompt blockを抽出して置換する。例：`{emotion}`→`寂しい`、`{pet}`→`猫`。英語keyはrecord側へ保存する。
4. コンテンツ準備時に[既存Gemini demo](story_generation_demo.md)を一話ずつ使い、必要な生成物を制作recordへ移す。利用者のアプリsessionでは生成しない。demo自身はファイル保存・採番・人の承認を行わない。raw出力・実行条件を記録し、実ユーザーの文章や秘密情報を入力・保存しない。
5. JSONをparseし、title/story_textが文字列で空でなく、余分なキーがないことを確認する。日本語・長さ・動物視点は人も確認する。
6. 本文を声に出して読み、次の全項目を確認する。問題があれば理由を付けて差し戻す。
7. 承認者が本文hash付きで`approved_text` / `human_approved: true`にする。準備済みの例文を無断で承認扱いにしない。
8. 承認済みrecordと原稿を再利用可能なStory Libraryへ保存し、音声担当へ同じID/revision/hashを渡す。別の話を追加するときは別IDを採番し、既存の話を複製して本数を満たさない。

### 人が確認する採用チェック

- [ ] 感情・ペット・IDが対応表と一致する。
- [ ] 動物の一人称の小さな日常で、カウンセラーの助言ではない。
- [ ] 感情の否定・診断・治療・医療助言・危険/依存表現がない。
- [ ] 読みやすい日本語、構成、語り口、タイトル、文字数が適切。例外は理由がある。
- [ ] 個人情報・秘密・第三者作品の流用がなく、利用条件/出典を確認した。
- [ ] 声に出して読み、難しい読みや誤読候補を別の読み指定欄へ記録した。
- [ ] Prompt/モデル/実行条件・原稿版・本文hashが記録されている。

### 保存の責任と将来の配置

Story Libraryは再利用可能な承認済み原稿の集合と、その公開用catalogを指す。新しいクラウドサービスではない。
将来の制作時は、レビュー用の`content/stories/drafts/{story_id}/rNNN/`にrecord、原稿、置換済みPromptをまとめ、承認済み原稿を`content/stories/approved/{story_id}/rNNN/`へ保存する（今回はdirectory未作成）。
公開用catalogの形式は[story_library_template.json](story_library_template.json)。これは`publication_status: draft`、`stories: []`の空templateであり、承認済みlibraryではない。将来の配布先は`assets/stories/story_library.json`を予定し、今回asset登録・loader・exporterは作らない。
draftには拒否/差戻しも記録し、承認済み原稿を上書きしない。公開repoへ入れるのは権利・秘密情報を確認した制作物だけとする。
不要なraw request metadata、credentials、個人の実行環境設定はrepo外で管理する。

## 8. Story Libraryと将来のStory List契約

### 8.1 必須metadataと編集recordからの公開projection

公開catalogは`schema_version: yorisoi-story-library-v1`、`language: ja-JP`、`publication_status: draft | approved`、`stories`配列を持つ。
各entryのmetadataは次のとおり。編集record全体をそのままアプリへ同梱せず、下記fieldだけを投影する。Prompt、raw応答、内部reviewer ID、credentialsを公開catalogに入れない。

| 公開field | 契約 |
| --- | --- |
| `story_id` / `revision` | 一意IDとactive revision。IDの重複を許さない |
| `emotion` / `pet` | 編集recordと同じ`{label, key}`。日本語と英語キー、対応表が一致 |
| `language` / `title` / `story_text` | `ja-JP`、日本語タイトル、承認済み本文。本文から勝手に要約・改稿しない |
| `status` / `human_approved` | `approved_text` / `true`が必須。片方だけ合っていても表示不可 |
| `display_order` | 感情内の正の表示順 |
| `audio` | `{status, asset_path, duration_seconds, source_revision}`。音声未生成時は`not_generated`、path/duration/source_revisionはnull。予定pathは編集recordに残す |

`audio.status`は`not_generated / in_review / ready / rejected`。`ready`は次の音声Issueで生成・聴取・利用条件を人が確認してから設定する。
`ready`ならasset pathは`assets/audio/{story_id}_rNNN.mp3`、実測durationは正の秒数、source_revisionはstory revisionと一致させる。例：`assets/audio/lonely_cat_002_r001.mp3`。
`duration_seconds`は音声未作成ならnull。文字数から推測して実測値として入れない。

entryの構造例（未記入draft。公開対象ではない）：

```json
{
  "story_id": "lonely_cat_001",
  "revision": 1,
  "emotion": {"label": "寂しい", "key": "lonely"},
  "pet": {"label": "猫", "key": "cat"},
  "language": "ja-JP",
  "title": "",
  "story_text": "",
  "status": "draft",
  "human_approved": false,
  "display_order": 1,
  "audio": {
    "status": "not_generated",
    "asset_path": null,
    "duration_seconds": null,
    "source_revision": null
  }
}
```

これは書式例であり、人の承認を経ずにstatus/booleanだけを書き換えて公開してはいけない。公開projectionの作成者が編集recordの承認者・日時・本文hashと一致することを確認し、library全体も人がrelease reviewする。

### 8.2 将来の絞り込み・表示順（仕様のみ・コード未実装）

```text
分析成功 → main_emotionを既存enum/keyへ検証・変換
  → 対応するペットを既存mappingで決定
  → publication_status=approved のStory Libraryを読む
  → emotion一致 AND pet一致 AND status=approved_text AND human_approved=true
  → title/body/ID/order等が正常 AND audio.status=ready
     AND audio参照が存在 AND duration>0 AND source_revision一致
  → display_order昇順（同順はstory_id順）→ 最大3本 → Story List
  → 利用者がstory_idを選択 → 対応する事前生成音声を再生
```

- 初期releaseの内容確認で**各感情2〜3本、全体16〜24本**の異なる承認済みstoryと、対応するready音声が揃うことをgateにする。本文承認だけで音声準備完了にはしない。
- 初期配布では各感情のdisplay_order重複をrelease errorにする。二次sortは不正データ時にも表示が不安定にならないための防御であり、重複を承認するものではない。
- `draft / in_review / needs_revision / rejected`、`human_approved=false`、不明status・欠落metadataは常に除外する。library自体がdraftなら全件非表示。端末設定でこのgateを解除しない。
- 標準時は2〜3本を表示し、ペットを選ぶ画面ではなく「同じ感情に対応する別の物語」を選ぶ画面とする。自動random選択・自動生成・勝手な自動再生はしない。
- データ欠損等で0本なら「この気持ちの物語は準備中です」とHomeへ戻る操作。1本しか有効でなければ存在する1本だけと準備不足の案内を表示する。別感情・別ペット・draft・重複で本数を埋めない。
- 選択後にasset欠損・読込失敗が判明した場合は再生失敗を案内し、一覧へ戻れるようにする。生成APIをfallbackとして呼ばない。例外系UI・player実装は後続Issue。
- API失敗を`other`へ変換しない。副感情で別のリストに切り替えない。利用者の本文・Auth情報はlibrary検索条件に含めない。

### 8.3 追加・修正・撤回

新規話は別ID、同じ話の改稿は同じIDの新revision。承認後の本文改稿は再レビューと再音声化が必要。
公開catalogのactive revisionと音声source_revisionを同時に更新し、古い本文に新音声が混ざらないようにする。
撤回する話は次のcatalogから除き、制作記録を残す。未承認新版があるだけで承認済み旧版を自動置換しない。

## 9. 次の音声生成Issueへの引継ぎ

引継ぎ対象は**承認済みrecord、本文、title、ID/版/hash、ja-JP、動物、読み指定、120〜180秒の目標、利用条件**。
音声担当はvoice候補/版/許諾/読み速度/生成parameters、実測時間、形式、音声hash、聴取レビューを別途記録する。
音声provider、話者、sample rate、bitrate、音量・間の調整値は次Issueで決める。猫の声などの無断な声真似を前提にしない。

- 旧来の1組1ファイル案は複数話で衝突するため、今回確認したStory Libraryでは`assets/audio/{story_id}_rNNN.mp3`へ更新する。これは命名仕様の更新で、既存MP3を改名・削除する作業ではない。
- `audio_handoff.asset_path`は予定値であり、ファイルの存在を保証しない。音声化前は`status: not_generated`、実測時間・hashはnull。
- 原稿承認≠音声承認。音声を聞いて誤読・欠落・過大音量・不自然な間・動物らしさを確認してから配布を判断する。
- 音声化時に本文を変えたら原稿を新版として再承認し、新hashを使う。
- 初期配布は既存方針どおりFlutter assets。Firebase Storage/Billingを有効化しない。TTS設定・pubspec登録・player・Pet Room UIは今回作らない。

## 10. 未確定事項と今回の検証

| 項目 | 今回の扱い |
| --- | --- |
| MVPの本数 | 8組に各2〜3本、計16〜24本に確定。32組に拡張しない |
| 主/副感情と選択 | 主感情で絞り、表示順はdisplay_order、利用者が一話を選ぶ。副感情は絞り込みに使わない。実装は後続 |
| 2〜3分 | 制作目標。実音声時間・声・音質は音声Issueで確認 |
| 本番の生成モデル・ローカルモデル | Gemini demoの過去の実request記録は別書参照。16〜24本の制作・品質確認やOllama性能確認は未実施 |
| 人の承認 | 本書の例文もtemplateも未承認。承認者の割当と16〜24本の完成は今後の制作作業 |
| 次Issueの音声 | provider/声/許諾/音声品質は未決定。音声生成・再生は未実施 |
| 将来の画面遷移 | 本更新のStory List→利用者選択→事前音声を優先する。過去#7/#9の「Room一覧」や自動一話選択は旧案。UI/route実装は後続 |

達成目標「第三者が同じルール・Promptで追加できる仕様」に対し、対応表・作成手順・Prompt・record・採用gate・音声引継ぎを本書で定義した。
今回の更新はtemplate JSON/metadata・対応表・命名・相対リンク・既存コード保持の確認と、既存Story focused tests/analysisで検証する。
新しいAI生成成功、human approval、TTS、音声時間・再生、Story List実装のPASSは報告しない。重いbuildやSimulator確認は行わない。

## 11. 関連ファイル・公式参考

- [共通Prompt](story_generation_prompt.md)、[原稿record template](story_record_template.json)、[Story Library template](story_library_template.json)、[日本語例文8組](story_examples.md)、[既存の制作用Gemini demo](story_generation_demo.md)
- [Firebaseの文章生成](https://firebase.google.com/docs/ai-logic/generate-text)：既存Gemini demoで利用する文章生成の公式手順。本更新でAPIを呼ばない。
- [Firebase対応モデル](https://firebase.google.com/docs/ai-logic/models)：候補IDの掲載確認。project権限・利用枠の正常動作の証明ではない。
- [Ollama generate API](https://docs.ollama.com/api/generate)：ローカル候補の呼出し形式・完了応答の参考。
- [Ollama公式Qwen3配布](https://ollama.com/library/qwen3)：候補tagの参考。導入・品質の確認とは区別する。
