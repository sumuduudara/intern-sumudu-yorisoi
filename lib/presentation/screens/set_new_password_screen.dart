import 'package:flutter/material.dart';

import '../../services/auth/firebase_auth_service.dart';
import '../widgets/auth/auth_design.dart';
import 'forgot_password_screen.dart';
import 'password_recovery_support.dart';
import 'password_updated_screen.dart';

class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({
    super.key,
    required this.code,
    this.verifyCode,
    this.confirmReset,
  });
  final String code;
  final Future<String> Function(String code)? verifyCode;
  final Future<void> Function({required String code, required String password})?
  confirmReset;
  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late Future<String> _verification;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _verification = _verify();
  }

  Future<String> _verify() async {
    if (widget.code.isEmpty) throw StateError('Missing reset code');
    return await (widget.verifyCode ??
        FirebaseAuthService().verifyPasswordResetCode)(widget.code);
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool get _longEnough => _password.text.length >= 8;
  bool get _mixed =>
      RegExp('[A-Za-z]').hasMatch(_password.text) &&
      RegExp('[0-9]').hasMatch(_password.text);
  bool get _matches =>
      _password.text.isNotEmpty && _password.text == _confirmation.text;

  void _newLink() {
    if (!_busy) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
      );
    }
  }

  Future<void> _update() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await (widget.confirmReset ?? FirebaseAuthService().confirmPasswordReset)(
        code: widget.code,
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PasswordUpdatedScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) setState(() => _error = recoveryError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _rule(String label, bool met) => Semantics(
    checked: met,
    child: Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
      decoration: BoxDecoration(
        color: met ? const Color(0xFFFBE1E1) : const Color(0xFFFDF9F6),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: met ? const Color(0xFFD97C84) : const Color(0xFFD9CEC8),
            ),
            child: authIcon('check_small.svg', 12),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: authText(
                12,
                color: const Color(0xFFA24C56),
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AuthDesignPage(
    cardTop: 300,
    cardPaddingTop: 24,
    header: [
      Positioned.fill(
        child: RecoveryHeader(step: 3, onBack: _busy ? null : _newLink),
      ),
      Positioned(
        left: 127,
        top: 112,
        width: 137,
        height: 180,
        child: authImage('cat.png', label: '猫'),
      ),
      Positioned(
        left: 34,
        top: 150,
        child: Transform.rotate(
          angle: -.10472,
          child: Text(
            'あたらしい\nはじまり ♡',
            textAlign: TextAlign.center,
            style: authText(
              15,
              color: const Color(0xFFB86E74),
              font: 'Yomogi',
              height: 1.5,
            ),
          ),
        ),
      ),
    ],
    child: FutureBuilder<String>(
      future: _verification,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Column(
            children: [
              const AuthTitle('新しいパスワード', 'Set a new password'),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              Text('リンクを確認しています…', style: authText(14)),
            ],
          );
        }
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthTitle('新しいパスワード', 'Set a new password'),
              const SizedBox(height: 14),
              Text(
                widget.code.isEmpty
                    ? '再設定メール内の有効なリンクから開いてください。'
                    : recoveryError(snapshot.error!),
                style: authText(14, color: const Color(0xFF9A3544)),
              ),
              const SizedBox(height: 14),
              AuthLink(
                'リンクの確認を再試行',
                onPressed: () {
                  final verification = _verify();
                  setState(() {
                    _verification = verification;
                  });
                },
              ),
              const Spacer(),
              AuthPrimaryButton(
                japanese: 'リンクをもう一度送る',
                english: 'Send reset link',
                onPressed: _newLink,
              ),
            ],
          );
        }
        return Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthTitle('新しいパスワード', 'Set a new password'),
              const SizedBox(height: 14),
              AuthField(
                label: '新しいパスワード',
                english: 'New password',
                hint: '••••••••••',
                controller: _password,
                obscure: true,
                enabled: !_busy,
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '新しいパスワードを入力してください';
                  }
                  if (!_longEnough) return 'パスワードは8文字以上で入力してください';
                  if (!_mixed) return '英字と数字を組み合わせてください';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              AuthField(
                label: 'もう一度入力',
                english: 'Confirm password',
                hint: '••••••••••',
                controller: _confirmation,
                obscure: true,
                enabled: !_busy,
                onChanged: (_) => setState(() {}),
                validator: (value) => value == null || value.isEmpty
                    ? 'パスワード確認を入力してください'
                    : !_matches
                    ? 'パスワードが一致しません'
                    : null,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _rule('8文字以上 · 8+ chars', _longEnough),
                  _rule('英字と数字 · Letters & numbers', _mixed),
                  _rule('一致 · Match', _matches),
                ],
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
                japanese: 'パスワードを更新',
                english: 'Update password',
                onPressed: _busy ? null : _update,
                busy: _busy,
                busyLabel: '更新中...',
              ),
            ],
          ),
        );
      },
    ),
  );
}
