# 認証UI — 原本Figmaへの復元

更新日：2026-11-08。原本：Yorisoi App UI、Sign Up `2:2` / Login `2:54`。
Figma screenshots、取得したlayout/style情報、元画像・SVGを参照する。Home背景の代用ではない。

## 復元した構成

| 項目 | Sign Up | Login |
| --- | --- | --- |
| 基準viewport | 390 × 844 | 390 × 844 |
| card位置/寸法 | x14 / y286 / 362 × 538 | x14 / y384 / 362 × 440 |
| pets位置/寸法 | x57 / y172 / 276 × 162 | x45 / y262 / 300 × 176 |
| primary button位置/寸法 | x36 / y715 / 318 × 56 | x36 / y715 / 318 × 56 |
| card角丸 | 34 | 34 |
| input角丸/通常高さ | 18 / 48 | 18 / 48 |

Auth専用の`AuthDesignFrame`、brand、heading、field、button、linkを使用する。
Zen Maru Gothicの400/500/700/900、Yomogi、原本の色・fade・shadow・配置を使う。
brandの文字は元のtypefaceで描き、heart/iconは原本SVG。logo frame PNGに入った不透明背景を重ねて隠す実装はしない。
SVGを忠実にrenderするため`flutter_svg: 2.3.2`を追加。global Material themeは変更しない。

## 原本からの意図した相違・適応

- password hintは承認された既存ルールに合わせ**6文字以上**。Figmaの8文字以上にvalidationを変更しない。
- nickname欄の「Sumudu」は原本のplaceholderのみ。初期値や保存値ではなく、空欄ならprofile writeを行わない。
- referenceより狭い画面ではheroを比例縮小し、form textは読みやすい大きさを維持する。
- cardは固定高さで切らず、validation errors/文字拡大に応じて伸びる。keyboard表示時も縦scrollできる。
- brandはlogoとしてreference比率を保ち、個々の文字をtext scaleで崩さず、代わりに読み上げlabelを付ける。
- loading/error/profile部分成功の案内は動作上必要な追加stateであり、原本Figmaにある状態と偽らない。
- native text/SVGのantialiasing、font metrics、keyboard/insetsによる差は残り得る。pixel-perfectとは主張しない。

## 認証・起動・画面遷移

- session復元成功なら既存Home。未ログインなら復元したLogin。Firebase初期化/App Checkのcodeは変更しない。
- `WelcomeScreen`は旧logout routeとの互換wrapperとして残し、内部で同じLoginを描く。新しいWelcome画面を発明しない。
- Login/Sign Up相互linkは既存のpushReplacementを維持し、routeの積み重ねを防ぐ。
- Login/本番登録成功時は既存通りHomeへ進み、認証画面historyを消す。
- password resetは既存のemail検証・送信・情報漏えいを防ぐ日本語feedbackを維持する。
  別のForgot Password / Set New Password画面やemail action handlerは今回追加しない。
- logout処理やHome、Gemini、voice、Story List、Firestore repository、rules、billingを変更しない。

## Optional nicknameの保存と部分成功

`FirebaseAuthService.register(email, password, nickname)`は一度だけcreateUserを実行する。
名前が空でなければ、その戻り値のUserへ`updateDisplayName(trimmedNickname)`をawaitする。
Firestore、local preferences、logへnicknameを別保存しない。

1. createUser失敗：既存の日本語登録エラー。profileは変更しない。
2. createUser成功・profile成功：登録成功としてHomeへ進む。
3. createUser成功・profile失敗：safeな`RegistrationProfileException`で部分成功を区別。
   raw SDK errorやprofile値を表示/logしない。accountを削除・再作成・自動signOutしない。
4. UIはaccount作成済みと明示し、email/password/再登録をロックする。
   nicknameだけ編集して再保存するか、保存確認なしで続けることを利用者が選べる。
5. retryは`retryRegistrationNickname(expectedUserId, nickname)`だけを呼ぶ。
   現在の認証user IDが作成済みuser IDと一致しない場合は更新しない。
6. retry待機中は再retry/continueを無効にする。破棄後のUI更新は行わない。
7. 通信エラーでもserver側writeが完了した可能性があるため、続行時は「保存は未確認」と表示する。
   名前が確実に未保存と断定したり、無断で消したりしない。

## 検証

widget testsはrequired/email/6文字/confirmation、loading/重複防止、日本語error、reset、
session/logout/navigation、nickname部分成功・retry・続行・disposeを確認する。
real AuthService→fake FirebaseAuth SDKのwidget統合testも用意する。real accountは作成しない。
390×844のcard/hero/button geometryと、320px・text scale 1/2・keyboard inset 0/280でoverflowと操作到達を検証する。

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
```

実font/artworkを使った390×844のlocal widget rendersをFigma screenshotsと視覚比較した。
比較PNGは`/tmp/yorisoi_auth_login.png`と`/tmp/yorisoi_auth_signup.png`。テスト用renderであり、Chrome live認証成功の証拠ではない。
real Firebaseへのnickname保存/再起動後のdisplayName、今回のChrome認証フロー、native実機は未確認。

今回の実行結果：全Flutter suite **480 passed / 3 skipped**。skipは既存opt-in live emotion tests。
最終`flutter analyze --no-pub`は**No issues**。最後のtest lint調整後、nickname widget/SDK-fake統合testsも**5 passed**を再確認。
390×844の実font/artwork renderも2件完了し、card位置とprimary buttonのy715・高さ56を確認した。
これらは自動/ローカルrender検証であり、実account作成やChrome認証の再成功を主張しない。

手動確認は既存の同じbrowser profile/originを使う。未ログインならLogin、ログイン済みならHomeからlogoutしてLoginを確認する。
Login/Sign Up切替、invalid input、reset feedback、既存test accountでのLogin、session復元、logoutを確認する。
nicknameの実保存は利用者が意図して作る検証accountでのみ確認し、自動testのためだけにaccountを作らない。
App Check tokenやpassword等をchat/screenshotへ含めない。

## 変更file一覧

- `lib/app/yorisoi_app.dart`
- `lib/presentation/screens/login_screen.dart`
- `lib/presentation/screens/registration_screen.dart`
- `lib/presentation/screens/welcome_screen.dart`
- `lib/presentation/screens/session_startup_screen.dart`
- `lib/presentation/widgets/auth/auth_design.dart`（新規）
- `lib/services/auth/firebase_auth_service.dart`
- `pubspec.yaml` / `pubspec.lock`
- `assets/images/auth/bg_login.jpg` / `bg_signup.jpg` / `pets_group.png`（新規）
- `assets/images/auth/heart_login.svg` / `heart_signup.svg` / `icon_user.svg` / `icon_email.svg` / `icon_lock.svg`（新規）
- `assets/README.md`
- `docs/auth_figma_restoration.md`（本書・新規）
- `test/app_startup_test.dart`
- `test/session_startup_test.dart`
- `test/login_screen_test.dart`
- `test/registration_screen_test.dart`
- `test/password_reset_test.dart`
- `test/firebase_auth_service_test.dart`
- `test/auth_figma_layout_test.dart`（新規）
- `test/registration_nickname_test.dart`（新規）

Git操作、branch/PR操作、Firebase Console/enforcement/billingの変更は行っていない。
