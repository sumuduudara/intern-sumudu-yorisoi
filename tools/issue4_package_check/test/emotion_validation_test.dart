import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi_package_check/emotion_test.dart';

void main() {
  test('accepts only the eight emotion codes', () {
    for (final code in emotionCodes) {
      expect(validateEmotion(' $code\n'), code);
    }
    for (final bad in [null, '', 'lonely because...', 'unknown']) {
      expect(() => validateEmotion(bad), throwsFormatException);
    }
  });
}
