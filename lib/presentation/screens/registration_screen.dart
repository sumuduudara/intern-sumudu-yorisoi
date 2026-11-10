import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth/firebase_auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../widgets/auth/auth_design.dart';

typedef RegistrationAction = Future<void> Function({
  required String email,
  required String password,
  String? nickname,
});

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    this.registrationAction,
    this.nicknameUpdateAction,
  });

  /// Tests can supply an action without connecting to Firebase.
  final RegistrationAction? registrationAction;
  final Future<void> Function(String? expectedUserId, String nickname)?
  nicknameUpdateAction;

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
  bool _accountCreated = false;
  bool _finished = false;
  RegistrationProfileException? _profileFailure;
  String? _profileMessage;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isSubmitting ||
        _accountCreated ||
        !_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() => _isSubmitting = true);
    try {
      final action = widget.registrationAction;
      if (action != null) {
        await action(
          email: email,
          password: password,
          nickname: _nicknameController.text.trim(),
        );
      } else {
        await FirebaseAuthService().register(
          email: email,
          password: password,
          nickname: _nicknameController.text.trim(),
        );
      }
      if (!mounted) return;
      _accountCreated = true;
      _finishRegistration();
    } on RegistrationProfileException catch (error) {
      if (!mounted) return;
      setState(() {
        _accountCreated = true;
        _profileFailure = error;
        _profileMessage =
            'アカウントは作成済みですが、ニックネームを保存できませんでした。名前だけ再保存するか、名前なしで続けられます。';
      });
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _finishRegistration({bool withoutNickname = false}) {
    if (!mounted) return;
    setState(() {
      _finished = true;
      _profileFailure = null;
    });
    _showMessage(
      withoutNickname ? 'アカウントを作成しました。ニックネームの保存は未確認です。' : '登録が完了しました。',
    );
    if (widget.registrationAction == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _retryNickname() async {
    final failure = _profileFailure;
    if (_isSubmitting || _finished || failure == null) return;
    if (_nicknameController.text.trim().isEmpty) {
      setState(() {
        _profileMessage = '名前を入力して再保存するか、「名前なしで続ける」を選んでください。';
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      final action = widget.nicknameUpdateAction;
      if (action != null) {
        await action(failure.userId, _nicknameController.text.trim());
      } else {
        await FirebaseAuthService().retryRegistrationNickname(
          expectedUserId: failure.userId,
          nickname: _nicknameController.text,
        );
      }
      if (mounted) _finishRegistration();
    } catch (_) {
      if (mounted) {
        setState(() {
          _profileMessage = '名前を保存できませんでした。接続・ログイン状態を確認するか、名前なしで続けてください。';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AuthDesignFrame(
    signUp: true,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeading(signUp: true),
          const SizedBox(height: 14),
          if (_profileFailure != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                _profileMessage!,
                key: const Key('registration-profile-warning'),
                style: authText(13, color: authPink),
              ),
            ),
            const SizedBox(height: 14),
          ],
          AuthField(
            fieldKey: const Key('auth-nickname'),
            label: 'ニックネーム（任意）',
            english: 'Nickname (optional)',
            hint: 'Sumudu',
            icon: 'icon_user',
            enabled: !_isSubmitting && !_finished,
            controller: _nicknameController,
            autofillHints: const [AutofillHints.nickname],
          ),
          const SizedBox(height: 10),
          AuthField(
            fieldKey: const Key('auth-email'),
            label: 'メールアドレス',
            english: 'Email',
            hint: 'you@example.com',
            icon: 'icon_email',
            enabled: !_isSubmitting && !_accountCreated,
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
            hint: '6文字以上 · 6+ characters',
            icon: 'icon_lock',
            enabled: !_isSubmitting && !_accountCreated,
            controller: _passwordController,
            obscure: true,
            autofillHints: const [AutofillHints.newPassword],
            validator: (value) {
              if (value == null || value.isEmpty) return 'パスワードを入力してください';
              if (value.length < 6) return 'パスワードは6文字以上で入力してください';
              return null;
            },
          ),
          const SizedBox(height: 10),
          AuthField(
            fieldKey: const Key('auth-confirmation'),
            label: 'パスワード（確認）',
            english: 'Confirm password',
            hint: 'もう一度入力 · Re-enter',
            icon: 'icon_lock',
            enabled: !_isSubmitting && !_accountCreated,
            obscure: true,
            validator: (value) {
              if (value == null || value.isEmpty) return 'パスワード確認を入力してください';
              if (value != _passwordController.text) return 'パスワードが一致しません';
              return null;
            },
          ),
          const SizedBox(height: 29),
          AuthPrimaryButton(
            label: _profileFailure == null ? 'アカウントを作成' : 'ニックネームを再保存',
            english: _profileFailure == null ? 'Create Account' : '',
            busyLabel: _accountCreated ? '保存中...' : '登録中...',
            busy: _isSubmitting,
            onPressed: _isSubmitting || _finished
                ? null
                : _profileFailure != null
                ? _retryNickname
                : _register,
          ),
          if (_profileFailure != null)
            TextButton(
              key: const Key('registration-without-nickname'),
              onPressed: _isSubmitting
                  ? null
                  : () => _finishRegistration(withoutNickname: true),
              child: Text('名前なしで続ける', style: authText(14, color: authPink)),
            ),
          const SizedBox(height: 14),
          AuthSwitchLink(
            signUp: true,
            onPressed: _isSubmitting || _accountCreated
                ? null
                : () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
          ),
        ],
      ),
    ),
  );
}
