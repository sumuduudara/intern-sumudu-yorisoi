import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/emotions/emotion_analysis_result.dart';
import '../../../domain/stories/story.dart';
import '../../../domain/stories/story_draft.dart';
import '../../../repositories/story_repository.dart';
import 'story_choice_card.dart';
import 'story_list_design.dart';

/// Official frames 109:25/125/225/325 and Empty State 109:425.
/// Presentation only; eligibility, repository and navigation stay unchanged.
class StoryListView extends StatelessWidget {
  const StoryListView({
    super.key,
    required this.result,
    required this.stories,
    required this.loading,
    required this.error,
    required this.opening,
    required this.selectionError,
    required this.onRetry,
    required this.onSelect,
    required this.onBack,
  });
  final EmotionAnalysisResult result;
  final List<Story> stories;
  final bool loading;
  final StoryDataError? error;
  final bool opening;
  final String? selectionError;
  final VoidCallback onRetry;
  final ValueChanged<Story> onSelect;
  final VoidCallback onBack;

  String _errorMessage(StoryDataError error) => switch (error) {
    StoryDataError.network => '通信できませんでした。接続を確認して、再試行してください。',
    StoryDataError.permissionDenied => 'お話を取得できませんでした。ログイン状態と利用設定を確認してください。',
    StoryDataError.invalidCatalog ||
    StoryDataError.configuration => 'お話の配信設定を確認できませんでした。しばらくしてから再試行してください。',
    StoryDataError.audioCheckFailed ||
    StoryDataError.readFailed => 'お話を読み込めませんでした。もう一度お試しください。',
  };

  @override
  Widget build(BuildContext context) {
    final pet = StorySelection.approvedPets[result.main]!;
    final design = StoryPetDesign.forPet(pet);
    final empty = !loading && error == null && stories.isEmpty;
    final inset = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: storyPaper,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  design.background,
                  key: const Key('story-list-background'),
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x8CFBF5EF),
                        Color(0x4DFBF5EF),
                        Color(0xB3FBF5EF),
                        Color(0xD9FBF5EF),
                      ],
                      stops: [0, .30, .42, 1],
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                key: const Key('story-list-scroll'),
                padding: EdgeInsets.only(
                  top: math.max(54, inset.top + 12),
                  bottom: math.max(32, inset.bottom + 16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x24966E63),
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: IconButton(
                              key: const Key('story-list-back'),
                              tooltip: '入力に戻る',
                              onPressed: onBack,
                              icon: storyIcon('back', 21),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .8),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  storyIcon(
                                    'paw_chip',
                                    14,
                                    color: design.chipColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      design.chip,
                                      style: storyText(
                                        12,
                                        color: design.chipColor,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PetGreeting(design: design, empty: empty),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _Message(
                        design: design,
                        empty: empty,
                        sad: result.main == EmotionCategory.sad,
                      ),
                    ),
                    if (empty) ...[
                      const SizedBox(height: 25),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: _EmptyCard(),
                      ),
                      const SizedBox(height: 62),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: StoryGradientButton(
                          height: 56,
                          onPressed: onBack,
                          child: Text.rich(
                            TextSpan(
                              text: 'ホームに戻る',
                              children: [
                                TextSpan(
                                  text: ' · Back to Home',
                                  style: storyText(11, color: Colors.white),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: storyText(
                              16,
                              color: Colors.white,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('story-list-retry'),
                        onPressed: onRetry,
                        child: Text(
                          'もう一度さがす · Try again',
                          style: storyText(
                            13,
                            color: storyPink,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ] else if (loading || error != null) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Container(
                          key: const Key('story-state-panel'),
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .9),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Semantics(
                            liveRegion: true,
                            child: Column(
                              children: [
                                if (loading) ...[
                                  const CircularProgressIndicator(
                                    key: Key('story-list-loading'),
                                    color: storyPink,
                                  ),
                                  const SizedBox(height: 16),
                                  Text('公開済みのお話を探しています…', style: storyText(15)),
                                ] else ...[
                                  Text(
                                    _errorMessage(error!),
                                    key: const Key('story-list-error'),
                                    style: storyText(15),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: onRetry,
                                    child: Text(
                                      '再試行',
                                      style: storyText(16, color: storyPink),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'おはなしを えらんでね',
                              style: storyText(16, weight: FontWeight.w900),
                            ),
                            Text(
                              'Choose a story · ${stories.length}',
                              style: storyText(11, color: storyMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),
                      for (final story in stories)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                          child: StoryChoiceCard(
                            story: story,
                            enabled: !opening,
                            onSelect: () => onSelect(story),
                          ),
                        ),
                    ],
                    if (selectionError != null)
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            selectionError!,
                            key: const Key('story-selection-error'),
                            style: storyText(14, color: storyPink),
                          ),
                        ),
                      ),
                    // Preserve the real main/secondary result and non-diagnostic notice
                    // below the reference composition; never alter the assigned pet.
                    const SizedBox(height: 80),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '主な気持ち',
                            style: storyText(11, color: storyMuted),
                          ),
                          Text(
                            result.main.japanese,
                            key: const Key('main-emotion'),
                            style: storyText(13),
                          ),
                          if (result.secondary != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'もう一つの気持ち',
                              style: storyText(11, color: storyMuted),
                            ),
                            Text(
                              result.secondary!.japanese,
                              key: const Key('secondary-emotion'),
                              style: storyText(13),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            'AIの推定であり、医療上の診断ではありません。',
                            key: const Key('story-emotion-disclaimer'),
                            style: storyText(11, color: storyMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetGreeting extends StatelessWidget {
  const _PetGreeting({required this.design, required this.empty});
  final StoryPetDesign design;
  final bool empty;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = math.min(1.0, constraints.maxWidth / 390);
      final bounds = design.petBounds;
      return Padding(
        key: const Key('story-pet-greeting'),
        padding: const EdgeInsets.only(left: 18, right: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150 * scale,
              height: 150,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: (bounds.left - 18) * scale,
                    top: bounds.top - 100,
                    width: bounds.width * scale,
                    height: bounds.height,
                    child: Image.asset(
                      design.artwork,
                      fit: BoxFit.contain,
                      semanticLabel: '${design.pet.japanese}のお話',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 28),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -12,
                      top: 32,
                      child: storyIcon('bubble_tail', 16),
                    ),
                    Container(
                      key: const Key('story-speech-bubble'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F966E63),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            empty ? 'いまは、おはなしの\n準備中だよ' : design.heading,
                            style: storyText(
                              18,
                              weight: FontWeight.w900,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            empty ? 'No stories yet.' : design.english,
                            style: storyText(
                              11,
                              color: storyMuted,
                              height: 16 / 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.design,
    required this.empty,
    required this.sad,
  });
  final StoryPetDesign design;
  final bool empty;
  final bool sad;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        empty
            ? '新しいおはなしが届くまで、少しだけ待っててね。また会いに来てくれるとうれしいな。'
            : sad
            ? '今日は少し悲しい気持ちなんだね。ねこと一緒に、ゆっくり聴こう。'
            : design.message,
        key: const Key('story-pet-description'),
        style: storyText(
          13,
          color: storyBody,
          weight: FontWeight.w500,
          height: 1.65,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        empty
            ? 'New stories are on the way. Please check back soon.'
            : sad
            ? 'Feeling a little sad today. Let’s listen together, slowly.'
            : design.messageEnglish,
        style: storyText(11, color: storyMuted),
      ),
    ],
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();
  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: const _DashedBorder(),
    child: Container(
      key: const Key('story-state-panel'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 29),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Image.asset(
            '${storyAssetPath}empty_moon.png',
            width: 64,
            height: 64,
            excludeFromSemantics: true,
          ),
          const SizedBox(height: 14),
          Text(
            'おはなし準備中',
            key: const Key('story-list-empty'),
            style: storyText(16, weight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text('Coming soon', style: storyText(11, color: storyMuted)),
          const SizedBox(height: 8),
          Text(
            'いま公開されているおはなしはありません。',
            key: const Key('story-list-empty-detail'),
            textAlign: TextAlign.center,
            style: storyText(12, color: storyBody),
          ),
          const SizedBox(height: 6),
          Text(
            'There are no published stories right now.',
            textAlign: TextAlign.center,
            style: storyText(11, color: storyMuted),
          ),
          const SizedBox(height: 14),
          Text(
            'おやすみ中…　zzz',
            style: storyText(
              15,
              color: const Color(0xFFD97C84),
            ).copyWith(fontFamily: 'Yomogi'),
          ),
        ],
      ),
    ),
  );
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)),
      );
    final paint = Paint()
      ..color = const Color(0xFFF2B3B6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in path.computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += 18) {
        canvas.drawPath(
          metric.extractPath(offset, math.min(offset + 10, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => false;
}
