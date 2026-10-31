import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth/firebase_auth_service.dart';
import '../widgets/auth/auth_design.dart';
import 'login_screen.dart';
import 'password_recovery_support.dart';

class CheckEmailScreen extends StatefulWidget {
  const CheckEmailScreen({
    super.key,
    required this.email,
    this.sendReset,
    this.openEmail,
  });
  final String email;
  final Future<void> Function({required String email})? sendReset;
  final Future<bool> Function()? openEmail;
  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  bool _busy = false;
  bool _openingEmail = false;
  bool _cooldown = true;
  Timer? _timer;
  String? _message;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _cooldown = true;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 60), () {
      if (mounted) setState(() => _cooldown = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _login() {
    if (!_busy) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _resend() async {
    if (_busy || _cooldown) return;
    setState(() => _busy = true);
    try {
      final action =
          widget.sendReset ?? FirebaseAuthService().sendPasswordResetEmail;
      try {
        await action(email: widget.email);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'user-not-found') rethrow;
      }
      if (!mounted) return;
      setState(() {
        _message = resetEmailFeedback;
        _startCooldown();
      });
    } catch (e) {
      if (mounted) setState(() => _message = recoveryError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEmail() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _openingEmail = true;
    });
    try {
      final opened =
          await (widget.openEmail?.call() ??
              launchUrl(
                Uri(scheme: 'mailto'),
                mode: LaunchMode.externalApplication,
              ));
      if (mounted) {
        setState(
          () => _message = opened
              ? 'メールアプリの受信トレイをご確認ください。'
              : 'メールアプリを開けませんでした。ご利用のメールアプリやWebメールで受信トレイをご確認ください。',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'メールアプリを開けませんでした。ご利用のメールアプリやWebメールで受信トレイをご確認ください。',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _openingEmail = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AuthDesignPage(
    cardTop: 332,
    header: [
      Positioned.fill(
        child: RecoveryHeader(step: 2, onBack: _busy ? null : _login),
      ),
      Positioned(
        left: 103,
        top: 118,
        width: 170,
        height: 196,
        child: authImage('dog.png', label: '犬'),
      ),
      Positioned(
        left: 262,
        top: 136,
        child: Transform.rotate(
          angle: -.139626,
          child: authIcon('envelope.svg', 48, height: 36),
        ),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthTitle('メールを送りました', 'Check your email'),
        const SizedBox(height: 14),
        Text(
          '${widget.email} 宛に、パスワード再設定のリンクを送りました。',
          style: authText(14, color: const Color(0xFF5F4A45), height: 1.7),
        ),
        const SizedBox(height: 4),
        Text(
          'We sent a password reset link to your email.',
          style: authText(12, color: authMuted, height: 1.5),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF1F0),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              authIcon('paw_tip.svg', 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '届かないときは、迷惑メールフォルダも見てみてね',
                      style: authText(
                        14,
                        color: const Color(0xFFA24C56),
                        font: 'Yomogi',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Can’t find it? Check your spam folder.',
                      style: authText(11, color: authMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Do not reveal whether the address exists, or claim confirmed delivery.
        const SizedBox(height: 8),
        Text('該当するアカウントがある場合に送信されます。', style: authText(11, color: authMuted)),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(_message!, style: authText(12, color: authPink)),
            ),
          ),
        const SizedBox(height: 14), const Spacer(),
        AuthPrimaryButton(
          japanese: 'メールアプリを開く',
          english: 'Open email app',
          onPressed: _busy ? null : _openEmail,
        ),
        const SizedBox(height: 14),
        AuthLink(
          _busy
              ? (_openingEmail ? 'メールアプリを開いています…' : '送信中...')
              : _cooldown
              ? '再送まで少しお待ちください · Resend'
              : 'メールが届かない？ · Didn’t get it? 再送する · Resend',
          key: const Key('auth-resend'),
          onPressed: _busy || _cooldown ? null : _resend,
        ),
        const SizedBox(height: 14),
        AuthLink('ログインに戻る · Back to Login', onPressed: _busy ? null : _login),
      ],
    ),
  );
}
