import 'package:flutter/material.dart';

import '../widgets/auth/auth_design.dart';
import 'login_screen.dart';

class PasswordUpdatedScreen extends StatelessWidget {
  const PasswordUpdatedScreen({super.key});
  @override
  Widget build(BuildContext context) => AuthDesignPage(
    cardTop: 440,
    cardPaddingTop: 52,
    header: [
      Positioned(
        left: 30,
        top: 150,
        width: 330,
        height: 230,
        child: authIcon('glow.svg', 330, height: 230),
      ),
      Positioned(left: 46, top: 150, child: authIcon('sparkle_left.svg', 20)),
      Positioned(left: 322, top: 320, child: authIcon('sparkle_right.svg', 18)),
      Positioned(
        left: 35,
        top: 170,
        width: 320,
        height: 187,
        child: authImage('pets_group.png', label: '猫、犬、うさぎ、イルカ'),
      ),
    ],
    overlays: [
      Positioned(
        left: 159,
        top: 404,
        width: 72,
        height: 72,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFD97C84), authPink],
            ),
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59BF5C66),
                offset: Offset(0, 10),
                blurRadius: 22,
              ),
            ],
          ),
          child: authIcon('check_success.svg', 30),
        ),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthTitle('パスワードを変更しました', 'Password updated', center: true),
        const SizedBox(height: 8),
        Text(
          '新しいパスワードでログインしてね。',
          textAlign: TextAlign.center,
          style: authText(14, color: const Color(0xFF5F4A45), height: 1.7),
        ),
        const SizedBox(height: 4),
        Text(
          'Log in with your new password.',
          textAlign: TextAlign.center,
          style: authText(12, color: authMuted, height: 1.5),
        ),
        const SizedBox(height: 8),
        Transform.rotate(
          angle: -.05236,
          child: Text(
            'みんなで待ってるよ ♡',
            textAlign: TextAlign.center,
            style: authText(16, color: const Color(0xFFB86E74), font: 'Yomogi'),
          ),
        ),
        const SizedBox(height: 8),
        const Spacer(),
        AuthPrimaryButton(
          japanese: 'ログインへ',
          english: 'Go to Login',
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          ),
        ),
      ],
    ),
  );
}
