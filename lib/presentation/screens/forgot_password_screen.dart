import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth/firebase_auth_service.dart';
import '../widgets/auth/auth_design.dart';
import 'check_email_screen.dart';
import 'password_recovery_support.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
    this.sendReset,
  });
  final String initialEmail;
  final Future<void> Function({required String email})? sendReset;
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _back() {
    if (_busy) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) return;
    final email = _email.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final action =
          widget.sendReset ?? FirebaseAuthService().sendPasswordResetEmail;
      try {
        await action(email: email);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'user-not-found') rethrow;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              CheckEmailScreen(email: email, sendReset: widget.sendReset),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = recoveryError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthDesignPage(
    cardTop: 332,
    header: [
      Positioned.fill(
        child: RecoveryHeader(step: 1, onBack: _busy ? null : _back),
      ),
      Positioned(
        left: 135,
        top: 112,
        width: 120,
        height: 210,
        child: authImage('rabbit.png', label: 'うさぎ'),
      ),
      Positioned(
        left: 244,
        top: 150,
        child: Transform.rotate(
          angle: .10472,
          child: Text(
            'だいじょうぶ、\nいっしょに直そう ♡',
            textAlign: TextAlign.center,
            style: authText(
              15,
              color: const Color(0xFFB05F78),
              font: 'Yomogi',
              height: 1.5,
            ),
          ),
        ),
      ),
    ],
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthTitle('パスワードをお忘れですか？', 'Forgot your password?'),
          const SizedBox(height: 14),
          Text(
            '登録したメールアドレスを入力してね。\nパスワード再設定のリンクを送ります。',
            style: authText(14, color: const Color(0xFF5F4A45), height: 1.7),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your email and we’ll send you a link to reset your password.',
            style: authText(12, color: authMuted, height: 1.5),
          ),
          const SizedBox(height: 14),
          AuthField(
            label: 'メールアドレス',
            english: 'Email',
            hint: 'you@example.com',
            icon: 'email.svg',
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            validator: validateRecoveryEmail,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: authText(13, color: const Color(0xFF9A3544)),
                ),
              ),
            ),
          const SizedBox(height: 14),
          const Spacer(),
          AuthPrimaryButton(
            key: const Key('auth-send-reset'),
            japanese: 'リンクを送る',
            english: 'Send reset link',
            onPressed: _busy ? null : _send,
            busy: _busy,
            busyLabel: '送信中...',
          ),
          const SizedBox(height: 14),
          AuthLink('ログインに戻る · Back to Login', onPressed: _busy ? null : _back),
        ],
      ),
    ),
  );
}
