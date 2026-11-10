import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth/firebase_auth_service.dart';
import 'home_screen.dart';
import 'registration_screen.dart';
import '../widgets/auth/auth_design.dart';

typedef LoginAction = Future<void> Function({
  required String email,
  required String password,
});

typedef PasswordResetAction = Future<void> Function({required String email});

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.loginAction, this.passwordResetAction});

  /// Replaces only the network call in tests; success navigation stays the same.
  final LoginAction? loginAction;
  final PasswordResetAction? passwordResetAction;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailFieldKey = GlobalKey<FormFieldState<String>>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _isResettingPassword = false;

  bool get _isBusy => _isSubmitting || _isResettingPassword;

  static const _resetFeedback =
      '該当するアカウントがある場合は、パスワード再設定メールを送信しました。受信トレイと迷惑メールをご確認ください。';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isBusy || !_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    var openedHome = false;
    setState(() => _isSubmitting = true);
    try {
      final action = widget.loginAction;
      if (action != null) {
        await action(email: email, password: password);
      } else {
        await FirebaseAuthService().login(email: email, password: password);
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      openedHome = true;
    } on FirebaseAuthException catch (error) {
      _showMessage(switch (error.code) {
        'invalid-credential' ||
        'invalid-login-credentials' ||
        'wrong-password' ||
        'user-not-found' => 'メールアドレスまたはパスワードが正しくありません。',
        'invalid-email' => '正しいメールアドレスを入力してください。',
        'user-disabled' => 'このアカウントは無効になっています。',
        'network-request-failed' => '通信に失敗しました。接続を確認して、もう一度お試しください。',
        'too-many-requests' => '試行回数が多すぎます。しばらく待ってからお試しください。',
        'operation-not-allowed' => '現在、ログインをご利用いただけません。時間をおいてお試しください。',
        _ => 'ログインに失敗しました。しばらく待ってからもう一度お試しください。',
      });
    } catch (_) {
      _showMessage('ログインに失敗しました。しばらく待ってからもう一度お試しください。');
    } finally {
      // Keep the old route disabled until it is removed after success.
      if (mounted && !openedHome) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetPassword() async {
    // Reset needs a valid email, not the forgotten password.
    if (_isBusy || !_emailFieldKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    setState(() => _isResettingPassword = true);
    try {
      final action = widget.passwordResetAction;
      if (action != null) {
        await action(email: email);
      } else {
        await FirebaseAuthService().sendPasswordResetEmail(email: email);
      }
      _showMessage(_resetFeedback);
    } on FirebaseAuthException catch (error) {
      _showMessage(switch (error.code) {
        // Do not reveal whether an address has an account.
        'user-not-found' => _resetFeedback,
        'invalid-email' => '正しいメールアドレスを入力してください。',
        'network-request-failed' => '通信に失敗しました。接続を確認して、もう一度お試しください。',
        'too-many-requests' => '試行回数が多すぎます。しばらく待ってからお試しください。',
        'operation-not-allowed' => '現在、パスワード再設定をご利用いただけません。',
        _ => '再設定メールを送信できませんでした。しばらく待ってからもう一度お試しください。',
      });
    } catch (_) {
      _showMessage('再設定メールを送信できませんでした。しばらく待ってからもう一度お試しください。');
    } finally {
      if (mounted) setState(() => _isResettingPassword = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => AuthDesignFrame(
    signUp: false,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeading(signUp: false),
          const SizedBox(height: 14),
          AuthField(
            fieldKey: _emailFieldKey,
            label: 'メールアドレス',
            english: 'Email',
            hint: 'you@example.com',
            icon: 'icon_email',
            enabled: !_isBusy,
            controller: _emailController,
            email: true,
            autofillHints: const [AutofillHints.email],
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'メールアドレスを入力してください';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                return '正しいメールアドレスを入力してください';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          AuthField(
            fieldKey: const Key('auth-password'),
            label: 'パスワード',
            english: 'Password',
            hint: 'パスワード · Password',
            icon: 'icon_lock',
            enabled: !_isBusy,
            controller: _passwordController,
            obscure: true,
            autofillHints: const [AutofillHints.password],
            validator: (value) =>
                value == null || value.isEmpty ? 'パスワードを入力してください' : null,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('auth-password-reset'),
              onPressed: _isBusy ? null : _resetPassword,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _isResettingPassword
                    ? '送信中...'
                    : 'パスワードをお忘れですか？ · Forgot password?',
                textAlign: TextAlign.right,
                style: authText(
                  12,
                  color: authPink,
                  weight: FontWeight.w700,
                  height: 17 / 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 62),
          AuthPrimaryButton(
            label: 'ログイン',
            english: 'Log in',
            busyLabel: 'ログイン中...',
            busy: _isSubmitting,
            onPressed: _isBusy ? null : _login,
          ),
          const SizedBox(height: 14),
          AuthSwitchLink(
            signUp: false,
            onPressed: _isBusy
                ? null
                : () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegistrationScreen(),
                      ),
                    );
                  },
          ),
        ],
      ),
    ),
  );
}
