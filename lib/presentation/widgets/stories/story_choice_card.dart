import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/stories/story.dart';
import 'story_list_design.dart';

/// Figma Story Card 109:2. All content comes from the eligible repository record.
/// The current metadata has no English title; do not invent a translation.
class StoryChoiceCard extends StatelessWidget {
  const StoryChoiceCard({
    super.key,
    required this.story,
    required this.enabled,
    required this.onSelect,
  });

  final Story story;
  final bool enabled;
  final VoidCallback onSelect;

  String get _duration {
    final duration = story.duration;
    if (duration == null) return '再生時間未登録';
    final seconds = duration.round();
    final minutes = seconds ~/ 60;
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    final estimate = math.max(1, minutes);
    return '約$estimate分 · $minutes:$remainder';
  }

  @override
  Widget build(BuildContext context) {
    final design = StoryPetDesign.forPet(story.petType);
    return Container(
      key: ValueKey('story-card-${story.storyId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F966E63),
            blurRadius: 13,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 59),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: design.tileColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: storyIcon('paw_card', 26, color: design.pawColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.title,
                        style: storyText(15, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        story.description,
                        style: storyText(12, color: storyBody),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Wrap rather than truncate Japanese or overflow at large text sizes.
          LayoutBuilder(
            builder: (context, constraints) {
              final scaled = MediaQuery.textScalerOf(context).scale(13);
              final stackActions = constraints.maxWidth < 290 || scaled > 17;
              final duration = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F1EC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    storyIcon('clock', 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _duration,
                        style: storyText(
                          12,
                          color: storyMuted,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              final button = StoryGradientButton(
                buttonKey: ValueKey('select-${story.storyId}'),
                onPressed: enabled ? onSelect : null,
                semanticLabel: '${story.title}を選ぶ。音声は自動再生しません。',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    storyIcon('play', 12),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '聴く · Listen',
                        style: storyText(
                          13,
                          color: Colors.white,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (stackActions) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    duration,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: button),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: duration),
                  const SizedBox(width: 8),
                  Flexible(child: button),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
