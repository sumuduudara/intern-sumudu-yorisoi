import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../services/auth/firebase_auth_service.dart';
import 'welcome_screen.dart';
import '../widgets/home/analysis_loading_view.dart';
import '../widgets/home/feeling_input_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.logoutAction,
    this.displayName,
    this.previewOnly = false,
    this.analysisPreviewAction,
  });

  final Future<void> Function()? logoutAction;
  final String? displayName;
  final bool previewOnly;

  /// A controllable local UI preview for widget tests; never an AI result.
  final Future<void> Function(String text)? analysisPreviewAction;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSigningOut = false;
  final _feelingController = TextEditingController();
  final _feelingFocus = FocusNode();
  bool _isPreviewLoading = false;
  bool _canRetry = false;
  String? _inputError;
  int _previewRequest = 0;

  String? get _displayName {
    if (widget.displayName != null) return widget.displayName;
    if (widget.previewOnly || Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.currentUser?.displayName;
  }

  @override
  void dispose() {
    _previewRequest++;
    _feelingController.dispose();
    _feelingFocus.dispose();
    super.dispose();
  }

  void _cancelPreview() {
    _previewRequest++;
    setState(() => _isPreviewLoading = false);
  }

  Future<void> _submitFeeling() async {
    if (_isPreviewLoading || _isSigningOut) return;
    final text = _feelingController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _inputError = '今の気持ちを入力してください。';
        _canRetry = false;
      });
      _feelingFocus.requestFocus();
      return;
    }
    _feelingFocus.unfocus();
    final request = ++_previewRequest;
    setState(() {
      _isPreviewLoading = true;
      _inputError = null;
      _canRetry = false;
    });
    try {
      // Local delay only. No Gemini, STT, Firestore, or recommendation request.
      final action = widget.analysisPreviewAction;
      if (action == null) {
        await Future<void>.delayed(const Duration(seconds: 3));
      } else {
        await action(text);
      }
      if (!mounted || request != _previewRequest) return;
      setState(() => _isPreviewLoading = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('UIプレビュー'),
          content: const Text(
            '感情分析・おすすめ画面はまだ接続されていません。'
            '入力内容は送信していません。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('入力に戻る'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted || request != _previewRequest) return;
      setState(() {
        _isPreviewLoading = false;
        _inputError = 'プレビューの表示に失敗しました。もう一度お試しください。';
        _canRetry = true;
      });
    }
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('設定プレビュー'),
              const SizedBox(height: 12),
              const Text('設定画面全体は準備中です。'),
              if (widget.previewOnly)
                const Text('UIプレビューのためログアウトは利用できません。')
              else
                TextButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _logout();
                  },
                  child: const Text('ログアウト'),
                ),
            ],
          ),
        ),
      ),
    );
  }

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
      body: Stack(
        children: [
          if (_isPreviewLoading)
            AnalysisLoadingView(
              message: _feelingController.text.trim(),
              displayName: _displayName,
              onCancel: _cancelPreview,
            )
          else
            FeelingInputView(
              controller: _feelingController,
              focusNode: _feelingFocus,
              displayName: _displayName,
              onSubmit: _isSigningOut ? null : _submitFeeling,
              onMicrophone: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('音声入力は準備中です。テキストで入力してください。')),
              ),
              onSettings: _isSigningOut ? null : _showSettings,
              onChanged: (_) {
                if (_inputError != null) {
                  setState(() {
                    _inputError = null;
                    _canRetry = false;
                  });
                }
              },
              error: _inputError,
              canRetry: _canRetry,
            ),
          if (_isSigningOut)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xCCFBF5EF),
                child: Center(child: Text('ログアウト中...')),
              ),
            ),
        ],
      ),
    );
  }
}
