import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth/firebase_auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../widgets/auth/auth_design.dart';

typedef RegistrationAction = Future<void> Function({
  required String email,
  required String password,
});

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, this.registrationAction});

  /// Tests can supply an action without connecting to Firebase.
  final RegistrationAction? registrationAction;

  @override
  State<RegistrationScreen> createState() {
    return _RegistrationScreenState();
  }
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final nickname = _nicknameController.text.trim();
    var openedHome = false;
    setState(() => _isSubmitting = true);
    try {
      final action = widget.registrationAction;
      if (action != null) {
        await action(email: email, password: password);
      } else {
        await FirebaseAuthService().register(email: email, password: password);
      }
      var profileSaved = true;
      if (action == null && nickname.isNotEmpty) {
        try {
          await FirebaseAuthService().updateNickname(nickname);
        } catch (_) {
          profileSaved = false;
        }
      }
      _showMessage(
        profileSaved ? '登録が完了しました。' : '登録は完了しましたが、ニックネームを保存できませんでした。',
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        openedHome = true;
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(switch (error.code) {
        'email-already-in-use' => 'このメールアドレスはすでに登録されています。',
        'invalid-email' => '正しいメールアドレスを入力してください。',
        'weak-password' => 'より安全なパスワードを入力してください（6文字以上）。',
        'network-request-failed' => '通信に失敗しました。接続を確認して、もう一度お試しください。',
        'too-many-requests' => '試行回数が多すぎます。しばらく待ってからお試しください。',
        'operation-not-allowed' => '現在、新規登録をご利用いただけません。時間をおいてお試しください。',
        _ => '登録に失敗しました。しばらく待ってからもう一度お試しください。',
      });
    } catch (_) {
      _showMessage('登録に失敗しました。しばらく待ってからもう一度お試しください。');
    } finally {
      if (mounted && !openedHome) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => AuthDesignPage(
    background: 'bg_registration.png',
    cardTop: 286,
    cardPaddingTop: 24,
    header: [
      const Positioned(
        left: 101,
        top: 58,
        width: 188,
        child: AuthLogo(registration: true),
      ),
      Positioned(
        left: 57,
        top: 172,
        width: 276,
        height: 162,
        child: authImage('pets_group.png', label: '猫、犬、うさぎ、イルカ'),
      ),
    ],
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: AuthTitle('はじめまして', 'Create your account', size: 23),
              ),
              Transform.rotate(
                angle: -.0872665,
                child: Text(
                  'よろしくね ♡',
                  style: authText(
                    14,
                    color: const Color(0xFFC27A7F),
                    font: 'Yomogi',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AuthField(
            fieldKey: const Key('registration-nickname'),
            label: 'ニックネーム（任意）',
            english: 'Nickname (optional)',
            hint: 'Sumudu',
            icon: 'nickname.svg',
            controller: _nicknameController,
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 10),
          AuthField(
            fieldKey: const Key('registration-email'),
            label: 'メールアドレス',
            english: 'Email',
            hint: 'you@example.com',
            icon: 'email.svg',
            controller: _emailController,
            enabled: !_isSubmitting,
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
            fieldKey: const Key('registration-password'),
            label: 'パスワード',
            english: 'Password',
            hint: '6文字以上 · 6+ characters',
            controller: _passwordController,
            enabled: !_isSubmitting,
            obscure: true,
            validator: (value) {
              if (value == null || value.isEmpty) return 'パスワードを入力してください';
              if (value.length < 6) return 'パスワードは6文字以上で入力してください';
              return null;
            },
          ),
          const SizedBox(height: 10),
          AuthField(
            fieldKey: const Key('registration-confirmation'),
            label: 'パスワード（確認）',
            english: 'Confirm password',
            hint: 'もう一度入力 · Re-enter',
            enabled: !_isSubmitting,
            obscure: true,
            validator: (value) {
              if (value == null || value.isEmpty) return 'パスワード確認を入力してください';
              if (value != _passwordController.text) return 'パスワードが一致しません';
              return null;
            },
          ),
          const SizedBox(height: 14),
          const Spacer(),
          AuthPrimaryButton(
            key: const Key('auth-register-submit'),
            japanese: 'アカウントを作成',
            english: 'Create Account',
            onPressed: _isSubmitting ? null : _register,
            busy: _isSubmitting,
            busyLabel: '登録中...',
          ),
          const SizedBox(height: 14),
          AuthLink(
            'ログイン',
            prefix: 'アカウントをお持ちの方 · Have an account? ',
            key: const Key('auth-switch-login'),
            onPressed: _isSubmitting
                ? null
                : () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
          ),
        ],
      ),
    ),
  );
}
