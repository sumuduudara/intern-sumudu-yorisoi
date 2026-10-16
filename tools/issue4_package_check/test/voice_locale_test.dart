import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi_package_check/voice_test.dart';

void main() {
  test(
    'web attempts Japanese even when browser language is empty or English',
    () {
      expect(japaneseLocale([], isWeb: true), 'ja-JP');
      expect(japaneseLocale(['en-US'], isWeb: true), 'ja-JP');
    },
  );
  test('native uses installed Japanese locale and rejects missing locale', () {
    expect(japaneseLocale(['en_US', 'ja_JP'], isWeb: false), 'ja_JP');
    expect(japaneseLocale(['ja-JP'], isWeb: false), 'ja-JP');
    expect(japaneseLocale(['en-US'], isWeb: false), isNull);
    expect(japaneseLocale(['jargon'], isWeb: false), isNull);
  });
}
