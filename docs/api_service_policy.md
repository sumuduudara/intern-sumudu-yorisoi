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
6. 対応する音声ストーリーをFirebase Storageから取得
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
- MP3ファイルはFirebase Storageに保存する。
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

未検証：

- Firebaseプロジェクトへの接続
- Gemini APIへの実際のリクエスト
- 日本語の8感情分類の精度
- エラー・タイムアウト処理
- App Checkの実動作
- 無料枠の利用制限

2026年10月10日に実APIへのリクエストを行ったが、エラーにより感情分類は未確認である。

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

### 4.2 検証結果

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

Firebase AI Logicの設定エラーの原因を引き続き調査する。
エラーが解決した後、8種類の感情分類の精度を検証する。
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
- 日本語音声の認識、権限許可、実機・エミュレーターでの動作：未検証。

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
- パッケージのビルド確認は実施済み。実際のMP3再生は未検証。

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
| Firebase AI Logic       | テキストから8感情へ分類        | 採用候補。実API呼び出しは404エラー     |
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

| 検証項目                                | 2026年10月11日時点の結果                     |
| --------------------------------------- | -------------------------------------------- |
| Flutterパッケージ導入・静的解析         | 成功                                         |
| Androidテストアプリの起動               | 成功                                         |
| iOS Simulator向けビルド                 | 成功（過去の検証）                           |
| Firebase AI Logicの感情分類             | 失敗。`genai config not found`。原因は未特定 |
| 日本語Speech-to-Text                    | 未検証                                       |
| 事前MP3生成                             | 未検証                                       |
| `just_audio`による実MP3再生             | 未検証                                       |
| Cloud Firestore・Authenticationの実動作 | 未検証                                       |
| Firebase Storageへの保存                | 未検証。Sparkでは利用できない                |

### 9.1 次の対応

1. Firebase AI Logicのプロバイダー設定・バックエンド状態を調査し、感情分類を再試験する。
2. `speech_to_text`の日本語音声認識を実機で検証する。
3. 権利上利用可能なサンプルMP3で`just_audio`の再生を確認する。
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

※ FlutterアプリおよびFirebase AI Logicとの
連携動作は別途検証が必要。
