import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth/firebase_auth_service.dart';
import 'home_screen.dart';
import 'registration_screen.dart';
import 'forgot_password_screen.dart';
import '../widgets/auth/auth_design.dart';

typedef LoginAction = Future<void> Function({
  required String email,
  required String password,
});

typedef PasswordResetAction = Future<void> Function({required String email});

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.loginAction,
    this.passwordResetAction,
    this.homeBuilder,
  });

  /// Replaces only the network call in tests; success navigation stays the same.
  final LoginAction? loginAction;
  final PasswordResetAction? passwordResetAction;
  final WidgetBuilder? homeBuilder;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  bool get _isBusy => _isSubmitting;

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
        MaterialPageRoute(
          builder: widget.homeBuilder ?? (_) => const HomeScreen(),
        ),
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

  void _openPasswordRecovery() {
    if (_isBusy) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: _emailController.text,
          sendReset: widget.passwordResetAction,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => AuthDesignPage(
    cardTop: 384,
    header: [
      const Positioned(left: 94, top: 84, width: 202, child: AuthLogo()),
      Positioned(
        left: 45,
        top: 262,
        width: 300,
        height: 176,
        child: authImage('pets_group.png', label: '猫、犬、うさぎ、イルカ'),
      ),
    ],
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthTitle('おかえりなさい', 'Welcome back', size: 23),
          const SizedBox(height: 14),
          AuthField(
            label: 'メールアドレス',
            english: 'Email',
            hint: 'you@example.com',
            icon: 'email.svg',
            controller: _emailController,
            enabled: !_isBusy,
            keyboardType: TextInputType.emailAddress,
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
            label: 'パスワード',
            english: 'Password',
            hint: 'パスワード · Password',
            controller: _passwordController,
            enabled: !_isBusy,
            obscure: true,
            validator: (value) =>
                value == null || value.isEmpty ? 'パスワードを入力してください' : null,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: AuthLink(
              'パスワードをお忘れですか？ · Forgot password?',
              key: const Key('auth-forgot-password'),
              onPressed: _isBusy ? null : _openPasswordRecovery,
            ),
          ),
          const SizedBox(height: 14),
          const Spacer(),
          AuthPrimaryButton(
            key: const Key('auth-login-submit'),
            japanese: 'ログイン',
            english: 'Log in',
            onPressed: _isBusy ? null : _login,
            busy: _isSubmitting,
            busyLabel: 'ログイン中...',
          ),
          const SizedBox(height: 14),
          AuthLink(
            '新規登録 · Sign up',
            prefix: 'はじめての方 · New here? ',
            key: const Key('auth-switch-registration'),
            onPressed: _isBusy
                ? null
                : () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistrationScreen(),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
