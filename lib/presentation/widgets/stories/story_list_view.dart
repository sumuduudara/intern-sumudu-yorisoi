import 'package:flutter/material.dart';

import '../../../domain/emotions/emotion_analysis_result.dart';
import '../../../domain/stories/story.dart';
import '../../../domain/stories/story_draft.dart';
import '../../../repositories/story_repository.dart';
import '../home/home_design_frame.dart';

// Reserve enough line height for bundled Japanese glyphs, including wrapping
// and accessibility text scaling. Never constrain message text to a fixed box.
TextStyle _storyTextStyle(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w400,
}) => homeTextStyle(size, color, weight: weight, height: 1.5);

/// Temporary composition, not a reproduction of a Pet Radio playback frame.
/// The official Story List design can replace this widget without changing I/O.
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

  static const ink = Color(0xFF5F4A45);
  static const pink = Color(0xFFBF5D67);

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
    return Scaffold(
      backgroundColor: homePaper,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  '${homeAssetPath}bg_home.png',
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            key: const Key('story-list-back'),
                            tooltip: '入力に戻る',
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back, color: ink),
                          ),
                          const SizedBox(width: 8),
                          Image.asset(
                            '${homeAssetPath}yorisoi_logo.png',
                            width: 90,
                            height: 38,
                            semanticLabel: 'Yorisoi',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '今の気持ちに寄り添うお話',
                        style: _storyTextStyle(
                          25,
                          ink,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose a story, at your own pace.',
                        style: _storyTextStyle(13, ink),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '仮UI・正式なFigmaデザイン待ち',
                        key: const Key('temporary-story-list'),
                        style: _storyTextStyle(12, pink),
                      ),
                      const SizedBox(height: 20),
                      _ReadabilityPanel(
                        key: const Key('story-emotion-panel'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Image.asset(
                                  'assets/images/pets/${pet.name}.png',
                                  width: 80,
                                  height: 96,
                                  fit: BoxFit.contain,
                                  semanticLabel: '${pet.japanese}のお話',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              result.main.japanese,
                              key: const Key('main-emotion'),
                              style: _storyTextStyle(
                                24,
                                pink,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${pet.japanese}が語るお話から、聴きたいものを選んでね。',
                              key: const Key('story-pet-description'),
                              style: _storyTextStyle(15, ink),
                            ),
                            if (result.secondary != null) ...[
                              const SizedBox(height: 16),
                              Text('もう一つの気持ち', style: _storyTextStyle(13, ink)),
                              const SizedBox(height: 4),
                              Text(
                                result.secondary!.japanese,
                                key: const Key('secondary-emotion'),
                                style: _storyTextStyle(13, ink),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              'AIの推定であり、医療上の診断ではありません。',
                              key: const Key('story-emotion-disclaimer'),
                              style: _storyTextStyle(12, ink),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (loading || error != null || stories.isEmpty)
                        _ReadabilityPanel(
                          key: const Key('story-state-panel'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (loading) ...[
                                const Center(
                                  child: CircularProgressIndicator(
                                    key: Key('story-list-loading'),
                                    color: pink,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '公開済みのお話を探しています…',
                                  style: _storyTextStyle(15, ink),
                                ),
                              ] else if (error != null) ...[
                                Text(
                                  _errorMessage(error!),
                                  key: const Key('story-list-error'),
                                  style: _storyTextStyle(15, ink),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: onRetry,
                                  child: Text(
                                    '再試行',
                                    style: _storyTextStyle(16, pink),
                                  ),
                                ),
                              ] else if (stories.isEmpty) ...[
                                Text(
                                  '公開済みのお話は現在準備中です。',
                                  key: const Key('story-list-empty'),
                                  style: _storyTextStyle(18, ink),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '未承認のお話は表示しません。入力に戻るか、後でもう一度確認してください。',
                                  key: const Key('story-list-empty-detail'),
                                  style: _storyTextStyle(14, ink),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: onRetry,
                                  child: Text(
                                    'もう一度確認',
                                    style: _storyTextStyle(16, pink),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      else ...[
                        if (stories.length == 1)
                          Text(
                            '現在ご案内できるお話は1件です。',
                            style: _storyTextStyle(14, ink),
                          ),
                        if (stories.length == 1) const SizedBox(height: 12),
                        for (final story in stories)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _StoryCard(
                              story: story,
                              enabled: !opening,
                              onSelect: () => onSelect(story),
                            ),
                          ),
                      ],
                      if (selectionError != null)
                        Text(
                          selectionError!,
                          key: const Key('story-selection-error'),
                          style: _storyTextStyle(14, pink),
                        ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: onBack,
                        child: Text('入力に戻る', style: _storyTextStyle(16, pink)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadabilityPanel extends StatelessWidget {
  const _ReadabilityPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.enabled,
    required this.onSelect,
  });
  final Story story;
  final bool enabled;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('story-card-${story.storyId}'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              'assets/images/pets/${story.petType.name}.png',
              width: 64,
              height: 84,
              fit: BoxFit.contain,
              semanticLabel: story.petType.japanese,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    style: _storyTextStyle(
                      18,
                      StoryListView.ink,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    story.description,
                    style: _storyTextStyle(14, StoryListView.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    story.duration == null
                        ? '再生時間未登録'
                        : '${story.duration!.round() ~/ 60}分${(story.duration!.round() % 60).toString().padLeft(2, '0')}秒',
                    style: _storyTextStyle(13, StoryListView.ink),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFFD97C84), StoryListView.pink],
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              key: ValueKey('select-${story.storyId}'),
              onPressed: enabled ? onSelect : null,
              child: Text(
                'このお話を選ぶ',
                semanticsLabel: '${story.title}を選ぶ',
                style: _storyTextStyle(
                  16,
                  Colors.white,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
