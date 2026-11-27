// Developer read-only entrypoint. No story generation or publication writes.
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'domain/emotions/emotion_analysis_result.dart';
import 'firebase_options.dart';
import 'repositories/firestore_story_repository.dart';
import 'repositories/story_repository.dart';
import 'services/auth/firebase_auth_service.dart';
import 'presentation/screens/login_screen.dart';

// Developer-only evidence for terminal verification without browser control.
// Never pass credentials, user identifiers, story content or raw SDK errors.
void _report(Map<String, Object?> evidence) =>
    debugPrint('STORY_FIRESTORE_CHECK ${jsonEncode(evidence)}');

// Observes the actual server response without replacing SDK reads or rules.
class _ObservedFirebaseSource extends FirebaseStorySource {
  _ObservedFirebaseSource(super.firestore);
  Map<String, dynamic>? library;
  bool libraryReadCompleted = false;
  int storyQueries = 0;

  @override
  Future<Map<String, dynamic>?> readLibrary() async {
    library = await super.readLibrary();
    libraryReadCompleted = true;
    return library;
  }

  @override
  Future<List<FirestoreStoryRecord>> readPage(
    EmotionCategory emotion, {
    FirestoreStoryRecord? after,
  }) {
    storyQueries++;
    return super.readPage(emotion, after: after);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAuth.instance.authStateChanges().first;
    runApp(const MaterialApp(home: StoryFirestoreDemo()));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Firebaseの初期化に失敗しました。既存のlocal設定を確認してください。')),
        ),
      ),
    );
  }
}

class StoryFirestoreDemo extends StatefulWidget {
  const StoryFirestoreDemo({super.key, this.authStates, this.verifySession});

  // Test seams only. The normal entrypoint uses the real Firebase SDK/service.
  final Stream<bool>? authStates;
  final Future<bool> Function()? verifySession;

  @override
  State<StoryFirestoreDemo> createState() => _ReadDemoState();
}

class _ReadDemoState extends State<StoryFirestoreDemo> {
  late final StreamSubscription<bool> _authSubscription;
  bool? _signedIn;
  bool _busy = false;
  String _message =
      'Firebase Authをサーバーで確認し、libraryを実Firestoreから読みます。draftは正常な非公開状態です。';

  @override
  void initState() {
    super.initState();
    final states =
        widget.authStates ??
        FirebaseAuth.instance.authStateChanges().map((user) => user != null);
    _authSubscription = states.listen(
      (signedIn) {
        if (mounted) setState(() => _signedIn = signedIn);
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _signedIn = null;
            _message = 'ログイン状態の取得に失敗しました。接続確認ボタンから再試行できます。';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _read() async {
    if (_busy) return;
    var authServerVerified = false;
    _ObservedFirebaseSource? observedSource;
    setState(() => _busy = true);
    try {
      // Validate the restored user/token with Firebase Auth; never display them.
      // Do not interpret a transient currentUser == null as a lost session.
      final verify =
          widget.verifySession ?? FirebaseAuthService().restoreSession;
      final validSession = await verify().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() => _signedIn = validSession);
      if (!validSession) {
        _report({
          'stage': 'auth',
          'status': 'login_required',
          'firestoreRead': false,
        });
        setState(() => _message = '有効なログイン状態がありません。既存のログイン画面からログインしてください。');
        return;
      }
      authServerVerified = true;
      // Real SDK, server-only; no mocks, fallback, fabricated stories or audio.
      final source = _ObservedFirebaseSource(FirebaseFirestore.instance);
      observedSource = source;
      final repository = FirestoreStoryRepository(
        source: source,
        audioAvailable: bundledStoryAudio(rootBundle),
      );
      final result = await repository.findByEmotion(EmotionCategory.happy);
      if (!mounted) return;
      final library = source.library!; // Repository has validated these fields.
      _report({
        'stage': 'complete',
        'authServerVerified': true,
        'librarySource': 'server',
        'libraryPath': 'storyLibraries/current',
        'publicationStatus': library['publicationStatus'],
        'language': library['language'],
        'schemaVersion': library['schemaVersion'],
        'storyQueries': source.storyQueries,
        'storyCount': result.length,
        'outcome': library['publicationStatus'] == 'draft'
            ? 'draft_expected_empty'
            : 'published_library_read',
      });
      final evidence =
          'Firebase Auth：サーバー確認済み\n'
          'Firestore：Source.serverでstoryLibraries/currentを読込済み\n'
          'publicationStatus: ${library['publicationStatus']}\n'
          'language: ${library['language']}\n'
          'schemaVersion: ${library['schemaVersion']}\n'
          'stories query回数: ${source.storyQueries}\n';
      setState(
        () => _message =
            evidence +
            (library['publicationStatus'] == 'draft'
                ? '接続成功。libraryはdraftのため非公開です。stories検索をせず0件を返しました（正常）。'
                : result.isEmpty
                ? '表示可能なHappyの物語は0件です。音声同梱・公開metadataを確認してください。'
                : '${result.length}件\n${result.map((s) => '${s.storyId} / ${s.title} / ${s.audioPath}').join('\n')}'),
      );
    } on FirebaseAuthException catch (e) {
      _report({
        'stage': 'auth',
        'status': e.code == 'network-request-failed'
            ? 'network_error'
            : 'verification_failed',
        'firestoreRead': false,
      });
      if (!mounted) return;
      setState(
        () => _message = e.code == 'network-request-failed'
            ? 'Firebase Authの通信エラーです。Firestore読込前に停止しました。'
            : 'Firebase Authの確認に失敗しました。ログイン状態を確認してください。',
      );
    } on TimeoutException {
      _report({'stage': 'auth', 'status': 'timeout', 'firestoreRead': false});
      if (!mounted) return;
      setState(() => _message = 'Firebase Auth確認が時間切れです。Firestore読込前に停止しました。');
    } on StoryCatalogException catch (e) {
      final source = observedSource!;
      final diagnostics = {
        'authServerVerified': authServerVerified,
        'libraryServerReadCompleted': source.libraryReadCompleted,
        'projectId': source.firestore.app.options.projectId,
        'databaseId': source.firestore.databaseId,
        'libraryPath': 'storyLibraries/current',
        'storyQueries': source.storyQueries,
        ...storyLibraryDiagnostics(source.library),
      };
      _report({'stage': 'metadata', 'status': e.code.name, ...diagnostics});
      if (!mounted) return;
      setState(
        () => _message =
            '公開catalogのmetadata検証で停止しました。\n'
            'Auth確認とFirestore読込の成否は以下の通りです。\n'
            '${const JsonEncoder.withIndent('  ').convert(diagnostics)}\n'
            'draft自体は有効です。公開状態は変更しないでください。',
      );
    } on StoryDataException catch (e) {
      _report({
        'stage': 'firestore',
        'status': e.code.name,
        'authServerVerified': authServerVerified,
        'libraryServerReadCompleted':
            observedSource?.libraryReadCompleted ?? false,
      });
      if (!mounted) return;
      setState(
        () => _message = switch (e.code) {
          StoryDataError.permissionDenied =>
            '権限エラー：ログイン・Firestore rulesを確認してください。',
          StoryDataError.network => '通信エラー：接続を確認して再試行してください。',
          StoryDataError.configuration =>
            '設定エラー：database/API/indexの設定を確認してください。',
          StoryDataError.invalidCatalog => '公開catalogのmetadataが未登録、または不正です。',
          _ => '読込に失敗しました。公開metadataとasset登録を確認してください。',
        },
      );
    } catch (_) {
      _report({'stage': 'check', 'status': 'incomplete'});
      if (!mounted) return;
      setState(() => _message = '接続確認を完了できませんでした。成功として扱いません。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Issue #11 Firestore読込デモ')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('開発者用。音声再生・Story List画面ではありません。'),
          const SizedBox(height: 16),
          Text(switch (_signedIn) {
            true => 'ログイン状態：保存済みセッションあり（サーバー確認は接続確認ボタン）',
            false => 'ログイン状態：未ログイン。同じブラウザーとURLを使用してください。',
            null => 'ログイン状態：復元待ち、または未確認。接続確認から再試行できます。',
          }),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy || _signedIn != false
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                  ),
            child: Text(_signedIn == true ? 'ログイン済み（再ログイン不要）' : '既存のログイン画面を開く'),
          ),
          const Text('ログイン後にHomeが表示されたら、このページを再読み込みして接続確認してください。'),
          const SizedBox(height: 16),
          Text(_busy ? '接続確認：実行中（認証・通信の完了待ち）' : '接続確認：待機中（確認ボタンを操作できます）'),
          ElevatedButton(
            onPressed: _busy ? null : _read,
            child: Text(_busy ? '確認中…' : '認証と実Firestore接続を確認'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(child: SelectableText(_message)),
          ),
        ],
      ),
    ),
  );
}
