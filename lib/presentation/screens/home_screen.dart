import 'package:flutter/material.dart';

import '../../services/auth/firebase_auth_service.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.logoutAction});

  final Future<void> Function()? logoutAction;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSigningOut = false;

  Future<void> _logout() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    var openedWelcome = false;
    try {
      final action = widget.logoutAction;
      if (action != null) {
        await action();
      } else {
        await FirebaseAuthService().signOut();
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
      openedWelcome = true;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログアウトできませんでした。もう一度お試しください。')),
      );
    } finally {
      if (mounted && !openedWelcome) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yorisoi'),
        actions: [
          TextButton(
            onPressed: _isSigningOut ? null : _logout,
            child: Text(_isSigningOut ? 'ログアウト中...' : 'ログアウト'),
          ),
        ],
      ),
      body: const Center(child: Text('今日はどんな気分ですか？')),
    );
  }
}
