# Issue #11 配信ストーリーデータ管理仕様

作成日：2026-11-02 / 実行用data schema：`yorisoi-story-data-v1`

**最新状態（2026-11-03）：Chromeで実Firebase Auth確認と`Source.server`によるdraft library読込を利用者が確認済み。最終review・検証結果は第12節。第8〜11節の未確認/エラーは当時の履歴。公開storyの実取得はまだ未検証。**

## 1. 目的・既存決定・今回の範囲

[Issue #11](https://github.com/sumuduudara/intern-sumudu-yorisoi/issues/11)の登録・検索・表示metadataを定義し、実行可能なDart model / repository / local fixture demoで検証する。
[Issue #9](emotion_analysis_spec.md)の`EmotionAnalysisResult.main`、[Issue #10](emotion_pet_story_spec.md)の人の承認・revision・事前音声・表示順を継承する。

| 主感情キー | 日本語 | ペットキー |
| --- | --- | --- |
| sad | 悲しい | cat |
| lonely | 寂しい | cat |
| anxious | 不安 | rabbit |
| stressed | ストレス | rabbit |
| angry | 怒り | dog |
| happy | 嬉しい | dog |
| calm | 安心 | dolphin |
| other | その他 | dolphin |

MVPは各感情に異なる2〜3話、計16〜24話。副感情による別ペットへの変更・候補削減は行わない。
生成・原稿review・音声制作は準備時に行う。利用者のsession中に生成しない。
Story List・player・TTS・Storage・大量のstory制作は今回実装しない。Firestore read-only adapterを追加し、metadataはFirestore、MP3はbundled assetsというMVP構成とする。

## 2. 編集用recordと実行用データを分ける

- Issue #10の`yorisoi-story-record-v2`は制作・承認の履歴。Prompt、raw出力、内部reviewer ID等を含み得るため、そのまま配布しない。
- Issue #10のsnake_case catalogは維持する。Issue #11のJSON/Firestore documentは下表のflat camelCaseをcanonical形とする。
- `Story.fromLibraryJson()`で旧catalog entryを明示変換できる。ただし`description`、`isActive`、`createdAt`、任意`imageUrl`を編集者が補完する必要がある。欠落した承認・公開flagや日時を勝手に推定しない。
- `docs/story_library_template.json`の空draftはそのまま読め、常に0件を返す。以前のtemplateや例文を人の承認済みデータへ書き換えない。
- JSON root：`schemaVersion`、`language: ja-JP`、`publicationStatus: draft | approved`、`stories`配列。library自体がdraftなら全件非表示。

## 3. metadata・validation

| field | 型・単位・制約 |
| --- | --- |
| storyId | `{emotion}_{petType}_NNN`。001以上の3桁識別番号。全体で一意、別の話へ再利用しない |
| emotion | 上表の英語キー。Issue #9の日本語mainを既存enumで検証してから変換 |
| petType | cat / dog / rabbit / dolphin。emotionとの対応が一致すること |
| title | 空でない日本語タイトル、最大80 Unicode code points。制作上の推奨8〜24文字は#10を継承 |
| description | 空でない日本語の短い紹介、最大300 code points。編集者がreviewし、個人情報を入れない |
| storyText | 承認した日本語本文、空不可、metadata読込の上限4000 code points。600〜900文字と安全性の制作reviewを置き換える上限ではない |
| language | ja-JPのみ |
| audioPath / audioUrl | nullable。ready時はどちらか一方。assetは`assets/audio/{emotion}/{petType}/story_NNN.mp3`または互換用`assets/audio/{storyId}_rNNN.mp3`。JSONの旧URLはuserinfo/query/fragmentなしのHTTPS。Firestore MVPではaudioPath必須・audioUrlはnull |
| imageUrl | nullableの同様のHTTPS URL。未用意ならnull。Figma artworkを変更・追加せず、今後の画面側で既存pet artworkを使う方針を別途確認 |
| duration | nullableの正の有限数、**秒**。ready時は実測値必須。文字数から推定しない |
| isActive | 必須boolean。falseは撤回・非表示。読込側がtrueにしない |
| createdAt | JSONはtimezone付きISO 8601、内部はUTC DateTime。FirestoreはTimestamp変換。登録日時であり、再読込のたびに生成しない |
| revision | 正の整数。本文を直したら版を上げ、承認・音声を再確認。同一IDの複数active revisionは配布しない |
| approvalStatus / humanApproved | draft / in_review / needs_revision / approved_text / rejected とboolean。approved_textの時だけtrue。矛盾するrecordは不正 |
| audioStatus | not_generated / in_review / ready / rejected。readyは音声の制作・聴取・許諾確認後に人が設定 |
| audioSourceRevision | nullableの正の整数。ready時はrevisionと一致必須 |
| displayOrder | 正の整数。同じ感情内で重複しないようrelease確認。repositoryは同順ならstoryId順で安定化 |

URLに埋め込んだtokenや期限付き署名をcatalogへ保存しない。今後認証付き配信が必要なら別の認証/URL解決境界を設計する。
不正値の例外へ本文・URL・日時の生値を入れない。文字や日本語の存在チェックは内容の安全性・人の承認の証明ではない。

### JSON / Firestore serialization

`Story.fromJson()` / `toJson()`はcanonical fieldsを読み書きする。toJsonのmapを書き換えてもimmutable modelの状態は変わらない。
`toFirestore(encodeTimestamp: ...)` / `fromFirestore(decodeTimestamp: ...)`はtimestamp変換関数を注入する。実adapterでcloud_firestore 7.1.0を使用する。

実SDK adapterでは次の変換を渡す：

```dart
story.toFirestore(encodeTimestamp: Timestamp.fromDate);
Story.fromFirestore(data,
  decodeTimestamp: (value) => (value as Timestamp).toDate());
```

このserializerはSDKへ渡すMapの契約を検証するもので、Firestoreから実データを読んだという意味ではない。serverTimestampを使う場合は書込側で扱い、未確定Timestampは公開repositoryへ流さない。

## 4. 実装したrepositoryの取得・除外

`StoryRepository`は`findByEmotion()`、`findForAnalysis()`、`findById()`のread専用境界。
`JsonStoryRepository`にJSONを読む関数と音声存在を確認する関数を注入する。保存・承認・公開・生成APIは持たない。

1. JSON rootのschema/language/storiesを確認。draft libraryは0件。不明形式・不明publication statusは安全なcatalog error。
2. 各recordをvalidate。不正recordは除外し、他の正常な候補は取得できる。欠落flagに安全でないdefault値を補わない。
3. 同じstoryIdが複数ある場合は、revisionを推測せずそのIDをすべて除外する。
4. `isActive=true AND approvalStatus=approved_text AND humanApproved=true AND audioStatus=ready`だけを残す。readyはduration/参照/revision整合が検証済み。
5. Issue #9の`result.main`とemotionが一致するrecordだけを抽出。副感情・利用者の原文・Auth情報は検索に渡さない。
6. displayOrder→storyIdの順に並べ、注入された`audioAvailable`で参照の存在を確認。最大3件を返す。

通常は2〜3件。0件なら準備中、1件なら実在する1件と不足案内を将来のUIで表示する。別感情・未承認・重複で補完しない。
`findById()`にも同じ公開・音声gateを適用する。draftのIDを直接指定しても取得できない。
JSON読込失敗・不正catalog・audio verifier障害はそれぞれ`StoryDataException`のsafe code。正常な0件と障害を混同しない。
sourceは呼出しごとに読み、今回cacheは実装しない。source同一ファイルの更新は制作側でvalidate後にatomicに差し替える想定。

`audioAvailable`は必須。将来のFlutter adapterはasset manifestまたは承認済みremote media manifestを確認する。
単にURLが文字列で存在するだけでは音声ファイルの存在・再生成功は保証できない。今回のfixture demoだけはその確認を明示的に模擬する。

## 5. 登録・保存・更新の手順

1. 制作担当が既存Gemini demo等で作ったdraftへIDとrevisionを付与する。各感情2〜3話を準備する。
2. #10のreview後、権限を持つ人が本文hash・承認日時を確認。クライアントやAIがhumanApprovedをtrueにしない。
3. description、createdAt、displayOrder、公開対象のmetadataを補完し、編集recordからcanonical documentへ投影する。
4. 音声担当が事前音声・実測duration・音声source revisionを確認。未用意はaudioStatus=not_generatedとして非表示。
5. 制作用validateと公開reviewで全8感情に2〜3話、ID/order重複なし、音声参照の存在と許諾を確認する。
6. 人が承認したreleaseだけを配布catalogまたは将来のFirestore storiesへ公開。下書き用データは別保管。
7. 修正は同じIDの新revisionとして再承認・再音声化。公開時は本文と音声の版を一緒に変更し、旧履歴を残す。撤回はisActive=falseまたは公開catalogから除外する。

今回、登録・書込・公開の管理ツール、catalog exporter、16〜24本のproduction dataは作らない。

## 6. 実Firestore repository（read-only）

rulesとstories用indexは利用者がConsoleへ設定済み・index Enabledと報告。以下は初期導入/変更時の手順であり、再deployの依頼ではない。開発者はdeployしていない。

### schema / 保存先

```text
storyLibraries/current                 # schemaVersion / language / publicationStatus
stories/{storyId}                      # 第3節のcanonical fields、createdAtはTimestamp
storyDrafts/{storyId}/revisions/{rNNN}  # 制作用、client read/write禁止
storyRevisions/{storyId}/revisions/{rNNN} # 旧版、client read/write禁止
```

`storyLibraries/current`のschemaVersionは`yorisoi-story-data-v1`、languageは`ja-JP`、publicationStatusは`draft | approved`。
MVPではFirestoreにmetadataのみ保存し、MP3 binary・感情原文・credentials・review担当の個人情報は保存しない。
利用者は生成・登録・承認・更新できない。信頼できる管理者が第5節の人のreview後にのみ登録する。
音声は例`assets/audio/happy/dog/story_001.mp3`。Firebase Storage URLとして解釈しない。
NNNはstoryId末尾と一致、emotion/pet folderは既存mappingと一致必須。旧versioned asset pathも互換性のため維持。
同じpathでrevisionを変更する場合は**アプリ同梱音声も一致する版でrelease**する。異なるapp版の混在を避けるには旧versioned pathを使い、版ごとのmanifestを管理する。
`audioSourceRevision == revision`だけでは古いアプリの実音声一致まで証明できない。

### 実装と呼出し

- `FirebaseStorySource`が実cloud_firestore SDKを使う。`Source.server`で読み、cacheだけを実通信成功として扱わない。
- `FirestoreStoryRepository.firebase(firestore: FirebaseFirestore.instance)`で既存初期化済みinstanceを渡す。AuthやFirebase設定は変更しない。
- `findForAnalysis(result)`はIssue #9のmainだけを検索条件にする。secondaryや元の感情文は送信しない。
- `findByEmotion(EmotionCategory.happy)`はemotion=happy、petType=dog、language=ja-JP、isActive=true、humanApproved=true、approvalStatus=approved_text、audioStatus=readyを指定する。
- displayOrder ASC → document ID ASC。1page 10件、最大10page/100候補。validate・asset確認後の最大3件で停止。無制限scan/自動再送なし。
- document IDとstoryId、Timestamp、mapping、revision、durationなどを再validate。不正/未公開/URL-only/asset欠損は除外する。
- libraryがdraftなら空。missing/不正libraryはinvalidCatalog。通常の0件は例外ではなく「準備中」。
- `findById`も同じgateを通す。未公開documentの直接getはrulesによりpermission errorになる場合がある。未公開本文は返さない。
- timeout/unavailable/deadline-exceededはnetwork、permission-denied/unauthenticatedはpermissionDenied、failed-precondition/not-foundはconfiguration、その他はreadFailed。raw SDKエラーや本文をUI/logへ出さない。
- `bundledStoryAudio(rootBundle)`は実AssetManifestに参照があるか確認する。未登録/未同梱なら除外。再生成功・音声品質の保証ではない。

```dart
final live = FirestoreStoryRepository.firebase(
  firestore: FirebaseFirestore.instance,
);
final stories = await live.findForAnalysis(emotionResult);
```

### JSON offline fallback

`JsonStoryRepository`を維持し、`FallbackStoryRepository(primary: live, offline: approvedLocalRepository)`で明示的に選択可能。
offlineにはreview済みcatalogと`audioAvailable: bundledStoryAudio(rootBundle)`を渡す。fixtureは本番用に使わない。
**networkだけ**fallbackする。permission/configuration/不正catalog/正常0件/draftはfallbackしない。
受信済みFirestore本文を独自永続化しない。offline catalogはアプリrelease時のsnapshotなので、後日撤回をofflineで即座に反映できない。
撤回即時性を必須とするreleaseではfallbackを使わず、通信復旧後に再試行する。
本タスクではproduction catalogもMP3も追加しないため、通常アプリへのfallback/UI接続はまだ行わない。

### rules・index・安全な手動deploy（今回は実行しない）

プロジェクトファイル：`firestore/story.rules`、`firestore/story.indexes.json`、専用`firebase.story-data.json`。
既存`firebase.json`は変更しない。rulesは認証済みreadのみ・client write禁止・library公開gate・story公開gate・list limit<=10。残りをdenyする。
queryにも公開条件が必要。rulesはfilterではない。
indexは実queryと同じ7 equality fields、displayOrder ASC、document ID ASC。storyText/descriptionはsingle-field indexing対象外。

1. Firebase Consoleで対象project、Firestore API、default databaseの有無、既存rules/indexを確認する。database未作成ならownerがregion/無料枠を確認して判断する。billingやpaid Storageを有効にしない。
2. 既存rules/indexを安全に控える。このrulesは**独立した最小案**であり、無関係な既存collectionの許可を含まない。既存rules/indexがあれば必ず統合reviewしてからdeployする。複数allowはORなので別の広いallowがdraftを許さないかも確認する。
3. 専用環境で許可/拒否・draft・query・indexを検証する。local Rules emulatorによるコンパイル・許可/拒否の最新結果は第10節。production indexの適合・完成は別途確認する。
4. owner承認後、下記を**手動でのみ**実行。これは既存rules/indexに影響し得る操作なので、盲目的にcopy/pasteしない。--projectは対象IDを明示し、firebase use/initを不要にする。

```sh
# owner review / authorization 後のみ（この作業では実行していない）
firebase deploy --project yorisoi-emotion-test --config firebase.story-data.json --only firestore:rules,firestore:indexes
```

5. index完成を待つ。人の承認済みmetadataと一致するMP3をアプリへ同梱し、pubspec.yamlのassetsに各folder/ファイルを明示してpub getする。Flutter asset directory指定は任意の深さのsubdirectoryを自動登録するものではない。
6. 登録・withdrawalは管理者側でvalidate。Admin SDKはrulesを迂回するためIAMも制限する。サンプルを承認済みproduction storyとして登録しない。

無料枠は無制限ではない。read/index/rules内getの利用量を確認する。今回billing変更・API有効化・database作成・deploy・story書込は一切行っていない。
参考：[公式rules/query](https://firebase.google.com/docs/firestore/security/rules-query)、[公式index管理](https://firebase.google.com/docs/firestore/query-data/indexing)、[公式無料枠](https://firebase.google.com/docs/firestore/quotas)。

### Chrome実readデモ

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
# まず通常アプリでログイン。同一Chrome profile、同一scheme/host/portを使う。
flutter run -d chrome --web-port 8879
# 停止後、同じChrome profileのタブで次を実行（web-server URLを開く）
flutter run -d web-server --web-port 8879 -t lib/story_firestore_demo.dart
```

通常のflutter runが一時Chrome profileを使う場合、前後でsessionが共有されない。確実にするには両entrypointとも`-d web-server --web-port 8879`を使い、同じ通常Chromeタブでログイン→停止→demo起動→reloadする。
デモは認証情報を入力・保存せず、既存Firebase Auth sessionを使う。「Happyを実Firestoreから読む」は本物のSDK/server request。mock/fallbackは使わない。
初期化/未ログイン/permission/network/catalog errorと正常0件を区別する。Story List/playerではない。
assetsがまだない場合、Firestoreにmetadataがあっても結果は0件になる。Firebaseを操作して仮の承認済みstoryを追加しない。

## 7. ローカルデモ・テスト

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
dart run tool/story_data_demo.dart happy
# 日本語でも可：dart run tool/story_data_demo.dart 嬉しい
# 空結果の確認：dart run tool/story_data_demo.dart anxious
```

Firebase・network・実AI不要。fixtureは`test/fixtures/story_library_demo.json`で、通常のapp assetsへ登録しない。
Happyは順番にhappy_dog_002、happy_dog_001、happy_dog_003を返す。別感情、draft、inactive、音声未準備、矛盾した承認、誤ったpet、不正recordを除外する。
承認flag・音声ready・音声存在は**テスト用模擬値**。example.invalidのURLは実音声ではなく、このdemoをhuman approvalやaudio playback成功の証拠にしない。

```sh
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded \
  test/story_data_test.dart test/story_generation_service_test.dart \
  test/firebase_story_model_test.dart
```

metadata/serialization、8組、未承認等の除外、直接ID lookup、0件/1件/最大3件、安定sort、重複ID、音声不存在/確認障害、旧#10 catalog互換、Firestore timestamp converterを検証する。
初回のfake timestamp検証に加え、実SDK Timestamp変換とquery構築spyを検証する。production Firestoreの実query/rules、聴感品質、Story Listとplayer接続は未検証/未実装として残す。local Rules emulator検証は第10節。

## 8. 初回の実行結果（2026-11-02、Firestore拡張前の履歴）

- `flutter analyze --no-pub`：**No issues found**。
- 上記3ファイルのfocused tests：**146 passed**（Issue #11の42件と、既存Issue #10の104件）。実Firestore/AIを呼ばないtests。
- `dart run tool/story_data_demo.dart happy`：exit 0。happy_dog_002、happy_dog_001、happy_dog_003の3件を順番どおり表示。
- `dart run tool/story_data_demo.dart anxious`：exit 0、0件、準備中の案内。ほかの感情を代用品として返さない。
- 試験用approval/audio flagとavailability callbackの模擬値による確認であり、人の本番承認・実MP3の存在や再生成功を示さない。
- 既存Issue #9/#10のDartコード、Prompt v3、template、assets、Firebase options、pubspecを変更していない。Firestore package追加・設定・rules/indexのdeploy、Git操作、Simulator、heavy buildは行っていない。

## 9. Firestore拡張時点の実行結果（2026-11-02の履歴）

- `cloud_firestore`は元のpubspecに存在しなかったため7.1.0を追加。firebase_core/Auth/AIの既存version制約は維持。
- 最終`flutter analyze --no-pub`：**No issues found**。
- focused suite：既存146件 + 新規Firestore関連19件 = **165 passed**。新規はfake source/query spy/実SDK Timestamp/manifest testであり、live Firebase readの成功を示さない。
- 実Firebase projectへcredentialを送らないread-only Firestore REST queryを実行した結果：**HTTP 403 / PERMISSION_DENIED**。
- backendの正確なmessage：`Cloud Firestore API has not been used in project yorisoi-emotion-test before or it is disabled.`
- このため実Firestore story read成功、databaseの存在、認証後のrules許可、index適合、production metadata/MP3の存在は未確認。API有効化・default database/rules/indexのowner確認が必要。APIを勝手に有効化していない。
- 失敗はmetadata読込前であり、mock成功や空結果をlive成功と呼ばない。Chrome SDK demoは用意したが今回手動実行・認証付きreadは未検証。
- UI/Auth/Issue #9/#10/Firebase optionsと既存firebase.jsonは変更せず、音声upload/生成・billing変更・Git操作・Simulator・heavy buildは行っていない。

再現用のfocused command（実Firebaseを呼ばない）：

```sh
flutter test --no-pub --concurrency=1 --reporter expanded \
  test/firestore_story_repository_test.dart test/story_data_test.dart \
  test/story_generation_service_test.dart test/firebase_story_model_test.dart
```

`flutter pub add`によりignored/generated plugin registrantsとlocal tooling cacheは更新される。Android/iOS build・Simulatorは実行していない。

## 10. Console公開前のRules review・local再現手順

`released()`は`storyLibraries/current`のpublicationStatus、language、schemaVersionを確認する。
documentが存在しない、field欠落、draft、不明schemaの場合はstory readを拒否する（欠落参照の評価errorもfail closed）。
library自体は認証済みuserにgetを許可するため、公開flag等の非機密metadataだけを置く。制作用本文・内部reviewer情報を混ぜない。
`published()`はisActive / humanApproved / approvalStatus / audioStatus / languageの5条件。
repository queryも5条件をすべて指定し、displayOrder、document ID順、limit=10で取得する。
emotion/petはrepositoryが絞り込むが、rulesはemotion別のアクセス権限を設けていない。公開済みlibraryは全認証user共通である。

注意：rulesはmetadata全体のvalidatorではない。humanApproved/ready flagを設定する管理者は、本文承認・mapping・revision・同梱音声の一致・durationを別途validateする。
アプリ側はStory modelとasset manifestでも再検証する。Admin SDKによるwriteはrulesを迂回する。
直接getで未公開/存在しないstoryを指定すると、nullではなくpermission-deniedになる場合がある。repositoryは安全なpermissionDeniedを返す設計。
limit=10は1queryの上限であり、連続queryのrate limitではない。

### Local rules tests（productionへ接続しない）

`tool/firestore_rules_test.cjs`は実Rules emulatorに現在のstory.rulesを読み込ませ、許可・拒否・repositoryと同じquery/cursorを検証する。
`firebase.story-rules-test.json`はlocalhost:8189、UI無効の専用config。project IDは必ずdemo-yorisoi-rulesを使う。
test scriptもlocalhostのFIRESTORE_EMULATOR_HOSTを必須とする。fixtureの書込はlocal emulatorだけで行う。
JS packagesは/tmpに置き、Flutter appへ追加しない。JDKはこのMacのAndroid Studio付属runtimeを利用できる。

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
npm install --prefix /tmp/yorisoi-firestore-rules-check --no-audit --no-fund @firebase/rules-unit-testing@6.0.0 firebase@13.1.0
env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
  JAVA_TOOL_OPTIONS='-Xmx256m -XX:ActiveProcessorCount=2' \
  NODE_PATH=/tmp/yorisoi-firestore-rules-check/node_modules \
  FIREBASE_EMULATORS_PATH=/tmp/yorisoi-firestore-rules-check/emulators \
  firebase emulators:exec --project demo-yorisoi-rules \
  --config firebase.story-rules-test.json --only firestore \
  'node --test tool/firestore_rules_test.cjs'
```

これはAndroid/iOS simulatorではない。初回はFirestore emulator JARのdownloadが必要。
emulatorはproductionの複合index存在を検証しないため、query許可成功とproduction index完成を混同しない。
Consoleへ公開する前に第6節の既存rules統合、API/default database、index、実承認データと同梱音声の準備を確認する。

### Reviewの実行結果（2026-11-02）

- 現在の`firestore/story.rules`をFirestore emulator v1.22.0へロードし、**Rules compile成功、26 tests passed、0 failed**（25 subtests + 親test）。mockによるrules評価ではない。
- 認証済みlibrary/story read、repositoryと同じHappy query、document ID cursor、正常0件を許可。
- 未認証read、draft/inactive/unapproved/音声未準備/field欠落、公開条件不足query、limit未指定/11、library list、全client write、private/unrelated pathを拒否。
- library不存在/draft/不明schema/必要field欠落でもstory get/queryを拒否。release gateがfail closedであることを確認。
- security/query不具合は見つからず、rules/repositoryの変更は不要。新規test script・専用local config・この説明のみ追加/更新。
- Java heap 256 MB・processor数2で実行し、テスト後emulatorは正常終了。Android/iOS simulator、production deploy、billing変更、Git操作なし。
- productionへ安全に公開する前提は、既存rulesとの統合review、API/default database、必要index、library gateの管理者登録。実production read成功はまだ主張しない。前節のAPI disabledエラーは今回再検証していない。
- Dartコードは変更していないためFlutter analysis/testは今回再実行しない。前回の165件は第9節の履歴であり、今回の26件と異なる検証。

## 11. 実SDK接続確認用デモの更新（2026-11-03）

利用者から、default database（asia-northeast2 / Spark）、rules・Enabled index、
`storyLibraries/current = {publicationStatus: draft, language: ja-JP, schemaVersion: yorisoi-story-data-v1}`の設定完了連絡を受けた。
これは利用者の設定報告であり、実readの成功記録ではない。公開flagの変更やstory書込は行わない。

`lib/story_firestore_demo.dart`だけを最小限更新：

- 既存`FirebaseAuthService.restoreSession()`で実Auth serverへreload・token refreshを要求する。メール・UID・password・tokenは表示/log出力しない。
- 実`FirebaseStorySource`のserver-only library read結果を観測し、publicationStatus / language / schemaVersionとstories query回数を表示する。
- `draft`ならrepositoryはstories queryを実行せず0件を返す。デモは「接続成功・draftのため非公開・正常0件」と明示する。JSON fallbackやmockを使わない。
- 既存ログイン画面を開くボタンを追加。ログイン成功でHomeへ進む既存動作は変更しない。Home表示後に同じURLをreloadすると接続デモへ戻る。
- Auth未確認・通信error・permission errorを接続成功扱いしない。repeat submitはbusyで防ぐ。

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter run --no-pub -d web-server --web-hostname localhost --web-port 8879 -t lib/story_firestore_demo.dart
```

同一browser profileで`http://localhost:8879`を開く。未ログインなら「既存のログイン画面を開く」から**本人が既存accountでログイン**する。
Home表示後にreloadし、「認証と実Firestore接続を確認」を押す。
成功の証拠はAuth server確認済み、Source.serverでcurrentを読込済み、実際の3 fields、stories query回数0とdraft説明が表示されること。
draftのままstoriesの公開query/index適合やMP3を検証したとは言わない。確認のためにapprovedへ変更する必要はない。

今回ここまでの確認：対象projectIdはlocal optionsの`yorisoi-emotion-test`と一致。WebのFirebase初期化・Auth初期状態取得・既存ログイン画面の表示を確認。
Codex内browserはログインsessionなしだったため、本人のログインを依頼。**認証済みFirestore read成功はまだ未確認**。
変更したdemoの`flutter analyze --no-pub lib/story_firestore_demo.dart`はNo issues found。以前のsetup・Rules emulator tests・全Flutter testsは繰り返していない。

### CLI-only verification update — 2026-11-03

Following the requested workflow, no further Computer Use or browser automation is used.
The developer demo now emits a credential-free `STORY_FIRESTORE_CHECK` diagnostic after a manual check.
A successful draft check reports `authServerVerified: true`, `librarySource: server`,
`publicationStatus: draft`, `language: ja-JP`, `schemaVersion: yorisoi-story-data-v1`,
`storyQueries: 0`, `storyCount: 0`, and `outcome: draft_expected_empty`.
This describes the **expected output**, not an observed live-success result.
No password, token, email, UID, story body, or raw backend error is logged.
The diagnostic is sent through Flutter `debugPrint`; depending on the web-server debug connection,
it may be visible in the browser console rather than the Flutter terminal. The same result is shown on the page.

The local demo server is restarted at `http://localhost:8879`; targeted analysis of the changed
`lib/story_firestore_demo.dart` reports **No issues found**. Production settings, stories, rules,
indexes, billing, Auth implementation and Git are unchanged. Previous automated suites are not rerun.

**Manual action still needed:** refresh that URL in the browser/profile containing your existing login.
Press `認証と実Firestore接続を確認`. If login is required, use `既存のログイン画面を開く`, sign in yourself,
then reload the same URL and repeat the check. Share only the status panel or safe diagnostic line.
Local CLI tools do not automatically inherit a browser's Firebase Auth session; no stored browser
credentials or tokens are extracted to work around this boundary.

Until that output is observed or provided, authenticated Auth refresh and the real server document
read remain **unverified**. The prior API-disabled error is historical, not assumed to persist after
the reported Console setup. Even a successful draft check will not verify published story queries,
production index use, audio availability or playback. Keep the library in draft.

### Demo authentication-state correction — 2026-11-03

The user reported successful login followed by an apparently disabled verification button after refresh.
Code review found that the demo always offered a login form even for an existing session, and checked
`currentUser` before calling the service's restoration procedure. Neither observation proves a browser
persistence failure. The production service already requests `Persistence.LOCAL` before login and restoration.

The developer demo now subscribes to Auth state, shows whether a session is present/unknown/absent,
and prevents reopening login for a session that is already present. Verification remains available while
Auth state is unknown and calls restoration before deciding that login is necessary. A separate status label
distinguishes an idle verification button from an active check. Auth timeout/error paths release the busy state;
duplicate checks are blocked and the subscription is disposed with the screen.

Only the developer demo, `test/story_firestore_demo_test.dart`, and this note are changed for this correction.
The original Login UI, Auth service, Firebase settings and repository remain unchanged.
Focused fake-backed tests verify restored/unknown/changing Auth states, repeated taps, timeout/retry,
network error recovery and disposal. They do not prove live browser persistence or a production Firestore read.

Manual verification: use exactly `http://localhost:8879` in the same browser profile. Reload after login.
The demo should show a saved session and no need to log in again. Press the verification button and inspect
the actual Auth/Firestore result panel. With `draft`, the expected successful result is `draft_expected_empty`,
`storyQueries: 0` and `storyCount: 0`. If it still reports `login_required` after a same-origin reload,
share that status and the browser/profile being used; cross-refresh persistence remains unresolved until
observed. Do not clear site data, change Firebase settings, or publish the library as a workaround.

### Metadata errorの追跡（2026-11-03）

利用者が実デモで`公開catalogのmetadataが未登録、または不正です。`を確認したと報告した。
この表示は`StoryDataError.invalidCatalog`から生成され、Firestore repositoryの`_released()`に発生源がある。
現コードの経路ではAuth server確認がtrueとなり、`Source.server`のlibrary readが例外なしで完了した**後**のvalidation errorである。
これは利用者の実行結果とcode pathからの判断で、開発者が新たにproduction readを観測したという意味ではない。
readの完了だけではdocumentの存在を保証しない。存在しないdocumentはnull、空documentは空mapとして区別する必要がある。

報告された3 fields（draft / ja-JP / yorisoi-story-data-v1）をそのまま使ったfocused testは成功し、story queryなしで0件となった。
draftをinvalidと扱うbugは再現しない。実readのpayloadが未取得のため、どのfieldが異なるか・documentが存在しないかはまだ特定しない。

診断のみを追加：`StoryCatalogException.issue`はmissingDocument / schemaVersionMismatch / languageMismatch /
publicationStatusMismatchを区別する。strictな値のvalidationと公開条件は変更しない。
デモのmetadata error表示にはAuth確認の成否、server read完了、実instanceのprojectId/databaseId、document path、
存在判定、known fieldごとのmissing/wrong_type/unexpected_value/valid、trim後一致の有無を含める。
未知の生値・任意field・token・個人情報は出力しない。新しい診断の実値はまだ観測していない。

今回のfocused tests：**32 passed**（Firestore repository 26件、demo 6件、うち今回追加7件）。
変更3 Dart filesのtargeted analysis：**No issues found**。testsはfake source/stateを使い、live Firebase成功の証拠にしない。
Firestore settings/rules/index/publicationStatus、Auth/Figma UI、Gitは変更しない。browser操作や過去の手動確認手順の繰返し依頼も行わない。

## 12. 最終review・PR用の検証結果（2026-11-03）

### 実Firebase接続：利用者によるChrome確認

利用者が次の実行結果を報告した。mockではなく既存Flutter Web demoの実SDKによる確認である。
開発者がbrowserを操作して独立に再実行した結果ではない。

- Firebase Auth：server verified。
- Firestore：`Source.server` read成功、`storyLibraries/current`。
- publicationStatus：`draft`、language：`ja-JP`、schemaVersion：`yorisoi-story-data-v1`。
- stories query回数：0。draft libraryの正常な非公開動作を確認。

以前のAPI disabled / invalidCatalog / 接続未確認の記述は作業履歴として残す。
以前のmetadata不一致の具体原因が判明したとは主張しない。現在のdraft読込は利用者確認済み。
**この確認は公開story取得やproduction複合query/indexの実利用を証明しない。**

### 今回新たに実行した自動検証

- project全体の`flutter analyze --no-pub`：**No issues found**。
- 下記focused Flutter tests：**178 passed、0 failed**。Issue #11の74件と既存Issue #10の104件。live Firebase/AIを呼ばない。
- local Firestore Rules emulator：compile成功、**26 passed、0 failed**。25 subtests + 親test。テスト終了後に正常shutdown。
- local fixture Happy demo：exit 0、happy_dog_002 / happy_dog_001 / happy_dog_003を表示順に取得。模擬approval/audioであり、実MP3はない。

```sh
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --timeout 30s --reporter expanded \
  test/story_data_test.dart test/firestore_story_repository_test.dart \
  test/story_firestore_demo_test.dart test/story_generation_service_test.dart \
  test/firebase_story_model_test.dart
```

### Requirements・security・scopeのreview

- 日本語仕様、metadata、JSON/Timestamp変換、8感情と承認済みpet対応、事前制作2〜3話/感情の方針を維持。
- read-only Firestore repository、main emotion抽出、公開/承認/audio gate、安定sort・最大3件、bounded paging、不正recordの除外・safe errorを実装。
- JSON repositoryと明示opt-inのnetwork-only fallbackを維持。permission/不正metadata/正常0件/draftをfallbackで隠さない。
- rulesは認証・library公開・story公開条件とquery上限を要求し、client writesと非公開制作collectionを拒否。管理者の正しい承認判断・metadata検証は別途必要。
- API key/private key/token形式のtargeted scanを下記19 filesに実施し、該当なし。任意の他ファイルまで秘密情報なしと保証するscanではない。
- Issue #11直前の既存84 filesのhashと比較：82 filesが同一、差分はcloud_firestore追加に伴うpubspec.yaml/pubspec.lockのみ。Auth/Figma/Home/Issue #9/#10の既存source・local Firebase optionsはこのbaselineと同一。
- criticalな実装不具合やscope外のruntime変更は今回のreviewでは見つからず、新たなapp修正は行わない。今回更新したrepository fileはこの仕様書のみ。
- Git操作を行わないためbranch/staging/untracked/PR差分は未検査。下記は用途ベースの**review対象manifest**であり、Git差分一覧ではない。

### Issue #11 review対象manifest（19 files）

```text
docs/story_data_management_spec.md
firebase.story-data.json
firebase.story-rules-test.json
firestore/story.rules
firestore/story.indexes.json
lib/domain/stories/story.dart
lib/repositories/story_repository.dart
lib/repositories/json_story_repository.dart
lib/repositories/firestore_story_repository.dart
lib/repositories/fallback_story_repository.dart
lib/story_firestore_demo.dart
pubspec.yaml
pubspec.lock
test/story_data_test.dart
test/firestore_story_repository_test.dart
test/story_firestore_demo_test.dart
test/fixtures/story_library_demo.json
tool/story_data_demo.dart
tool/firestore_rules_test.cjs
```

local Firebase options、google-services.json、GoogleService-Info.plist、秘密情報、.dart_tool/build/cache/log、generated plugin registrants、無関係なAuth/Figma/native変更はIssue #11へ混ぜない。
SDK package追加に伴いgenerated registrantsは自動更新され得るが、既存ignore設定の対象である。

### 残る作業・制限

- 公開済み・人の承認済み・実音声同梱済みstoryのproduction取得、実query/index適合、直接ID取得を含む公開経路の実機能検証は今後必要。
- 今回root appのassets内にMP3は0件。16〜24話のproduction content制作、音声review/同梱とpubspec登録、聴取確認は未実施。fixtureで代用して完成としない。
- unversioned asset pathを使う場合はmetadata revisionとapp同梱音声のrelease整合が必要。manifest存在確認は音声品質やrevision一致を証明しない。
- offline catalogはrelease時snapshotで、offline中の撤回を即時反映できない。撤回即時性が必要ならfallbackを使用しない。
- 登録・承認・更新は信頼できる管理者の手順。管理UI/アップロード機能は実装しない。
- Story List / Podcast Player / TTS / Firebase Storage / 利用者session中の生成は対象外。iOS/Android端末上のFirestore動作は未検証。
- 上記制限を明記してIssue #11のspec/data layerをPR reviewへ提出できる。libraryをapprovedへ切り替える必要はない。GitHub/SourceTree側の対象files確認・commit/PR作成は利用者が行う。
