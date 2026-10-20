import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/main.dart' as entrypoint;
import 'package:yorisoi/app/yorisoi_app.dart';

void main() {
  testWidgets(
    'real entrypoint renders the app without Firebase configuration',
    (tester) async {
      entrypoint.main();
      await tester.pumpAndSettle();

      expect(find.byType(YorisoiApp), findsOneWidget);
      expect(find.text('Yorisoi'), findsOneWidget);
      expect(find.text('気持ちに、そっと寄り添う。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
        MediaQuery.textScalerOf(tester.element(find.text('Yorisoi'))).scale(16),
        32,
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.text('あなたのペースで、ひと息。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
