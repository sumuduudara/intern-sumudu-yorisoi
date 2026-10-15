import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() => runApp(const MaterialApp(home: AudioTestPage()));

class AudioTestPage extends StatefulWidget {
  const AudioTestPage({super.key});
  @override
  State<AudioTestPage> createState() => _AudioTestPageState();
}

class _AudioTestPageState extends State<AudioTestPage> {
  final player = AudioPlayer();
  String status = 'Ready';
  bool busy = false;
  StreamSubscription<PlayerState>? stateSubscription;

  @override
  void initState() {
    super.initState();
    stateSubscription = player.playerStateStream.listen((state) {
      if (mounted && state.processingState == ProcessingState.completed) {
        setState(() { status = 'Completed'; busy = false; });
      }
    });
  }

  Future<void> play() async {
    setState(() {
      busy = true;
      status = 'Loading asset';
    });
    try {
      await player.setAsset('assets/audio/test.mp3');
      if (!mounted) return;
      setState(() => status = 'Playing');
      await player.play();
      if (mounted && player.processingState == ProcessingState.completed) {
        setState(() => status = 'Completed');
      }
    } catch (_) {
      if (mounted) setState(() => status = 'Playback failed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    stateSubscription?.cancel();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Local MP3 Test')),
    body: Column(
      children: [
        ElevatedButton(
          onPressed: busy ? null : play,
          child: const Text('Play MP3'),
        ),
        ElevatedButton(
          onPressed: () async {
            await player.stop();
            if (mounted) setState(() => status = 'Stopped');
          },
          child: const Text('Stop'),
        ),
        Text(status),
      ],
    ),
  );
}
