@TestOn('browser')
@Tags(['experimental'])
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  test('bundled MP3 decodes and playback completes', () async {
    final data = await rootBundle
        .load('assets/audio/test.mp3')
        .timeout(const Duration(seconds: 10));
    // ignore: avoid_print
    print('Asset loaded: ${data.lengthInBytes} bytes');
    expect(data.lengthInBytes, greaterThan(100));
    final player = AudioPlayer();
    try {
      final duration = await player
          .setAsset('assets/audio/test.mp3')
          .timeout(const Duration(seconds: 10));
      // ignore: avoid_print
      print('MP3 decoded: $duration');
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, greaterThan(0));
      await player.play().timeout(const Duration(seconds: 30));
      expect(player.processingState, ProcessingState.completed);
      expect(player.position.inMilliseconds, greaterThan(0));
    } finally {
      await player.dispose();
    }
  });
}
