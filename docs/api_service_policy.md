# Yorisoi API・AI・クラウドサービス採用方針

## 1. 目的

本ドキュメントは、YorisoiのMVP開発で使用するAPI・AI・クラウドサービスの採用方針を定義する。

各サービスについて、以下の項目を調査・比較し、開発者が技術選定を判断できるようにする。

- サービスの用途と採用理由
- iOS・Android・Flutterへの対応状況
- 無料枠と有料プランの料金体系
- APIキーの管理方法とセキュリティ
- 技術的な制約と注意点
- 代替サービス
- 動作検証の結果と未検証項目

## 2. Yorisoiのアプリ概要

Yorisoiは、ユーザーの現在の感情をAIで分析し、その感情に対応する動物キャラクターの音声ストーリーを提供するメンタルウェルネスアプリである。

### 2.1 基本フロー

1. ユーザー登録・ログイン
2. テキストまたは音声で現在の気持ちを入力
3. 音声入力の場合はSpeech-to-Textでテキストに変換
4. AIで感情を分析し、8種類の感情に分類
5. 分析結果に対応する動物キャラクターを決定
6. 対応する音声ストーリーをFlutter assetsから取得（Storageは課金未承認のため保留）
7. Flutterアプリのラジオ・ポッドキャスト形式の画面で音声を再生

### 2.2 感情と動物キャラクターの対応

| 動物              | 対応する感情                          |
| ----------------- | ------------------------------------- |
| Cat（猫）         | Sad（悲しい）、Lonely（寂しい）       |
| Rabbit（うさぎ）  | Anxious（不安）、Stressed（ストレス） |
| Dog（犬）         | Angry（怒り）、Happy（嬉しい）        |
| Dolphin（イルカ） | Calm（安心）、Other（その他）         |

### 2.3 MVPの重要な前提

- リアルタイムのライブ配信は実装しない。
- 動物キャラクターとのリアルタイムAIチャットはMVPの対象外とする。
- 音声ストーリーは事前に生成・準備する。
- ストーリーテキストはText-to-SpeechでMP3形式に変換する。
- 初期MVPのMP3ファイルはFlutter assetsに同梱する。Firebase StorageはBlaze移行が必要なため保留する。
- アプリ利用時に毎回ストーリーをAIで生成する方式は採用しない。
- ユーザー入力の感情分析にはAIを使用する。
- 動物キャラクターの簡単な口の開閉アニメーションは実装可能な表現として検討する。

## 3. 感情分析AIの採用方針

### 3.1 目的

Yorisoiでは、ユーザーのテキストまたは音声認識結果をAIで分析し、8種類の感情のいずれかに分類する。

| 感情コード | 日本語   | 対応する動物 |
| ---------- | -------- | ------------ |
| sad        | 悲しい   | Cat          |
| lonely     | 寂しい   | Cat          |
| anxious    | 不安     | Rabbit       |
| stressed   | ストレス | Rabbit       |
| angry      | 怒り     | Dog          |
| happy      | 嬉しい   | Dog          |
| calm       | 安心     | Dolphin      |
| other      | その他   | Dolphin      |

AIは感情分類に使用する。ストーリーの生成と音声ファイルの作成は事前に行い、ユーザーの利用時には生成しない。

### 3.2 第一候補

サービス：Firebase AI Logic + Gemini Developer API

採用理由：

- Flutter、iOS、Android向けのSDKが提供されている。
- `firebase_ai`を利用できる。
- 対象モデルのFree Tierを利用できる。
- Firebase Sparkプランでは支払い方法なしで開始できる。
- Firebase App Checkと連携できる。

開発予算は0円とし、Cloud Billingを有効化しない。

### 3.3 モデルと料金

調査日：2026年10月10日

候補モデル：

- Gemini 3.5 Flash-Lite：低コストな感情分類の候補
- Gemini 3.8 Flash：分類精度の比較候補

両モデルについて、Gemini Developer APIの無料枠を第一に検討する。

無料枠にはモデルごとの利用制限がある。具体的な上限と利用可能モデルは実際のプロジェクトで確認する。

有料プランは現時点で契約しない。将来の運用開始時に最新の料金表を確認する。

### 3.4 Flutter実装方針

使用予定パッケージ：

- firebase_core
- firebase_ai
- firebase_app_check

処理フロー：

1. ユーザーの入力テキストを取得する。
2. Geminiに感情分類を依頼する。
3. 8種類の感情コードのうち1つを返す。
4. アプリ側で出力値を検証する。
5. 感情に対応する動物を決定する。
6. 事前作成した音声ストーリーを再生する。

無効な応答や通信エラーが発生した場合は、再試行または安全なフォールバック処理を実行する。

### 3.5 無料の代替案

- Mock：固定の感情コードを返す。
- Local keyword matching：簡易的なキーワード分類を行う。
- Test UI：開発時のみ感情を手動選択できるようにする。

これらは開発用の代替手段であり、AI分析と同じ精度は保証しない。

### 3.6 セキュリティとプライバシー

- 秘密のAPIキーをFlutterコードに埋め込まない。
- Firebase App Checkを使用する。
- 2026年11月2日からFirebase AI LogicでApp Check適用が必須となる。
- 開発用端末では適切なDebug Providerを使用する。
- 感情入力の原文や個人情報を不要に保存しない。
- Gemini Free Tierでは入力・出力がサービス改善に利用される場合がある。
- 初期テストには架空の文章のみ使用する。
- 本番公開前にデータの取り扱いとプライバシーを再評価する。
- 本アプリを医療診断サービスとして扱わない。

### 3.7 検証状況

Issue #3で確認済み：

- firebase_aiとfirebase_app_checkの依存関係解決
- 一時的なFlutterプロジェクトのAndroid / iOSビルド

Issue #4で追加確認済み（2026年10月13日）：

- Firebase接続とGeminiリクエスト：REST、Dart SDK、Android EmulatorおよびiOS Simulatorの実アプリで`lonely`を確認。

引き続き未検証：

- 日本語の8感情分類の精度
- エラー・タイムアウト処理
- App Checkの実動作
- 無料枠の利用制限

2026年10月10日は設定エラーで失敗したが、10月13日のbackend修復後に成功。過去結果と修復内容は後述。

### 3.8 公式参考資料

- https://firebase.google.com/docs/ai-logic
- https://firebase.google.com/docs/ai-logic/pricing
- https://firebase.google.com/docs/ai-logic/models
- https://firebase.google.com/docs/ai-logic/app-check
- https://ai.google.dev/gemini-api/docs/pricing

## 4. 感情分析APIの動作検証結果

検証日：2026年10月10日

### 4.1 検証環境

- Firebaseプロジェクト：yorisoi-emotion-test（個人の検証用）
- 料金プラン：Spark（Cloud Billing未設定）
- Flutterの一時テストプロジェクトを使用
- Android Emulator：Android 17（API 37）
- 使用SDK：firebase_core、firebase_ai
- 入力例：「今日は友達と会えなくて、とても寂しいです。」
- 期待する感情分類：lonely

### 4.2 検証結果（2026年10月10日の履歴・10月13日に解消）

- Flutter analyze：成功
- Flutter widget test：成功
- Android Emulatorでのアプリ起動：成功
- Firebase初期化：成功
- Gemini APIへのリクエスト：失敗
- エラー：Firebase AI Logic genai config not found
- 感情分類の正確性：未検証

### 4.3 確認済み事項

- FirebaseのAndroid/iOSアプリ登録済み
- Firebase AI Logic API：有効
- Gemini Developer API：有効
- Firebase AI Logic Service Agent：存在を確認
- App Check：Unenforced（検証時点）

### 4.4 今後の対応

2026年10月13日は同じREST経路で設定エラーを再現した後、欠落していたprovider configを修復。REST、Dart SDK、Android実アプリ、iOS Simulatorで`lonely`を確認した。詳細は末尾の再検証結果を参照。
今後は8種類の感情分類の精度を検証する。
本検証のみではAIサービスの採用可否を確定しない。

## 5. 音声入力（Speech-to-Text）の採用方針

### 5.1 採用候補

- Flutterパッケージ：`speech_to_text`
- Android・iOSのOS標準音声認識機能を利用する。
- 日本語の短い発話をテキスト化し、感情分析へ渡す。
- 常時録音やリアルタイム配信は行わない。

### 5.2 導入条件・注意点

- Android：`RECORD_AUDIO`など必要な権限・設定を追加する。
- iOS：`NSMicrophoneUsageDescription`、`NSSpeechRecognitionUsageDescription`を設定する。
- 日本語ロケールの対応、端末ごとの認識精度、ネットワーク依存を確認する。
- 音声認識が使えない場合はテキスト入力へ切り替える。

### 5.3 代替候補

- Google Cloud Speech-to-Text：クラウド型。料金と認証方式の確認が必要。
- Whisper系API：クラウド型の場合は送信する音声データの保護・料金を確認する。
- MVPでは追加の有料API契約を避け、`speech_to_text`を第一候補とする。

### 5.4 検証状況

- パッケージ導入およびFlutterプロジェクトのビルド確認：実施済み。
- 過去の試験：Android emulatorで`error_speech_timeout`、Chromeで`Japanese language unavailable`。
- 2026年10月13日：Webのロケール判定を修正し、回帰テストに合格。macOSのGoogle Chrome / Flutter Webで実発話認識をユーザーが確認（発話内容と一致してPASS）。
- Status：`done`。発話「とても寂しいです。」→実認識「とても寂しいです」。
- iOS Simulator（iPhone 18 Pro / iOS 27.0）：ユーザー確認でPASS。`Status: done`、認識「今日はとても寂しいです」。
- Androidの日本語音声認識は、まだ成功確認できていない。iOS実機も未検証。

## 6. TTS（音声生成）の採用方針

### 6.1 採用方式

- Yorisoiはライブ音声配信やリアルタイムTTSアプリではない。
- 感情×ペットごとにストーリーを事前に準備する。
- ストーリーのテキストを事前に音声化し、MP3を保存して再生する。
- 初期の感情カテゴリは8種類、ペットは4種類とする。

### 6.2 サービス比較

| 候補                                 | 用途                       | 費用・注意点                          |
| ------------------------------------ | -------------------------- | ------------------------------------- |
| Google Cloud Text-to-Speech          | 事前MP3生成                | 利用条件、課金設定、無料枠を事前確認  |
| 利用許諾のある録音・ローカル音声生成 | 事前MP3生成                | ツール・音声素材の商用利用条件を確認  |
| 実行時クラウドTTS                    | ユーザー操作ごとの音声生成 | コストと遅延が増えるためMVPでは不採用 |

### 6.3 安全性・検証状況

- 公開・商用利用が許可された音声のみ採用する。
- 他者の声の無断複製を行わない。
- MP3生成サービスによる実際の生成品質・料金：未検証。
- MVPでは事前生成済みMP3を利用し、実行時のTTS APIキーをアプリに埋め込まない。

## 7. 音声再生・音声ファイル保存

### 7.1 音声再生

- Flutterパッケージ：`just_audio`を第一候補とする。
- ストーリーはPodcast風画面で再生する。ライブ配信ではない。
- 再生開始・停止・終了・ロード失敗時の表示を実装する。
- 2026年10月13日：当初の録音MP3をFlutter assetsに同梱し、ChromeでPlaying→Completed、iOS Simulatorで音声聴取を確認（PASS）。後に録音をoriginal toneへ置換し、新toneもin-app browserのFlutter WebでCompleted確認（再生lifecycle PASS）。新toneの聴感品質・iOS/Android再生は未検証。

### 7.2 保存先の選定

| 保存方法                        | メリット                             | 判断                                  |
| ------------------------------- | ------------------------------------ | ------------------------------------- |
| Flutter assetsにMP3を同梱       | オフライン利用可、クラウド保存費なし | ¥0のMVPで暫定採用                     |
| Firebase Cloud Storage          | MP3の差し替え・追加が容易            | Blazeプランが必要なため現時点では保留 |
| 外部CDN・オブジェクトストレージ | 大量配信に対応しやすい               | 料金、アクセス制御、運用負担を要調査  |

- Firebase Storageの無料利用量があっても、現在はBlazeプランへの移行が必要。
- 個人の検証用FirebaseプロジェクトでBillingを有効にしない。

### 7.3 命名規則案

- `assets/audio/{emotion}_{pet}.mp3`
- 例：`assets/audio/lonely_cat.mp3`
- 感情コードは `sad / lonely / anxious / stressed / angry / happy / calm / other` とする。
- 感情→ペット対応は `sad, lonely=cat`、`anxious, stressed=rabbit`、
  `angry, happy=dog`、`calm, other=dolphin` とする。
- 存在しないファイルは安全なデフォルト音声またはエラー表示に切り替える。

## 8. Firebaseとセキュリティ方針

### 8.1 クラウドサービス

| サービス                | 使用目的                       | 方針                                   |
| ----------------------- | ------------------------------ | -------------------------------------- |
| Firebase Authentication | ログイン・新規登録             | 候補。認証フローは未検証               |
| Cloud Firestore         | 最小限のユーザー設定・利用情報 | 候補。読み書きとSecurity Rulesは未検証 |
| Firebase AI Logic       | テキストから8感情へ分類        | 採用候補。provider設定修復後、REST/SDK/Android/iOS Simulatorでlonely確認     |
| Firebase Cloud Storage  | MP3の保管・取得                | Blaze必須のため¥0環境では採用保留      |
| Flutter assets          | 固定MP3の配布                  | 初期MVPで暫定採用                      |

### 8.2 セキュリティ・プライバシー

- ユーザーの感情入力は機微性が高いため、必要最小限のみ処理する。
- 入力音声や感情テキストの恒久保存は、要件・同意なしでは行わない。
- FirestoreとStorageを利用する場合、認証・Security Rules・アクセス権限を必ず検証する。
- APIシークレット、サービスアカウント秘密鍵、個人の認証情報をGitHubへ登録しない。
- Firebaseのクライアント設定値と、秘密のサーバー認証情報を区別する。
- Firebase App Checkの適用方針は正式導入前に見直す。
- 会社の正式Firebaseプロジェクトと個人の検証用プロジェクトは分離する。

## 9. 検証状況・採用判断のまとめ

| 検証項目                                | 2026年10月13日時点の結果                     |
| --------------------------------------- | -------------------------------------------- |
| Flutterパッケージ導入・静的解析         | 成功                                         |
| Androidテストアプリの起動               | 成功                                         |
| iOS Simulator向けビルド                 | 成功（過去の検証）                           |
| Firebase AI Logicの感情分類             | backend修復後REST/実Dart SDK/Android/iOS Simulatorでlonely確認 |
| 日本語Speech-to-Text                    | Chrome/macOS実発話PASS（発話内容と一致）、iOS Simulator PASS。Android成功未確認                                       |
| 事前MP3生成                             | 未検証                                       |
| `just_audio`による実MP3再生             | 新toneはFlutter Web Completed確認。旧録音はChrome/iOS Simulator PASS。新toneのnative再生とAndroid成功は未確認                                       |
| Cloud Firestore・Authenticationの実動作 | 未検証                                       |
| Firebase Storageへの保存                | 未検証。Sparkでは利用できない                |

### 9.1 次の対応

1. 成功済みのGeminiテストを基準に、8感情全体の分類精度とApp Check運用を検証する。
2. `speech_to_text`のAndroidとiOS実機での実発話認識、および追加発話による認識精度を検証する。
3. WebとiOS Simulatorで再生確認済みのMP3について、Android・iOS実機の再生と各環境の聴感品質を検証する。
4. 正式開発環境の料金・権限・セキュリティ要件を担当者と確認する。
5. 未検証の項目は成功扱いにせず、実装Issueで追跡する。

### 9.2 参考資料

- https://firebase.google.com/docs/ai-logic
- https://firebase.google.com/docs/ai-logic/error-codes
- https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024
- https://pub.dev/packages/speech_to_text
- https://pub.dev/packages/just_audio
- https://firebase.google.com/docs/firestore/security/get-started

## Gemini API 動作確認結果（2026年10月12日）

### テスト環境

- OS：macOS
- API：Google Gemini API（REST API）
- 使用モデル：gemini-3.8-flash
- テスト方法：curlによるAPIリクエスト

### 感情分析テスト

- 入力文：最近、一人で寂しいです。
- 期待結果：Lonely（寂しい）
- 実際の結果：Lonely
- HTTPステータス：200
- 判定：成功（PASS）

### 補足

gemini-2.5-flashは新規ユーザー向けに利用できず、
HTTP 404エラーが返されたため、
gemini-3.8-flashに変更して動作確認を行った。

今回のテストでは、日本語テキストから
8種類の感情カテゴリのうち1つを返すことを確認した。

※ この10月12日の記録単独ではFlutter/Firebase連携を検証していない。
10月13日のREST、Dart SDK、Android実アプリ成功は後述。


## Issue #4 技術再検証（2026年10月13日）

対象ブランチ：`feature/api-service-policy`。作業対象はIssue #4のみ。
一時プロジェクト `/tmp/yorisoi_package_check` を修正し、その後独立した再現用packageを
[`tools/issue4_package_check`](../tools/issue4_package_check/README.md) に整備した。fresh runner作成scriptにより作者のtemporary projectへの依存は不要。
Firebase設定・APIキー・認証情報は保存していない。Push、Merge、Billing変更は実施していない。

### Gemini：モデル名ではなくprovider設定段階で失敗（修復前の履歴）

- [公式モデル一覧](https://firebase.google.com/docs/ai-logic/models)で
  `gemini-3.5-flash-lite` がFirebase AI Logic / Gemini Developer API対応、
  billing不要のモデルであることを確認。モデル名は変更していない。
- `firebase_ai 4.0.0` のGoogle AI URI生成実装を確認し、同じREST経路
  `POST /v1beta/projects/yorisoi-emotion-test/models/gemini-3.5-flash-lite:generateContent`
  に既存Firebaseクライアント設定をメモリ内で読み込んでリクエストした。
- 入力：`今日は友達と会えなくて、とても寂しいです。`、期待：`lonely`。
- 実測：HTTP **400**、`Firebase AI Logic genai config not found`。
  感情応答は得られず、期待値`lonely`の成功確認はできていない。
- [公式エラー説明](https://firebase.google.com/docs/ai-logic/error-codes#error-genai-config-not-found)
  はこのメッセージを通常404として説明し、Gemini provider設定の未完了・欠落、
  または設定直後のbackend伝播遅延を原因候補としている。本試験のHTTP statusは400だった。
  API有効化、IAM、service agentの存在だけではprovider設定完了の証明にならない。
- 診断範囲：Flutter UIを経由せずbackend設定エラーを再現した。
  Consoleのprovider登録状態を直接確認できていないため、未設定・破損・伝播問題の
  どれかまでは断定しない。モデル名、prompt変更で解決したとは報告しない。
- 必要なbackend対応：Firebase Consoleの対象projectでAI Services → AI Logic →
  Gemini Developer APIのsetup完了状態を確認し、不足があれば完了する。
  完了済みで時間経過後も再現する場合は、秘匿情報を除いた結果でFirebase Supportへ問い合わせる。
  このセッションではChrome操作のアクセスが得られず、Console設定修復は実施できなかった。
- 実装修正：30秒timeout、8感情コードのallowlist検証を追加。
  空・不正応答を成功や`other`として扱わず例外にする。通信timeoutはリクエストの
  待ち時間上限であり、サーバー処理のキャンセルを保証しない。
- 過去の2026年10月12日REST成功記録は今回のFlutter/Firebase経路の成功を意味しない。

### Japanese Speech-to-Text：Webの誤判定を修正

- `speech_to_text 7.5.0` のWeb実装 `locales()` はrecognitionオブジェクトの
  現在の`lang`だけを返す。空または英語のみでも、日本語非対応とは判定できない。
- 修正：Webでは`ja-JP`を直接指定。nativeでは実際に列挙された日本語localeを選択。
  underscore / hyphenの両表記に対応し、日本語がなければ停止する。
  dispose時のcancelと認識中の開始ボタン無効化も追加。
- 回帰テスト：Webの空/英語locale、nativeの`ja_JP` / `ja-JP`、日本語なしを確認。
  **実音声認識の成功テストではない**。
- Androidの`error_speech_timeout`は過去結果のまま。今回emulatorの再試験はしていない。
  `listenFor`はOSの無音timeoutを延長する保証ではない。
- 実用的な再試験：`flutter run -d chrome -t lib/voice_test.dart`、開始ボタンから
  マイクを許可して日本語を発話する。browser/OSの認識サービスへの依存は残る。
  認識できない場合はテキスト入力を採用。有料STTには切り替えない。
- Gemini用`firebase_options.dart`にはWeb設定がない。voice/audioのentrypointは
  Firebaseを初期化しないため、この制限を避けて単独試験できる。

### Local MP3：当初の録音fixtureによる再生確認（履歴）

- `just_audio 0.10.6`、`assets/audio/test.mp3`をpubspecへ登録。
- 当初の試験はfirebase-ios-sdkの約1.836秒の録音fixtureを使用した。
  repository-level Apache-2.0宣言は確認したが、録音固有の権利根拠が十分でないため
  PR用packageからこの録音を除外し、original generated toneへ置き換えた（後述）。
- `audio_test.dart`で`setAsset()`、Play / Stop、完了・失敗表示、disposeを実装。
- 実Flutter Webアプリをlocalhostで起動し、Playクリック後の`Playing`と
  `Completed`をUIで確認した。成功はasset再生ライフサイクルの範囲。
  このWeb試験では聴感品質を確認していない。後続のiOS Simulator試験では音声聴取をユーザーが確認（PASS）。Android再生とiOS実機は未検証。
- 別の`flutter test --platform chrome` harnessはrootBundle読み込みで10秒timeout。
  最初の試行も30秒timeout。これは未解決のtest harness制約として記録し、
  pass扱いにしない。実アプリの再生結果とは分離する。
- Flutter assetsをMVPで採用継続。Firebase Storageへの保存・Billing有効化は行わない。

### 実行結果（最新確認を反映）

| 実行内容 | 結果 |
| --- | --- |
| temporary project `flutter analyze`（最終修正後） | 成功、No issues found |
| widget表示、感情allowlist、Web/native locale回帰テスト | 4 tests passed |
| Gemini同経路RESTリクエスト | 修復前HTTP 400、修復後HTTP 200 / lonely |
| Gemini Dart SDK / Android Emulator / iOS Simulator実アプリ | すべてlonely確認（Android/iOSはユーザー確認） |
| `flutter build web -t lib/audio_test.dart` | 成功 |
| `flutter build web -t lib/voice_test.dart --output build/voice_web` | 成功 |
| local MP3実Flutter Web UI | Playing → Completed確認 |
| local MP3 iOS Simulator | Play MP3を押し音声聴取、PASS（ユーザー確認）。Android未検証 |
| headless browser MP3 harness | 失敗、asset load timeout |
| 実発話の日本語文字起こし | Chrome/macOSでPASS、done / とても寂しいです（発話内容と一致）。iOS SimulatorでPASS、done / 今日はとても寂しいです。Android成功未確認 |

修復前のサービス判断：Geminiはbackend修復と実分類確認まで採用候補のまま。
現在のSTTはChrome/macOSとiOS SimulatorでPASS、Android成功未確認。MP3はassets + just_audioでWebの再生動作とiOS Simulatorの音声聴取を確認。Android MP3は未検証。Issue #4全体を技術完了とはしない。


### Gemini backend修復と再試験（同日・上記エラー調査の続き）

**特定した原因：AI Logicのgeneral configは存在したが、Gemini Developer API用の
`generativeLanguageConfig` submessageが欠落していた。**

認証済みFirebase CLIのread-only APIで
`projects/yorisoi-emotion-test/locations/global/config`を取得したところ、
修復前は`name`のみだった。CLIのprovider表示はGemini Developer API=trueだったが、
実装を確認するとこれはAPI有効化状態から算出されるため、Gemini固有configの
存在確認にはならない。未設定/破損の発生経緯は特定していない。

[公式API discovery](https://firebasevertexai.googleapis.com/$discovery/rest?version=v1beta)
の`Config` / `GenerativeLanguageConfig` schemaを確認。
Gemini API key fieldはdeprecatedで、現在はkey material不要と記載されている。
Firebase CLI同梱API clientを使用し、既存loginをメモリ内で利用して次を実行した：

```text
PATCH /v1beta/projects/yorisoi-emotion-test/locations/global/config
updateMask=generativeLanguageConfig
body: {"generativeLanguageConfig": {}}
```

変更範囲は欠落していたprovider submessageのみ。API key、IAM、App Check、
traffic filter、telemetry、Billingの設定変更はしていない。
PATCH後のGETで`name`と`generativeLanguageConfig`の存在を確認した。
修復後のCloud Billing read-only照会でも`billingEnabled=false`を確認した。

| 再試験 | 実測結果 |
| --- | --- |
| 修復前・Firebase AI Logic REST | HTTP 400 / genai config not found |
| 修復後・同じREST probe | HTTP 200、emotion=`lonely` |
| 修復後・既存`testYorisoiEmotion()`を実`firebase_ai 4.0.0`から実行 | 1 live test passed、emotion=`lonely` |
| 修復後・Android Emulatorの実Flutterアプリ（ユーザー確認） | Test Emotionを押し、画面の`lonely`を確認、PASS |
| 修復後・iOS Simulatorの実Flutterアプリ（ユーザー確認） | iPhone 18 Pro / iOS 27.0、`lonely`を確認、PASS |

REST・Dart SDK・Android実アプリの入力はいずれも`今日は友達と会えなくて、とても寂しいです。`。
モデル名`gemini-3.5-flash-lite`と`FirebaseAI.googleAI()`は変更していない。
同一経路で修復前後の差を確認できたため、今回の設定エラーは解消と判断する。

Live SDK testはtemporary projectの`tool/gemini_sdk_live_test.dart`に置き、
`flutter test --dart-define=RUN_LIVE_GEMINI=true tool/gemini_sdk_live_test.dart`
で実行。native Firebase Core bootstrapのみtest hostに置き換え、実際のFirebase
client optionsを渡している。HTTP通信・Gemini応答・感情分類関数はmockしていない。
これはAndroid/iOS/Web UI全体のend-to-end試験ではなく、native platform headers、
App Check attestation/enforcement、本番認証設定を検証するものではない。

Git方針：当初のIssue #4 test overlay 11 filesはuntracked状態で別置きにしていた。
その後、PR blocker修正の承認に基づき独立packageへ拡張（最新構成は末尾参照）。
当初のlive testとbackend診断/修復scriptsはtemporary directoryのみに置いた。
live SDK testは後にruntime config方式で再現用packageへ追加した。backend修復scriptは同梱しない。
Issue #2/#3 files、branch、commit historyは変更せず、commit/push/mergeも実施していない。
GeminiはAndroid実アプリとiOS Simulatorで成功し、STTとMP3はChrome/macOSおよびiOS SimulatorでPASS。
8感情全体の精度、App Check運用、AndroidのSTT/MP3、iOS実機、追加発話による精度は
別途検証が必要なためIssue #4全体を完了扱いにはしない。


### Android実アプリでのGemini感情分析確認（2026年10月13日）

ユーザーがAndroid Emulator上で実Flutterテストアプリを起動し、
`Test Emotion`を押して結果が`lonely`であることを確認したと報告。
対象入力は`今日は友達と会えなくて、とても寂しいです。`。
この結果はユーザーによる実アプリ操作の確認であり、agentによる再実行ではない。
以前のREST（HTTP 200 / lonely）とDart SDK live test（1 passed / lonely）を
保持し、native Firebase initializationを含むAndroid実行の成功を追加記録する。
App Checkのproduction attestation/enforcement、iOS実行、8感情全体の精度、
日本語音声認識の成功をこの結果から推定しない。


### Japanese STT実発話テストの準備（同日・成功確認前の履歴）

修正済み`lib/voice_test.dart`を
`flutter run -d chrome --web-port 8766 -t lib/voice_test.dart`で起動し、
Chromeのdebug service接続とmain起動を確認した。
既に完了したlocale回帰テスト、build、マイク権限・Android emulator設定の
トラブルシューティングは繰り返していない。
この準備時点ではユーザーが学校にいたため実音声試験を延期し、PASS扱いにしなかった。
その後、同日にユーザーが別の短い文で実発話認識を確認。最新結果は次節に記録する。
今回STTソースと別置きoverlay 11 filesは変更していない。


### Japanese Speech-to-Text実発話結果（2026年10月13日・ユーザー確認）

| 項目 | 確認結果 |
| --- | --- |
| Platform | Flutter Web / Google Chrome（macOS） |
| Package | `speech_to_text` |
| Status | `done` |
| 発話した文 | 「とても寂しいです。」 |
| 実際の認識テキスト | 「とても寂しいです」 |
| 判定 | **完全一致PASS — 発話内容を正しく認識（句点を除く）** |

ユーザーが実発話で確認した結果を記録したもので、agentによる再実行ではない。
ユーザーの訂正により、実際に発話したのは「とても寂しいです。」のみ。
認識結果「とても寂しいです」は句点を除いた発話内容と完全一致し、PASSとする。
発話の冒頭が省略された事実はない。この一例での成功を、すべての発話の精度保証とはしない。
**Androidの日本語音声認識は、まだ成功確認できていない。iOS Simulatorの成功は次節に記録し、iOS実機は未検証。**
Gemini REST、Dart SDK、Android Emulatorの`lonely`成功、およびlocal MP3の
Flutter Web再生（Playing → Completed）の成功記録は保持する。


### iOS Simulator実アプリ確認（2026年10月13日・ユーザー確認）

検証端末：**iPhone 18 Pro Simulator / iOS 27.0**。
以下はユーザーがFlutterテストアプリを操作して確認した結果であり、agentによる再実行ではない。

| 項目 | 実測・操作結果 | 判定 |
| --- | --- | --- |
| Gemini Emotion Analysis | アプリが`lonely`を返した | PASS |
| Japanese Speech-to-Text（`speech_to_text`） | `Status: done`、認識テキスト「今日はとても寂しいです」 | PASS |
| MP3 Playback（`just_audio`） | Play MP3を押し、音声が聞こえることを確認 | PASS |

iOSの音声認識については実際の認識テキストとStatusを記録し、発話原文の詳細が
今回の報告にないため、Chrome試験のような入力との完全一致判定までは主張しない。
Simulatorでの成功はiOS実機の検証を代替しない。
**Android Voiceは成功未確認、Android MP3は未検証**であり、今回の結果から成功を推定しない。

以前のGemini REST（HTTP 200 / lonely）、Dart SDK（1 live test passed / lonely）、
Android Emulator（lonely）、Chrome Voice（とても寂しいです・発話内容と一致）、
Chrome MP3（Playing → Completed）の結果を保持する。
headless browser MP3 harnessのasset load timeoutも未解決の別結果として保持する。

### Issue #4 PR準備状況（2026年10月13日・最新）

サービス選定・backend修復・確認済み結果と制約を説明するPRのレビュー準備は可能。
ただし、全platformの技術検証完了や本番公開準備完了とは扱わない。
残項目はAndroid Voice/MP3、iOS実機、8感情全体の精度、App Check運用、
エラー・timeout動作、無料枠制限、headless MP3 test harness。
Authentication / Firestoreと本番ストーリーの生成・品質は引き続き未検証。
当初のtest files 11件は別置きでレビューした後、承認済みのPR blocker修正で拡張した。
最新packageと生成toneの構成・検証範囲は後述。
この更新は本ドキュメントのみ。Issue #2/#3、test files、Billingは変更せず、
commit/push/mergeは実施していない。


### Issue #4 PR blockers対応（2026年10月13日・再現用package整備）

- 第三者録音`hello-world.mp3`のコピーをPR対象から除外し、同じasset pathの
  `test.mp3`をoriginal generated sine-waveへ置換。以前のChrome/iOS録音再生PASSは
  **過去のfixtureの結果**として保持し、replacement toneの結果と区別する。
- waveformは440 Hz、1秒、mono 44.1 kHz、peak 12%、20 ms fades。
  `tool/generate_tone.py`と`lameenc==1.8.1`でローカル生成（64 kbit/s）。
  録音・声・音楽・cloud TTSは使用しない。生成fixtureはCC0-1.0で提供し、
  旧Apacheライセンスファイルもfixture用のCC0 dedicationに置換した。
  Encoderは別途インストールし、binaryや第三者録音を同梱しない。
- SHA-256：`11dfe6e263ccbbe371046f7b00b50e84a0d1a31e34a999a5bfd375d49db16463`。
  音声形式情報は44.1 kHz mono MP3、約1.045秒（encoder paddingを含む）と確認。
- `pubspec.yaml` / lockfile、Gemini UI `lib/main.dart`、runtime FirebaseOptions、
  fresh runner作成`tool/prepare_project.py`、native permissions設定を追加。
  Android minSdk 24 / iOS deployment target 15.0。Androidのマイク/ネットワーク権限と
  RecognitionService query、iOSのマイク/音声認識purpose stringsを生成runnerで確認。
  個人のFirebase設定はGit外のJSONを`--dart-define-from-file`で注入する。
  `.gitignore`でlocal config/生成物を除外。Firestore/Storage依存は追加しない。
- Flutter 3.47.5 stable / Dart 3.13.4で、fresh setup手順を新しい
  `/tmp/yorisoi_issue4_pr_check`に実行し、runner作成・依存解決・
  permissions・asset一致を確認。Gemini entrypointのWeb build成功。
  native runnerのビルド/起動は今回繰り返していない。
- `probe_gemini.py`はHTTP/network/config/JSON/応答検証failureでnonzero exit。
  HTTP 200 + STOP + 単一`lonely`を検証し、raw response/キー/エラーメッセージは出力しない。
  Python offline tests 5件PASS。修正版probeのlive実行もHTTP 200 / lonely / exit 0。
- 同梱live Dart SDK testもruntime configで実行し1件PASS（lonely）。
  native Core bootstrapのみtest host、HTTP/modelは実通信。
  通常`flutter test`はoffline 5件PASS、live 1件skip。
  browser audio harnessは`experimental` tagでdefault suiteから除外し、未解決の
  rootBundle timeoutは履歴として保持する。通常suiteの成功に含めない。

生成toneは実Flutter Webアプリをfresh runnerから起動し、in-app browserで
Play MP3操作後にCompletedを確認：再生lifecycle PASS。音が聞こえたというclaimはしない。
同じgenerator/encoderで再生成したbytesが一致することも確認した。
completion表示はplayerStateStreamも監視し、再生完了イベントを取りこぼさないようにした。
最終static analysisはNo issues found、offline Flutter testsは5 passed / 1 live skip。
これらの結果は旧録音のChrome/iOS PASSとは別の検証結果。
Android STT/MP3、iOS実機、生成toneのnative再生、production App Check、8感情全体の精度、
quota、統合フローは未検証の範囲を維持する。Billing有効化は実施していない。


PR準備判断：再現用package、original fixture、検証済みprobe、明示的なexperimental除外が
揃い、確認済み範囲と残項目を記載したIssue #4 PRをレビューへ出す準備ができた。
これは本番公開や全platform検証完了を意味しない。新toneのiOS/Android再生・聴感確認、
fresh native build、Android Voice、production App Check、quota、8感情精度は残項目。
