import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi_package_check/main.dart';
import 'package:yorisoi_package_check/local_firebase.dart';

void main() {
  testWidgets('emotion app displays before a request', (tester) async {
    await tester.pumpWidget(const EmotionTestApp());
    expect(find.text('Test Emotion'), findsOneWidget);
    expect(find.text('Not tested yet'), findsOneWidget);
  });
  test('missing local config fails without exposing its values', () {
    expect(localFirebaseOptions, throwsStateError);
  });
}
