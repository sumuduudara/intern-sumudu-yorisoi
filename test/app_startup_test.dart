import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/app/yorisoi_app.dart';
import 'package:yorisoi/presentation/screens/login_screen.dart';

void main() {
  testWidgets('app shell renders independently of Firebase initialization', (
    tester,
  ) async {
    await tester.pumpWidget(const YorisoiApp());
    await tester.pumpAndSettle();

    expect(find.byType(YorisoiApp), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('おかえりなさい'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'small screen with large text remains scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: YorisoiApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        MediaQuery.textScalerOf(tester.element(find.byType(LoginScreen)))
            .scale(16),
        32,
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('auth-submit')));
      expect(find.byKey(const Key('auth-submit')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
