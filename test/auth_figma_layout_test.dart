import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/presentation/screens/login_screen.dart';
import 'package:yorisoi/presentation/screens/registration_screen.dart';

void main() {
  for (final signup in [false, true]) {
    testWidgets(
      '${signup ? 'signup' : 'login'} uses original auth assets and reference card origin',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: signup ? const RegistrationScreen() : const LoginScreen(),
          ),
        );
        await tester.pumpAndSettle();
        final card = tester.getRect(find.byKey(const Key('auth-form-card')));
        expect(card.left, 14);
        expect(card.width, 362);
        expect(card.top, signup ? 286 : 384);
        final sources = tester
            .widgetList<Image>(find.byType(Image))
            .map((i) => (i.image as AssetImage).assetName)
            .toList();
        expect(
          sources,
          contains('assets/images/auth/bg_${signup ? 'signup' : 'login'}.jpg'),
        );
        expect(find.byKey(const Key('auth-brand')), findsOneWidget);
        expect(sources, contains('assets/images/auth/pets_group.png'));
        expect(sources.any((s) => s.contains('/home/')), isFalse);
      },
    );

    for (final scale in [1.0, 2.0]) {
      for (final keyboard in [0.0, 280.0]) {
        testWidgets(
          '${signup ? 'signup' : 'login'} scrolls at 320px scale $scale keyboard $keyboard',
          (tester) async {
            tester.view.physicalSize = const Size(320, 600);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    viewInsets: EdgeInsets.only(bottom: keyboard),
                  ),
                  child: child!,
                ),
                home: signup ? const RegistrationScreen() : const LoginScreen(),
              ),
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.byKey(const Key('auth-submit')));
            await tester.pumpAndSettle();
            expect(
              tester
                  .getRect(find.byKey(const Key('auth-submit')))
                  .overlaps(Offset.zero & tester.view.physicalSize),
              isTrue,
            );
            await tester.ensureVisible(find.byKey(const Key('auth-switch')));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
