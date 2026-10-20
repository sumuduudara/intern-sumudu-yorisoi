import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'welcome_screen.dart';

/// Checks the saved session once at startup, before displaying either screen.
class SessionStartupScreen extends StatefulWidget {
  const SessionStartupScreen({super.key, required this.restoreSession});

  final Future<bool> Function() restoreSession;

  @override
  State<SessionStartupScreen> createState() => _SessionStartupScreenState();
}

class _SessionStartupScreenState extends State<SessionStartupScreen> {
  late Future<bool> _session;

  @override
  void initState() {
    super.initState();
    _session = Future<bool>.sync(widget.restoreSession);
  }

  void _retry() {
    final session = Future<bool>.sync(widget.restoreSession);
    setState(() {
      _session = session;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('ログイン状態を確認中...'),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ログイン状態を確認できませんでした。接続を確認してください。',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _retry,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return snapshot.data == true
            ? const HomeScreen()
            : const WelcomeScreen();
      },
    );
  }
}
