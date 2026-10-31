import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/app/yorisoi_app.dart';
import 'package:yorisoi/presentation/screens/emotion_analysis_result_screen.dart';
import 'package:yorisoi/presentation/screens/home_screen.dart';
import 'package:yorisoi/presentation/screens/login_screen.dart';
import 'package:yorisoi/presentation/screens/welcome_screen.dart';
import 'package:yorisoi/services/emotion/emotion_analysis_service.dart';

void main() {
  Future<void> checkLiveHome(WidgetTester tester) async {
    final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
    expect(home.previewOnly, isFalse);
    expect(home.analysisPreviewAction, isNull);
    expect(
      home.emotionAnalyzer,
      isNull,
    ); // Uses the real default Firebase adapter.
    expect(find.text('今日はどんな気分ですか？'), findsOneWidget);
    expect(find.textContaining('UIプレビュー'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('feeling-input')),
      '今日はひとりで寂しいです',
    );
    await tester.ensureVisible(find.byKey(const Key('share-feeling')));
    await tester.tap(find.byKey(const Key('share-feeling')));
    await tester.pumpAndSettle();
    // Firebase is deliberately not initialized in this widget test. The real
    // adapter must report configuration failure, never fabricate a result.
    expect(
      find.text(
        const EmotionAnalysisException(EmotionAnalysisError.configuration)
            .japaneseMessage,
      ),
      findsOneWidget,
    );
    expect(find.byType(EmotionAnalysisResultScreen), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('feeling-input')))
          .controller!
          .text,
      '今日はひとりで寂しいです',
    );
  }

  testWidgets('main app restored session routes to live Home, never preview', (
    tester,
  ) async {
    await tester.pumpWidget(YorisoiApp(restoreSession: () async => true));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsNothing);
    await checkLiveHome(tester);
  });

  testWidgets('login from main app clears auth history and opens live Home', (
    tester,
  ) async {
    await tester.pumpWidget(YorisoiApp(restoreSession: () async => false));
    await tester.pumpAndSettle();
    // Replace only authentication with a fake; keep production navigation and
    // Home's default service. No real account is created or signed in.
    Navigator.of(tester.element(find.byType(WelcomeScreen))).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          loginAction: ({required email, required password}) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'test@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'test-only-value');
    await tester.ensureVisible(find.byKey(const Key('auth-login-submit')));
    await tester.tap(find.byKey(const Key('auth-login-submit')));
    await tester.pumpAndSettle();
    expect(
      Navigator.of(tester.element(find.byType(HomeScreen))).canPop(),
      isFalse,
    );
    await checkLiveHome(tester);
  });
}
