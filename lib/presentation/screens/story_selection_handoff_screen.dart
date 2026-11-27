import 'package:flutter/material.dart';

import '../../domain/stories/story_playback_request.dart';
import '../widgets/home/home_design_frame.dart';

/// Honest boundary for the future player, not a mock Pet Radio screen.
class StorySelectionHandoffScreen extends StatelessWidget {
  const StorySelectionHandoffScreen({super.key, required this.request});
  final StoryPlaybackRequest request;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: homePaper,
    appBar: AppBar(title: const Text('選んだお話')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '選択したお話: ${request.storyId}',
              key: const Key('selected-story-id'),
              style: homeTextStyle(18, const Color(0xFF5F4A45)),
            ),
            const SizedBox(height: 16),
            Text(
              '再生画面は準備中です。音声は再生していません。',
              textAlign: TextAlign.center,
              style: homeTextStyle(16, const Color(0xFF5F4A45)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('お話一覧に戻る'),
            ),
          ],
        ),
      ),
    ),
  );
}
