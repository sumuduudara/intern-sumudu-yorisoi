import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/app/theme/app_theme.dart';
import 'package:yorisoi/presentation/screens/home_screen.dart';
import 'package:yorisoi/presentation/screens/login_screen.dart';
import 'package:yorisoi/presentation/screens/emotion_analysis_result_screen.dart';
import 'package:yorisoi/presentation/screens/welcome_screen.dart';
import 'package:yorisoi/presentation/widgets/home/analysis_loading_view.dart';
import 'package:yorisoi/services/emotion/emotion_analysis_service.dart';
import 'package:yorisoi/services/emotion/firebase_emotion_model.dart';

import 'support/fake_voice_recognition.dart';

void main() {
  testWidgets(
    'login -> editable Japanese voice -> SDK adapter/parser -> result -> Home -> logout',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final voice = FakeVoiceRecognition();
      final pending = Completer<GenerateContentResponse>();
      var requests = 0;
      var logouts = 0;
      final service = EmotionAnalysisService(
        model: FirebaseEmotionModel(
          generateContent: (contents) {
            requests++;
            final text = contents.single.parts.single as TextPart;
            expect(jsonDecode(text.text), {'user_text': '今日はひとりで寂しいです'});
            return pending.future;
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: LoginScreen(
            loginAction: ({required email, required password}) async {
              expect(email, 'student@example.com');
            },
            homeBuilder: (_) => HomeScreen(
              voiceRecognition: voice,
              emotionAnalyzer: service,
              logoutAction: () async {
                logouts++;
              },
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'student@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'test-only-value',
      );
      await tester.tap(find.byKey(const Key('auth-login-submit')));
      await tester.pumpAndSettle();
      expect(
        Navigator.of(tester.element(find.byType(HomeScreen))).canPop(),
        isFalse,
      );
      await tester.tap(find.byKey(const Key('home-microphone')));
      await tester.pumpAndSettle();
      voice.result!('今日はひとりで寂しい', true);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('feeling-input')),
        '今日はひとりで寂しいです',
      );
      await tester.ensureVisible(find.byKey(const Key('share-feeling')));
      await tester.tap(find.byKey(const Key('share-feeling')));
      await tester.pump();
      expect(find.byType(AnalysisLoadingView), findsOneWidget);
      expect(requests, 1);
      pending.complete(
        GenerateContentResponse([
          Candidate(
            Content.text('{"main_emotion":"寂しい","secondary_emotion":null}'),
            null,
            null,
            FinishReason.stop,
            null,
          ),
        ], null),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EmotionAnalysisResultScreen), findsOneWidget);
      expect(find.text('寂しい'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('emotion-result-back')));
      await tester.tap(find.byKey(const Key('emotion-result-back')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('feeling-input')))
            .controller!
            .text,
        '今日はひとりで寂しいです',
      );
      await tester.tap(find.byKey(const Key('home-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ログアウト'));
      await tester.pumpAndSettle();
      expect(logouts, 1);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('はじめまして'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    },
  );
}
