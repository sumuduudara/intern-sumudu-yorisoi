import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../services/auth/firebase_auth_service.dart';
import '../../services/voice/speech_to_text_service.dart';
import '../controllers/voice_input_controller.dart';
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
    this.voiceRecognition,
  });

  final Future<void> Function()? logoutAction;
  final String? displayName;
  final bool previewOnly;
  final VoiceRecognition? voiceRecognition;

  /// A controllable local UI preview for widget tests; never an AI result.
  final Future<void> Function(String text)? analysisPreviewAction;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isSigningOut = false;
  final _feelingController = TextEditingController();
  final _feelingFocus = FocusNode();
  bool _isPreviewLoading = false;
  bool _canRetry = false;
  String? _inputError;
  int _previewRequest = 0;
  late final VoiceInputController _voice;

  @override
  void initState() {
    super.initState();
    _voice = VoiceInputController(
      textController: _feelingController,
      recognition: widget.voiceRecognition ?? SpeechToTextService.instance,
    )..addListener(_voiceChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void _voiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // "inactive" can be the OS permission dialog, not a background recording.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_voice.cancel());
    }
  }

  String? get _displayName {
    if (widget.displayName != null) return widget.displayName;
    if (widget.previewOnly || Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.currentUser?.displayName;
  }

  @override
  void dispose() {
    _previewRequest++;
    WidgetsBinding.instance.removeObserver(this);
    _voice.removeListener(_voiceChanged);
    _voice.dispose();
    _feelingController.dispose();
    _feelingFocus.dispose();
    super.dispose();
  }

  void _cancelPreview() {
    _previewRequest++;
    setState(() => _isPreviewLoading = false);
  }

  Future<void> _submitFeeling() async {
    if (_isPreviewLoading || _isSigningOut || _voice.busy) return;
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
      // Local analysis preview only. Never sends input to Gemini or Firestore.
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

  Future<void> _showSettings() async {
    await _voice.cancel();
    if (!mounted) return;
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
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) unawaited(_voice.cancel());
      },
      child: Scaffold(
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
                onSubmit: _isSigningOut || _voice.busy ? null : _submitFeeling,
                onMicrophone: _isSigningOut || !_voice.canTap
                    ? null
                    : () {
                        _feelingFocus.unfocus();
                        setState(() {
                          _inputError = null;
                          _canRetry = false;
                        });
                        unawaited(_voice.toggle());
                      },
                voiceHint: _voice.hint,
                voiceListening: _voice.phase == VoiceInputPhase.listening,
                voiceBusy: _voice.busy,
                onSettings: _isSigningOut ? null : _showSettings,
                onChanged: (_) {
                  _voice.clearError();
                  if (_inputError != null) {
                    setState(() {
                      _inputError = null;
                      _canRetry = false;
                    });
                  }
                },
                error: _voice.error ?? _inputError,
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
      ),
    );
  }
}
