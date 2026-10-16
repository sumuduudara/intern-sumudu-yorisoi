import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// Web Speech exposes the selected language, not a supported-language catalogue.
String? japaneseLocale(Iterable<String> locales, {required bool isWeb}) {
  if (isWeb) {
    return 'ja-JP';
  }
  for (final locale in locales) {
    if (locale.toLowerCase().replaceAll('_', '-').startsWith('ja-') ||
        locale.toLowerCase() == 'ja') {
      return locale;
    }
  }
  return null;
}

void main() {
  runApp(const MaterialApp(home: VoiceTestPage()));
}

class VoiceTestPage extends StatefulWidget {
  const VoiceTestPage({super.key});

  @override
  State<VoiceTestPage> createState() => _VoiceTestPageState();
}

class _VoiceTestPageState extends State<VoiceTestPage> {
  final stt.SpeechToText speech = stt.SpeechToText();
  String status = 'Ready';
  String words = 'No speech recognized yet';

  Future<void> startListening() async {
    try {
      setState(() => status = 'Initializing...');

      final ready = await speech.initialize(
        onStatus: (value) {
          if (mounted) setState(() => status = value);
        },
        onError: (error) {
          if (mounted) setState(() => status = error.errorMsg);
        },
        options: [stt.SpeechToText.androidNoBluetooth],
      );

      if (!ready) {
        if (mounted) {
          setState(() => status = 'Speech recognition unavailable');
        }
        return;
      }

      final locales = await speech.locales();
      final localeId = japaneseLocale(
        locales.map((locale) => locale.localeId),
        isWeb: kIsWeb,
      );

      if (localeId == null) {
        if (mounted) {
          setState(() => status = 'Japanese language unavailable');
        }
        return;
      }

      if (mounted) {
        setState(() {
          words = 'Listening...';
          status = 'Starting Japanese recognition';
        });
      }

      await speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() => words = result.recognizedWords);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: localeId,
          partialResults: true,
          listenFor: const Duration(seconds: 20),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => status = 'Error: $error');
    }
  }

  @override
  void dispose() {
    speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yorisoi Voice Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Japanese Speech-to-Text Test'),
              const SizedBox(height: 15),
              const Text('Say: 今日はとても寂しいです。'),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: speech.isListening ? null : startListening,
                child: const Text('Start Japanese Voice'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await speech.stop();
                  if (mounted) setState(() => status = 'Stopped');
                },
                child: const Text('Stop'),
              ),
              const SizedBox(height: 25),
              Text('Status: $status'),
              const SizedBox(height: 15),
              SelectableText('Recognized: $words'),
            ],
          ),
        ),
      ),
    );
  }
}
