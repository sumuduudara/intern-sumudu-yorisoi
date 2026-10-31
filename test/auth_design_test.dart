import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/presentation/screens/registration_screen.dart';
import 'package:yorisoi/presentation/screens/login_screen.dart';
import 'package:yorisoi/presentation/screens/forgot_password_screen.dart';
import 'package:yorisoi/presentation/screens/check_email_screen.dart';
import 'package:yorisoi/presentation/screens/set_new_password_screen.dart';
import 'package:yorisoi/presentation/screens/password_updated_screen.dart';

void main() {
  setUpAll(() async {
    final zen = FontLoader('Zen Maru Gothic');
    for (final weight in ['Regular', 'Medium', 'Bold', 'Black']) {
      zen.addFont(
        rootBundle.load(
          'assets/fonts/zen_maru_gothic/ZenMaruGothic-$weight.ttf',
        ),
      );
    }
    await zen.load();
    await (FontLoader('Yomogi')
          ..addFont(rootBundle.load('assets/fonts/yomogi/Yomogi-Regular.ttf')))
        .load();
  });
  final screens = <String, (Widget, double)>{
    'registration': (const RegistrationScreen(), 286),
    'login': (const LoginScreen(), 384),
    'forgot': (const ForgotPasswordScreen(), 332),
    'email': (const CheckEmailScreen(email: 'student@example.com'), 332),
    'new_password': (
      SetNewPasswordScreen(
        code: 'fake-test-code',
        verifyCode: (_) async => 'student@example.com',
      ),
      300,
    ),
    'updated': (const PasswordUpdatedScreen(), 440),
  };
  for (final entry in screens.entries) {
    testWidgets('${entry.key} uses original Figma card geometry and bundled art', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(key: boundary, child: entry.value.$1),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final image in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(
            image.image,
            tester.element(find.byKey(boundary)),
          );
        }
      });
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(const Key('auth-form-card')));
      expect(rect.left, 14);
      expect(rect.top, entry.value.$2);
      expect(rect.width, 362);
      expect(rect.height, closeTo(824 - entry.value.$2, 1));
      expect(tester.takeException(), isNull);
      final images = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => (image.image as AssetImage).assetName);
      expect(
        images,
        contains(
          'assets/images/auth/${entry.key == 'registration' ? 'bg_registration.png' : 'bg_auth.png'}',
        ),
      );
      // Optional local QA artifacts, clearly fixture-rendered rather than live
      // Firebase evidence. Nothing is written during normal test runs.
      if (const bool.fromEnvironment('CAPTURE_AUTH_DESIGNS')) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          try {
            final png = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File('/tmp/yorisoi_auth_${entry.key}.png')
                .writeAsBytes(png.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
    });

    testWidgets('${entry.key} remains usable at 320x480 and twice-sized text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: entry.value.$1,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
