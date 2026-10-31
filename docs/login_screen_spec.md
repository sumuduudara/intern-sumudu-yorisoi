# Issue #6 ログイン画面の仕様

## 1. 目的と入力

登録済みの利用者が、メールアドレスとパスワードでログインする。
メインアプリはrepository rootにある。入口は `lib/main.dart`。

- メールアドレス：必須。前後の空白を除き、登録画面と同じ簡単な形式チェックを行う。
- パスワード：必須。文字を隠して表示し、値は変更・trimしない。
- ログインには登録用の「6文字以上」チェックを追加しない。認証の可否はFirebaseが判断する。
- 入力エラーは該当欄の下に表示し、認証リクエストは送らない。

## 2. 送信・成功・失敗

`LoginScreen` → `FirebaseAuthService.login()` →
Firebase Authenticationの `signInWithEmailAndPassword()` の順に呼ぶ。
送信中は入力欄、ログインボタン、新規登録リンクを無効にし、ローディングを表示する。
関数の先頭でも送信中かを確認し、二重送信を防ぐ。

成功後は既存の `HomeScreen` へ移動する。
`pushAndRemoveUntil` でそれまでの画面履歴をすべて削除し、戻る操作でログイン画面へ戻らない。
現在のHomeはIssue #7/#8/#9の入力・音声・実Firebase AI分析・結果表示に接続している。Pet Roomは範囲外。

失敗時はログイン画面に留まり、SnackBarに日本語で理由を表示して再試行できる。

| Firebase code | 表示内容 |
| --- | --- |
| invalid-credential / invalid-login-credentials / wrong-password / user-not-found | メールアドレスまたはパスワードが正しくありません。 |
| invalid-email | 正しいメールアドレスを入力してください。 |
| user-disabled | このアカウントは無効になっています。 |
| network-request-failed | 通信に失敗しました。接続を確認して、もう一度お試しください。 |
| too-many-requests | 試行回数が多すぎます。しばらく待ってからお試しください。 |
| operation-not-allowed | 現在、ログインをご利用いただけません。時間をおいてお試しください。 |
| その他のFirebaseエラー / 予想外の例外 | ログインに失敗しました。しばらく待ってからもう一度お試しください。 |

存在しないメールと誤ったパスワードは同じ文言にし、内部の例外文は表示しない。
コントローラーは `dispose()` で解放する。await後の画面操作は `mounted` を確認する。

## 3. 画面の移動

- WelcomeScreenの「ログイン」→ LoginScreen。既存の「新規登録」は維持する。
- RegistrationScreenの「アカウントをお持ちの方 · Have an account? ログイン」→ LoginScreen。
- LoginScreenの「はじめての方 · New here? 新規登録 · Sign up」→ RegistrationScreen。
- 登録とログインの切り替えは `pushReplacement` とし、交互に履歴を積み重ねない。
- Issue #5の登録処理・入力条件・既存テストは維持する。

## 4. セッションの保持と起動時の復元

Webでは `setPersistence(Persistence.LOCAL)` を明示し、同じブラウザー・同じoriginで
リロードや再起動後もFirebase SDKが認証状態を保持する。独自にパスワードやトークンを保存しない。
ブラウザーの保存領域の制限・削除やプライベートモードでは保持が保証されない。
Android/iOSはFirebase SDKの標準の永続化に任せる。ただし現在のローカルFirebase設定はWeb用で、
今回のnative実行は未検証。

実アプリの `main()` は復元処理を渡し、`SessionStartupScreen` が次のように動く。

1. Firebaseの最初の `authStateChanges()` イベントを待つ。
2. 保存された利用者がなければWelcomeScreenを表示する。
3. 利用者がいれば `reload()` とID tokenの強制更新を行い、成功してtokenがあればHomeScreenを表示する。
4. 無効・削除・期限切れ等のセッションはsignOutしてWelcomeScreenを表示する。
5. 通信などの確認エラーは保存された利用者を消さず、確認失敗と「再試行」を表示する。
   確認できるまではHomeScreenを表示しない。オフラインでの自動ログインは行わない。

復元は起動時に一度行う。起動後の常時監視、メール確認、
アプリ復帰時の再検証は今回の範囲外。ログアウトと再設定メール送信は下記のとおり実装する。サーバーのアクセス制御を画面遷移だけで代用しない。
既存のapp shellテストは復元関数を省略できる。これはテスト用で、実mainは必ず復元関数を渡す。

## 5. 確認方法と未検証事項

- widget testsは偽の認証関数を渡し、実際の利用者を作成・認証しない。
- サービステストは偽のFirebaseAuth/Userで呼び出しとセッション確認を検証する。
- Chromeの実Firebaseログイン、ブラウザー再起動後のLOCAL永続化は自動テストの成功と分けて確認する。
- Web専用のsetPersistence呼び出しはVMテストでは実行されない。
- Firebase Console、firebase.json、認証情報は変更しない。

### Chromeでの手動確認（未実施）

1. rootで `flutter run -d web-server --web-hostname=localhost --web-port=7357` を実行し、
   通常のChromeプロファイルで `http://localhost:7357` を開く。
2. 保存済みログインがある場合はHomeが表示される。新しいブラウザープロファイル、または
   そのoriginのサイトデータを消した開発用プロファイルで未ログイン状態から確認する。
3. Welcome → ログイン。空欄・不正なメールで送信せず、入力エラーが出ることを確認する。
4. 自分が利用を許可された既存の開発用アカウントで、誤ったパスワードの日本語エラーを確認する。
   必要以上に繰り返さない。
5. 正しい認証情報でログインし、送信中表示、Homeへの移動、アプリ内の戻り先がないことを確認する。
6. 同じoriginのままリロードし、確認中 → Homeを確認する。サーバーを止めて同じコマンドで再実行し、
   同じ通常プロファイル・URLで復元を確認する。Flutterの一時Chromeプロファイルと混同しない。
7. 未ログインの開発用プロファイルで、登録 → ログイン → 登録のリンクと、履歴が増えないことを確認する。
8. 任意の通信失敗確認：Chrome DevToolsのRequest blockingで
   `*identitytoolkit.googleapis.com*` と `*securetoken.googleapis.com*` だけを遮断してリロードする。
   localhostのアプリ本体は遮断しない。SDKのタイムアウト後、確認失敗と再試行を確認する。
   遮断を解除して再試行し、Homeが表示されることを確認する。この手順も未実施。

参考：[Firebase Auth Flutter公式ドキュメント](https://firebase.google.com/docs/auth/flutter/start#persisting_authentication_state)

### 自動確認の実行結果（2026-10-18）

- `flutter analyze --no-pub`：No issues found。
- `flutter test --no-pub`：70 tests passed。追加前の50個もすべて成功。登録テストは変更していない。
- 内訳：登録・app shell 12、ログインwidget 18、起動時復元widget 4、
  サービス 20、ログアウトwidget 4、再設定widget 12。
- ログインの既存テストは新しいボタンに合わせて対象finderだけを絞り、元の確認を維持した。
- 初回に検出した再試行時のsetStateエラーを修正し、全体を再実行して成功した。
- 実Firebaseログイン、実ブラウザーでのログアウト後の永続状態、reset emailの受信・リンク操作、native動作は未検証。

## 6. ログアウトとパスワード再設定（追加）

### ログアウト

- HomeScreenの「ログアウト」から `FirebaseAuthService.signOut()` → `FirebaseAuth.signOut()` を呼ぶ。
- 完了するまでは「ログアウト中...」と表示し、連打を防ぐ。
- 成功後にWelcomeScreenへ移動し、前のHomeを含むアプリ内履歴を削除する。
- Firebase SDKが保持中の認証状態を解除する。`LOCAL`の保持方針は変更しない。
  次の起動で保存された利用者がなければWelcomeScreenになる。
- 失敗時はHomeに留まり、日本語で「ログアウトできませんでした。もう一度お試しください。」を表示する。
- await後はmountedを確認する。失敗時だけボタンを再び使える状態に戻す。

### 忘れたパスワード（2026-10-29更新）

- Loginの「パスワードをお忘れですか？」から原本Figmaの02-Aへ進む。入力済みemailを引き継ぐ。
- 02-Aでemailを確認し、既存の`sendPasswordResetEmail()`を呼ぶ。password入力は不要。
- 成功と`user-not-found`は同じ02-Bへ進み、アカウントの有無を公開しない。
- 02-Bはemail app起動（利用できなければ手動案内）、60秒の再送待機、ログインへ戻る操作を備える。
- 02-Cは`mode=resetPassword` / `oobCode`を受け、`verifyPasswordResetCode()`で検証してから入力可能にする。
- 新しいpasswordは8文字以上・英字と数字・確認一致を確認し、`confirmPasswordReset()`で更新する。
- 実SDKの成功後だけ02-Dを表示し、ログインへ戻る。自動ログインは行わない。
- 認証・入力の重複防止、mounted確認、controller解放、安全な日本語エラーを維持する。
- **既存のemail template/action handler URLは変更していない。** 現在のemail linkがFirebase標準画面を開く場合、
  custom 02-Cを自動で開くには、承認済みのhosted app URLを別途設定する必要がある。
- SDK fakeを使う自動testsの成功は、実email配信や実password変更の成功と区別する。

詳細と原本frame IDs：[auth_ui_integration.md](auth_ui_integration.md)。

### 追加の手動確認（未実施）

1. Homeで「ログアウト」を押し、完了後Welcomeへ戻り、アプリ内でHomeへ戻れないことを確認する。
2. 同じChromeプロファイル・同じoriginでリロードし、Welcomeのままであることを確認する。
3. Loginでパスワードを空にしたまま、空欄・不正なメールの再設定エラーを確認する。
4. 自分が管理し、試験を許可された開発用メールを入れて再設定を押す。
   日本語の案内、メール受信、Firebase側の再設定リンクを確認する。
5. 自分で再設定を完了した場合は、新しいパスワードでログインを確認する。
   自動テストは実際のメールを送らず、Firebase Consoleや設定も変更しない。

参考：[Firebaseのパスワード再設定API](https://firebase.google.com/docs/auth/flutter/manage-users#send_a_password_reset_email)
