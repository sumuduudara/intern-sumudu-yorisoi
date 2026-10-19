import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth/firebase_auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

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

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() => _isSubmitting = true);
    try {
      final action = widget.registrationAction;
      if (action != null) {
        await action(email: email, password: password);
      } else {
        await FirebaseAuthService().register(email: email, password: password);
      }
      _showMessage('登録が完了しました。');

      if (action == null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規登録')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Yorisoi',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 16),

                    const Text('アカウントを作成', textAlign: TextAlign.center),
                    const SizedBox(height: 32),

                    // Email
                    TextFormField(
                      enabled: !_isSubmitting,
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'メールアドレス',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final email = value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'メールアドレスを入力してください';
                        }

                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return '正しいメールアドレスを入力してください';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      enabled: !_isSubmitting,
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'パスワード',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'パスワードを入力してください';
                        }
                        if (value.length < 6) {
                          return 'パスワードは6文字以上で入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    TextFormField(
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'パスワード確認',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'パスワード確認を入力してください';
                        }

                        if (value != _passwordController.text) {
                          return 'パスワードが一致しません';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Register Button
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _register,
                      child: _isSubmitting
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('登録中...'),
                              ],
                            )
                          : const Text('登録する'),
                    ),
                    const SizedBox(height: 16),

                    // Replace this route to avoid stacking login/register loops.
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                      child: const Text('すでにアカウントをお持ちの方はこちら'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
