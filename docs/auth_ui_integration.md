# 認証UIと通常アプリの統合（2026-10-29）

## 原本と実装

原本：[Yorisoi App UI](https://www.figma.com/design/uiTEgE5aP1YTZCTijhhoEn/Yorisoi---App-UI)。
正しいinternship接続でdesign context、screenshot、source assetsを取得した。

| 原本frame | ID | 実装 |
| --- | --- | --- |
| 01 - Sign Up | 2:2 | RegistrationScreen / WelcomeScreen |
| 02 - Login | 2:54 | LoginScreen |
| 02-A — Forgot Password | 23:2 | ForgotPasswordScreen |
| 02-B — Check Your Email | 23:49 | CheckEmailScreen |
| 02-C — Set New Password | 23:103 | SetNewPasswordScreen |
| 02-D — Password Updated | 23:169 | PasswordUpdatedScreen |

原本に別のWelcome frameはない。既存のWelcome routeは01の登録画面を表示する。
以前のplain WelcomeはFirebaseやentrypointの問題ではなく、旧Material UIのままだったことが原因。

背景・各pet・heart・iconは原本sourceをローカルに保存。PNGを画面全体の画像として使っていない。
既存のZen Maru GothicとYomogiを再利用し、白card、pink gradient、入力欄、spacingを原本に合わせた。
共有AuthDesignPageは390×844でcard位置を維持し、validation errors、文字拡大、keyboard時にはscrollする。
認証UIの実装は`lib/presentation/widgets/auth/auth_design.dart`に共通化する。

### 意図した差分

- 既存の登録条件は6文字以上のまま。原本の「8文字以上」hintは6文字以上に修正し、誤った案内をしない。
- 新しいpassword再設定フォームは原本の8文字以上、英字と数字、確認一致を実際に検証する。
- ニックネームは任意。入力時は登録後にAuthのdisplayNameを更新し、保存失敗でもアカウント作成を再送しない。
- 原本のsample emailを固定表示せず、利用者の入力値を引き継ぐ。sample nicknameは入力済みの実データではなくhint。
- 02-Bにはアカウントの存在を明かさない補足、再送の60秒待機、メールアプリ起動失敗の案内を追加する。
- password rulesのcheckは条件を満たした場合だけpinkにする。空のformで達成済みと見せない。
- 原本にないエラーやloadingは同じ画面内で表示し、cardの外へ切れないよう高さを伸ばす。

## 実際の機能

- `main.dart`のFirebase初期化と既存のsession確認は維持する。
- sessionがなければ01。Login/Registerが成功すると履歴を消して既存の実Homeへ進む。
- Login/Registration間のリンク、重複送信防止、日本語validation、Auth errors、controller解放を維持する。
- Homeは実EmotionAnalysisService → FirebaseEmotionModel → Firebase AI Logicを使用し、実待機中に既存のloadingを表示する。
- voiceの日本語結果は同じcontrollerで編集してからShareできる。input、mic色、circular clip、loading見出しは変更していない。
- 結果からHomeへ戻ると文章を保持する。既存のSettings内のLogoutでAuth signOut後01へ戻る。
- emotional textのFirestore保存やPet Roomを追加していない。Home、voice、emotionサービスの実装は本変更では変更していない。

### パスワード再設定

1. Loginから02-Aへ移動し、入力済みemailを引き継ぐ。
2. `sendPasswordResetEmail()`を呼ぶ。`user-not-found`も同じ02-Bとし、存在するaccountを推測できない案内にする。
3. 再送は60秒待ち、処理中も重複を防ぐ。自動再送しない。
4. 「メールアプリを開く」は`url_launcher`でOSの既定mailto handlerを開く。
   端末によって作成画面が開く場合があり、受信トレイを直接開く保証はない。handlerがなければ手動確認を案内する。
5. appが`?mode=resetPassword&oobCode=…`付きで起動したときだけ02-Cを開く。
   codeを既存のFirebase projectで`verifyPasswordResetCode()`し、成功後に入力可能にする。
6. validation後に`confirmPasswordReset()`を実行する。SDK成功後だけ02-Dへ進む。自動ログインはしない。
7. codeの期限切れ・使用済み・無効・通信失敗には日本語案内と再試行／新しいリンク送信を提供する。
   password、code、生のSDK例外をログや画面へ表示しない。

### 外部設定・live確認の残り

**Firebase Console、email template、action-handler URL、credentials、billingは変更していない。**
既存emailがFirebase標準handlerを開く場合、そのリンクは引き続き標準画面で処理される。
独自02-Cへ直接到達させるには、承認済みのhosted appをcustom email action handlerとして設定する必要がある。
localhostを本番handlerとして勝手に設定しない。mobile app links、hosting/deploymentも今回設定していない。

このため、02-C/02-DのUIと実SDK接続は実装済みだが、**配信email → このapp → 実password更新**は未検証。
過去のreset email受信確認と、本変更後の配信・更新確認を混同しない。
仕様参考：[Firebase公式custom email action handler](https://firebase.google.com/docs/auth/custom-email-handler)。

## 確認結果

- `flutter pub get`：成功。`flutter_svg`と`url_launcher`を追加。Firebase dependenciesの指定は維持。
- `flutter analyze`：No issues found。
- `flutter test --reporter expanded`：269 passed / 3 skipped。skipは既存の任意live AI tests。
- 既存の登録／ログイン／session／logout／voice／AI testsを保持し、変更した原本文言・key・画面遷移に合わせてfinderを更新。
- Login → voice result編集 → 実EmotionAnalysisService／Firebase adapter／JSON parser → 結果 → Home → Logoutを一連のwidget testで確認。
  Auth、speech callbacks、SDK response、logout network部分はfake。これはlive Firebase成功の証明ではない。
- code検証、8文字・英数字・一致、期限切れ、無効code、SDK error、二重送信、dispose後のresponse、再送、launcher失敗を確認。
- frames全6件の390×844 card bounds・原本assetsと、320×480/2倍textでのscrollを確認。
- 6画面のfont-loaded widget-render screenshotsを目視確認。これらのrecovery screensはfixtureによる描画で、実password変更の記録ではない。
- 実`main.dart`をlocal web serverで起動し、Codex内のbrowserでRegistration/Login/Forgotの表示・空入力validation・navigationを確認。
- Google ChromeのComputer Use permissionがないため、**今回の実Chrome authenticated E2Eは未実施**。
  新規の実account作成、実password更新、reset email再配信は行っていない。
- 以前の`home_live.dart`の実Gemini成功記録は別途`home_emotion_analysis_integration.md`に保持する。今回の新しいlive結果とはしない。
- iOS/Android実機／Simulator、本変更後のsession復元と実voice→実AI一連の手動試験は未実施。
  現在のFirebase optionsはWeb用。nativeを確認済みとはしない。

## 通常アプリの起動と手動確認

```sh
cd /Users/sumuduudara/intern-sumudu-yorisoi
flutter run -d chrome --web-port 8879
```

`--target lib/home_live.dart`を付けない。通常の`main.dart`と認証を使用する。

1. 未ログインでは01の登録画面を確認し、Loginリンクから02へ進む。
2. 空欄／不正emailを確認。利用を許可された既存開発accountで自分でLoginする。
3. Homeで「今日はひとりで寂しいです」を入力、またはmic ON/OFF後に日本語文章を編集してShareする。
4. 実待機中のloading、主感情と任意副感情、入力へ戻る操作、元の文章を確認する。AIは毎回同じ結果を保証しない。
5. 同じbrowser/originでreloadしてsessionを確認。SettingsのLogout後、reloadでも01のままか確認する。
6. Forgotから自分の管理するemailへ送信し、02-B・受信・再送待機・launcherを確認する。
7. custom action handlerが承認・設定された環境でのみ、email link→02-C→実更新→02-D→新passwordでLoginを手動確認する。
   passwordやoobCodeをチャット、screenshot、公開資料へ貼り付けない。

## 変更ファイル一覧

以下は本作業で編集・追加したsource、tests、docs、assets。Git操作は実施していない。

- `assets/README.md`
- `assets/images/auth/back.svg`
- `assets/images/auth/bg_auth.png`
- `assets/images/auth/bg_registration.png`
- `assets/images/auth/cat.png`
- `assets/images/auth/check_small.svg`
- `assets/images/auth/check_success.svg`
- `assets/images/auth/dog.png`
- `assets/images/auth/email.svg`
- `assets/images/auth/envelope.svg`
- `assets/images/auth/glow.svg`
- `assets/images/auth/heart_login.svg`
- `assets/images/auth/heart_registration.svg`
- `assets/images/auth/lock.svg`
- `assets/images/auth/nickname.svg`
- `assets/images/auth/paw_active.svg`
- `assets/images/auth/paw_idle.svg`
- `assets/images/auth/paw_tip.svg`
- `assets/images/auth/pets_group.png`
- `assets/images/auth/rabbit.png`
- `assets/images/auth/sparkle_left.svg`
- `assets/images/auth/sparkle_right.svg`
- `docs/auth_ui_integration.md`
- `docs/login_screen_spec.md`
- `docs/registration_screen_spec.md`
- `lib/app/theme/app_theme.dart`
- `lib/app/yorisoi_app.dart`
- `lib/main.dart`
- `lib/presentation/screens/check_email_screen.dart`
- `lib/presentation/screens/forgot_password_screen.dart`
- `lib/presentation/screens/login_screen.dart`
- `lib/presentation/screens/password_recovery_support.dart`
- `lib/presentation/screens/password_updated_screen.dart`
- `lib/presentation/screens/registration_screen.dart`
- `lib/presentation/screens/set_new_password_screen.dart`
- `lib/presentation/screens/welcome_screen.dart`
- `lib/presentation/widgets/auth/auth_design.dart`
- `lib/services/auth/firebase_auth_service.dart`
- `pubspec.lock`
- `pubspec.yaml`
- `test/app_startup_test.dart`
- `test/auth_design_test.dart`
- `test/authenticated_emotion_flow_test.dart`
- `test/firebase_auth_service_test.dart`
- `test/login_screen_test.dart`
- `test/main_application_flow_test.dart`
- `test/password_recovery_flow_test.dart`
- `test/password_reset_test.dart`
- `test/registration_screen_test.dart`

`flutter pub get`によりpackage metadata/cacheと、次のplatform registrantも自動更新された。手動編集はしていない。

- `ios/Runner/GeneratedPluginRegistrant.m`
- `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`

Generated/ignored filesを含むため、この一覧全てを無条件でstageする指示ではない。SourceTreeで利用者が差分を確認する。
