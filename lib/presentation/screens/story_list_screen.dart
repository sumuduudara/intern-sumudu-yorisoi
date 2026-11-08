import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../domain/emotions/emotion_analysis_result.dart';
import '../../domain/stories/story.dart';
import '../../domain/stories/story_playback_request.dart';
import '../../repositories/firestore_story_repository.dart';
import '../../repositories/story_repository.dart';
import '../controllers/story_list_controller.dart';
import '../widgets/stories/story_list_view.dart';
import 'story_selection_handoff_screen.dart';

typedef OpenStory = Future<void> Function(
  BuildContext context,
  StoryPlaybackRequest request,
);

class StoryListScreen extends StatefulWidget {
  const StoryListScreen({
    super.key,
    required this.result,
    this.repository,
    this.openStory,
  });
  final EmotionAnalysisResult result;
  final StoryRepository? repository;
  final OpenStory? openStory;

  @override
  State<StoryListScreen> createState() => _StoryListScreenState();
}

class _StoryListScreenState extends State<StoryListScreen> {
  late final StoryListController _controller;
  bool _opening = false;
  String? _selectionError;

  @override
  void initState() {
    super.initState();
    // Resolve Firebase lazily inside load's try/catch; tests inject repository.
    _controller = StoryListController(
      result: widget.result,
      findForAnalysis: (result) =>
          (widget.repository ??
                  FirestoreStoryRepository.firebase(
                    firestore: FirebaseFirestore.instance,
                  ))
              .findForAnalysis(result),
    );
    _controller.load();
  }

  Future<void> _select(Story story) async {
    if (_opening ||
        _controller.loading ||
        !_controller.stories.contains(story)) {
      return;
    }
    setState(() {
      _opening = true;
      _selectionError = null;
    });
    try {
      final request = StoryPlaybackRequest.fromStory(story);
      final open = widget.openStory;
      if (open != null) {
        await open(context, request);
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            settings: RouteSettings(
              name: '/story-selection',
              arguments: request,
            ),
            builder: (_) => StorySelectionHandoffScreen(request: request),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectionError = 'お話を開けませんでした。もう一度お試しください。';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _opening = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => StoryListView(
      result: widget.result,
      stories: _controller.stories,
      loading: _controller.loading,
      error: _controller.error,
      opening: _opening,
      selectionError: _selectionError,
      onRetry: _controller.load,
      onSelect: _select,
      onBack: () => Navigator.of(context).pop(),
    ),
  );
}
