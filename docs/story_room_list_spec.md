# Issue #12 — お話・ペットルーム一覧画面仕様

更新日：2026-11-08。正式なStory ListのFigmaデザインが届くまでの**仮UI**。
本書は利用者が今回指定した要件とIssue #9/#11の実装を基にする。
GitHub Issue #12本文は本環境のread toolsで取得できず、GitHub側のacceptance criteriaとの独立照合は未完了。

## 1. 目的・対象範囲

実Geminiの検証済み`EmotionAnalysisResult`を受け、主感情に合う公開済みのお話を最大3件表示する。
利用者が聴きたいお話を選ぶ。通常2〜3件を目指すが、0/1件でも架空のお話で補完しない。
Pet Radioの再生、TTS、物語生成、Firestore/Storageへの書込み、手動pet変更は行わない。

## 2. デザインの区別

- 原本Figmaの`04 — Pet Radio`四画面は再生画面。一覧へ流用・改名しない。
- 仮UIで新規に構成したもの：見出し、感情の要約、story cards、loading/empty/error案内、選択操作、将来playerへの確認画面。
- 仮UIには常に「仮UI・正式なFigmaデザイン待ち」を表示する。これらの配置は正式承認済みFigmaの再現ではない。
- 再利用：Homeの背景・logo、Zen Maru Gothic、既存の暖色/pink gradient、白い丸角card、柔らかいshadow。
- petは原本FigmaのCat/Rabbit/Dog/Dolphin layerを加工せずPNG exportしたもの。絵文字・代替画像は使わず、縦横比を保つ`BoxFit.contain`で表示する。
- Home/Analysis Loading/Auth/Settingsの既存レイアウトは変更しない。pixel-perfectとは主張しない。
- 正式デザイン到着後は`StoryListView`を差替え、controller/repository/navigation contractを維持する。

## 3. 入力・対応表

入力は`StoryListScreen(result: EmotionAnalysisResult)`。利用者の生の感情文章、email、tokenを一覧へ渡さない。
`StoryRepository.findForAnalysis(result)`を使用し、検索は`result.main`のみ。
副感情は補足表示のみで検索条件・pet割当を変更しない。

| 主感情 | pet |
| --- | --- |
| 悲しい / sad、寂しい / lonely | 猫 / cat |
| 不安 / anxious、ストレス / stressed | うさぎ / rabbit |
| 怒り / angry、嬉しい / happy | 犬 / dog |
| 安心 / calm、その他 / other | イルカ / dolphin |

## 4. 読込と配信gate

本番経路は既存`FirestoreStoryRepository.firebase()`。fixtureやJSON fallbackを自動注入しない。
認証・Firebase/App Check初期化は既存`main.dart`のまま。

1. repositoryが`storyLibraries/current`をserverから確認する。
2. 正常なdraft libraryは空結果。stories queryを開始せず、公開済みと偽らない。
3. approved libraryでは主感情、対応pet、ja-JP、isActive、humanApproved、approved_text、audioStatus=readyをquery・validateする。
4. 実在するbundled audio asset、revision整合等の既存gateは維持する。Firebase Storageは利用しない。
5. displayOrder→storyIdで最大3件。controllerでも主感情/対応pet/公開flag/local audio参照/重複を再確認する。
6. repositoryがrelease/audioの真実を持つ。controllerの再確認だけで配信を承認したりasset存在を捏造しない。

`StoryListController`は読込関数と型付きresultだけに依存する。Firebase・widget・Navigatorを含まない。
同時loadを抑止し、20秒で待機を終了する（repositoryの各read timeoutは既存の15秒）。
画面破棄後の完了を無視し、自動retryはしない。timeout/画面を戻る操作は送信済み通信の中断保証ではない。

## 5. 表示・操作

| 状態 | 表示と操作 |
| --- | --- |
| 読込中 | progressと「公開済みのお話を探しています…」。story選択は表示しない |
| 0件・draft | 「公開済みのお話は現在準備中です。」。Homeへ戻る/再確認。fake cardsなし |
| 1件 | 実在する1件と不足案内。別感情/未承認storyで補充しない |
| 2〜3件 | cardに対応pet、title、description、duration、選択button |
| network/timeout | 接続案内と手動「再試行」 |
| permission/configuration等 | 安全な日本語案内と手動retry。raw SDK例外やmetadataを表示しない |
| navigation失敗 | 一覧に留まり再選択可能。内部例外を表示しない |

durationはmetadataの秒数を分・秒へ表示し、文章量から推定しない。
現行Story modelはaudio-ready時にduration必須。viewには未登録の場合の案内も用意するが、そのために公開gateを緩めない。
listは縦scrollし、狭い画面・文字拡大でも操作へ到達できる。

## 6. 遷移・選択情報

`Home → 実Gemini待機(既存Figma Loading) → StoryListScreen → 選択確認boundary`

- 分析成功の時だけ一覧へ一度pushする。旧`EmotionAnalysisResultScreen`は保存し、今回の通常経路では使用しない。
- main/secondaryの確認は一覧上部へ引継ぐ。Gemini失敗・空入力・取消しでは一覧を開かない。
- 選択時は実recordから`StoryPlaybackRequest(storyId, revision)`を作り、`/story-selection`のargumentsとして渡す。
- 現在の遷移先は「再生画面は準備中です。音声は再生していません。」と明示する最小の確認境界。音声の再生やmock player controlsは実装しない。
- 将来は`OpenStory` callback/遷移先を正式Pet Radioへ置換できる。player実装時は`findById`で公開状態・revision・audioを再検証し、撤回済みstoryを再生しない。
- 遷移待機中は全選択buttonを無効化し、二重pushを防ぐ。Home→一覧→確認からシステムBackで順に戻れる。
- 一覧からHomeへ戻ると元のcontrollerの入力文章が残り、修正できる。永続保存はしない。

## 7. 検証方法・残る制限

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
```

自動testsはfake repository/analyzerとtest専用metadataを使用する。fixtureはapp assetへ登録しない。
8感情の対応、主副の引継ぎ、公開条件、sort/最大3件、draft空結果、読込/timeout/安全error/retry、
二重load/選択、破棄後の完了、実ID/revisionのnavigation、Homeの文章保持と音声回帰を検証する。
既存のFirestore repository testsでserver query/release gateを引き続き検証する。

手動確認は既に登録したdebug tokenを持つ**同じChrome profile・localhost origin**で行う：

```sh
flutter run -d web-server --target lib/main.dart --web-hostname localhost --web-port 8891 --dart-define=YORISOI_APP_CHECK_DEBUG=true
```

Login→Homeで日本語を入力/音声で確定→Share→実Loading→一覧の主感情と対応petを確認する。
現時点のdraft libraryでは空案内が正しい。入力へ戻り文章保持を確認する。
実story cards/選択のbrowser確認は、別途人が承認・audio準備・公開した実metadata/assetが必要。
その確認のために本実装がlibraryをapprovedにしたり、fake production storiesを追加したりしない。
正式Figmaとの視覚比較、今回のChrome end-to-end、公開story選択、実audio playback、iOS/Android実機は未確認。

### 今回の実行記録

- `flutter analyze --no-pub`：No issues。
- `flutter test --no-pub --concurrency=1 --reporter expanded`：**454 passed / 3 skipped**。
  skipは既存のopt-in live emotion tests。fake-based成功をlive API成功と扱わない。
- 最後の仮pet badge/選択buttonの読み上げlabel調整後、一覧widget/navigation tests **13 passed**、analysisもNo issuesを再確認。
- 390×844のwidget renderを`/tmp`へ出力して仮UIの日本語表示・既存背景・元pet画像・card配置を視覚確認。
  test専用metadataを使用したlocal renderであり、Chromeや本番配信story選択の成功ではない。
- この作業でFirebase Console、App Check enforcement、billing、Gitを変更していない。
