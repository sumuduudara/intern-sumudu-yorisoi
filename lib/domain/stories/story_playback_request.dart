import 'story.dart';

/// Navigation contract only. This does not start audio or generate content.
class StoryPlaybackRequest {
  const StoryPlaybackRequest({required this.storyId, required this.revision});
  factory StoryPlaybackRequest.fromStory(Story story) =>
      StoryPlaybackRequest(storyId: story.storyId, revision: story.revision);
  final String storyId;
  final int revision;
}
