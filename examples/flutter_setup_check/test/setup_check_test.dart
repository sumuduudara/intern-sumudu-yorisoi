import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi_flutter_setup_check/main.dart';
import 'package:yorisoi_flutter_setup_check/packages.dart';

void main() {
  test('all eight selected SDKs have distinct compiled references', () {
    expect(packageChecks.map((p) => p.name).toSet().length, 8);
    expect(packageChecks.map((p) => p.sdkType).toSet().length, 8);
  });
  testWidgets('Japanese text is preserved by local input preview', (
    tester,
  ) async {
    await tester.pumpWidget(const SetupCheckApp());
    await tester.enterText(find.byType(TextField), '  今日は寂しいです。  ');
    await tester.tap(find.text('入力を確認'));
    await tester.pump();
    expect(find.text('入力確認: 今日は寂しいです。'), findsOneWidget);
  });
  testWidgets('blank input gives guidance instead of a false result', (
    tester,
  ) async {
    await tester.pumpWidget(const SetupCheckApp());
    await tester.tap(find.text('入力を確認'));
    await tester.pump();
    expect(find.text('テキストを入力してください'), findsOneWidget);
  });
}
