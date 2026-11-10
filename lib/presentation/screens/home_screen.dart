import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../services/auth/firebase_auth_service.dart';
import '../../services/emotion/emotion_analysis_service.dart';
import '../../services/emotion/firebase_emotion_model.dart';
import '../../services/voice/speech_to_text_service.dart';
import '../controllers/voice_input_controller.dart';
import 'welcome_screen.dart';
import 'emotion_analysis_result_screen.dart';
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
    this.emotionAnalyzer,
  }) : assert(analysisPreviewAction == null || previewOnly);

  final Future<void> Function()? logoutAction;
  final String? displayName;
  final bool previewOnly;
  final VoiceRecognition? voiceRecognition;
  final EmotionAnalyzer? emotionAnalyzer;

  /// Only used in explicit previewOnly mode, never in the production flow.
  final Future<void> Function(String text)? analysisPreviewAction;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isSigningOut = false;
  final _feelingController = TextEditingController();
  final _feelingFocus = FocusNode();
  bool _isAnalyzing = false;
  bool _canRetry = false;
  String? _inputError;
  int _analysisRequest = 0;
  late final VoiceInputController _voice;
  late final EmotionAnalyzer _emotionAnalyzer;

  @override
  void initState() {
    super.initState();
    _emotionAnalyzer =
        widget.emotionAnalyzer ??
        EmotionAnalysisService(model: FirebaseEmotionModel());
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
    _analysisRequest++;
    WidgetsBinding.instance.removeObserver(this);
    _voice.removeListener(_voiceChanged);
    _voice.dispose();
    _feelingController.dispose();
    _feelingFocus.dispose();
    super.dispose();
  }

  void _cancelAnalysis() {
    _analysisRequest++;
    setState(() {
      _isAnalyzing = false;
      if (!widget.previewOnly) {
        _inputError = '結果の表示を中止しました。送信済みの通信は取り消せません。';
        _canRetry = false;
      }
    });
  }

  Future<void> _submitFeeling() async {
    if (_isAnalyzing || _isSigningOut || _voice.busy) return;
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
    final request = ++_analysisRequest;
    setState(() {
      _isAnalyzing = true;
      _inputError = null;
      _canRetry = false;
    });
    try {
      if (widget.previewOnly) {
        await _runVisualPreview(text, request);
        return;
      }
      final result = await _emotionAnalyzer.analyze(text);
      if (!mounted || request != _analysisRequest) return;
      setState(() => _isAnalyzing = false);
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => EmotionAnalysisResultScreen(
            result: result,
            displayName: _displayName,
          ),
        ),
      );
    } catch (error) {
      if (!mounted || request != _analysisRequest) return;
      setState(() {
        _isAnalyzing = false;
        _inputError = widget.previewOnly
            ? 'プレビューの表示に失敗しました。もう一度お試しください。'
            : (error is EmotionAnalysisException
                  ? error.japaneseMessage
                  : const EmotionAnalysisException(
                      EmotionAnalysisError.apiFailure,
                    ).japaneseMessage);
        _canRetry = true;
      });
    }
  }

  Future<void> _runVisualPreview(String text, int request) async {
    final action = widget.analysisPreviewAction;
    if (action == null) {
      await Future<void>.delayed(const Duration(seconds: 3));
    } else {
      await action(text);
    }
    if (!mounted || request != _analysisRequest) return;
    setState(() => _isAnalyzing = false);
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
      canPop: !_isAnalyzing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          unawaited(_voice.cancel());
        } else if (_isAnalyzing) {
          _cancelAnalysis();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            if (_isAnalyzing)
              AnalysisLoadingView(
                message: _feelingController.text.trim(),
                displayName: _displayName,
                onCancel: _cancelAnalysis,
                previewOnly: widget.previewOnly,
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
