import '../emotions/emotion_analysis_result.dart';
import 'story_draft.dart';

/// Published-data metadata, separate from the generation/editing draft model.
/// Parsing never changes approval, activates content or generates audio.
class Story {
  Story._(this._data, this.emotion, this.petType, this.createdAt);

  final Map<String, Object?> _data;
  final EmotionCategory emotion;
  final StoryPet petType;
  final DateTime createdAt;

  String get storyId => _data['storyId']! as String;
  int get revision => _data['revision']! as int;
  String get title => _data['title']! as String;
  String get description => _data['description']! as String;
  String get storyText => _data['storyText']! as String;
  String? get audioPath => _data['audioPath'] as String?;
  String? get audioUrl => _data['audioUrl'] as String?;
  String? get imageUrl => _data['imageUrl'] as String?;
  double? get duration => (_data['duration'] as num?)?.toDouble();
  bool get isActive => _data['isActive']! as bool;
  String get approvalStatus => _data['approvalStatus']! as String;
  bool get humanApproved => _data['humanApproved']! as bool;
  String get audioStatus => _data['audioStatus']! as String;
  int get displayOrder => _data['displayOrder']! as int;
  int? get audioSourceRevision => _data['audioSourceRevision'] as int?;

  bool get isPublishable =>
      isActive &&
      humanApproved &&
      approvalStatus == 'approved_text' &&
      audioStatus == 'ready';

  static const approvalStates = {
    'draft',
    'in_review',
    'needs_revision',
    'approved_text',
    'rejected',
  };
  static const audioStates = {
    'not_generated',
    'in_review',
    'ready',
    'rejected',
  };

  factory Story.fromJson(Map<String, Object?> json) {
    Never invalid() => throw const FormatException('Invalid story metadata.');
    String text(String key) {
      final v = json[key];
      if (v is! String || v.trim().isEmpty) invalid();
      return v.trim();
    }

    int positiveInt(String key) {
      final v = json[key];
      if (v is! int || v <= 0) invalid();
      return v;
    }

    bool boolean(String key) {
      final v = json[key];
      if (v is! bool) invalid();
      return v;
    }

    String? optionalText(String key) {
      if (json[key] == null) return null;
      return text(key);
    }

    bool https(String value) {
      final u = Uri.tryParse(value);
      return u != null &&
          u.scheme == 'https' &&
          u.host.isNotEmpty &&
          u.userInfo.isEmpty &&
          !u.hasQuery &&
          !u.hasFragment;
    }

    final emotionKey = text('emotion');
    final petKey = text('petType');
    final emotions = EmotionCategory.values.where(
      (e) => e.englishKey == emotionKey,
    );
    final pets = StoryPet.values.where((p) => p.name == petKey);
    if (emotions.isEmpty || pets.isEmpty) invalid();
    final emotion = emotions.single;
    final pet = pets.single;
    if (StorySelection.approvedPets[emotion] != pet) invalid();
    final id = text('storyId');
    if (!RegExp('^${emotion.englishKey}_${pet.name}_[0-9]{3}\$').hasMatch(id) ||
        id.endsWith('_000')) {
      invalid();
    }
    final revision = positiveInt('revision');
    final title = text('title');
    final description = text('description');
    final body = text('storyText');
    final japanese = RegExp(r'[\u3040-\u30ff\u3400-\u9fff]');
    if (!japanese.hasMatch(title) ||
        !japanese.hasMatch(description) ||
        !japanese.hasMatch(body) ||
        title.runes.length > 80 ||
        description.runes.length > 300 ||
        body.runes.length > 4000 ||
        text('language') != 'ja-JP') {
      invalid();
    }
    final order = positiveInt('displayOrder');
    final active = boolean('isActive');
    final approved = boolean('humanApproved');
    final approval = text('approvalStatus');
    final audio = text('audioStatus');
    if (!approvalStates.contains(approval) ||
        !audioStates.contains(audio) ||
        approved != (approval == 'approved_text')) {
      invalid();
    }

    final path = optionalText('audioPath');
    final url = optionalText('audioUrl');
    final image = optionalText('imageUrl');
    final expectedPath =
        'assets/audio/${id}_r${revision.toString().padLeft(3, '0')}.mp3';
    // Keep Issue #10's versioned paths readable, and support the MVP's
    // emotion/pet folders. No arbitrary paths, traversal or Storage URLs.
    final nestedPath =
        'assets/audio/$emotionKey/$petKey/story_${id.substring(id.length - 3)}.mp3';
    if (path != null && path != expectedPath && path != nestedPath) invalid();
    if (url != null && !https(url)) invalid();
    if (path != null && url != null) invalid();
    if (image != null && !https(image)) invalid();
    final duration = json['duration'];
    if (duration != null &&
        (duration is! num || !duration.isFinite || duration <= 0)) {
      invalid();
    }
    final source = json['audioSourceRevision'];
    if (source != null && (source is! int || source <= 0)) invalid();
    if (audio == 'ready' &&
        ((path == null && url == null) ||
            duration == null ||
            source != revision)) {
      invalid();
    }
    final timestamp = text('createdAt');
    final parts = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'
      r'(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$',
    ).firstMatch(timestamp);
    if (parts == null) invalid();
    if (!timestamp.endsWith('Z')) {
      final offset = timestamp.substring(timestamp.length - 5).split(':');
      final hours = int.parse(offset[0]);
      final minutes = int.parse(offset[1]);
      if (hours > 14 || minutes > 59 || (hours == 14 && minutes != 0)) {
        invalid();
      }
    }
    final values = [for (var i = 1; i <= 6; i++) int.parse(parts.group(i)!)];
    final day = DateTime.utc(values[0], values[1], values[2]);
    if (values[0] < 1 ||
        day.year != values[0] ||
        day.month != values[1] ||
        day.day != values[2] ||
        values[3] > 23 ||
        values[4] > 59 ||
        values[5] > 59) {
      invalid();
    }
    final created = DateTime.tryParse(timestamp)?.toUtc();
    if (created == null) invalid();

    return Story._(
      Map.unmodifiable({
        'storyId': id,
        'revision': revision,
        'emotion': emotionKey,
        'petType': petKey,
        'title': title,
        'description': description,
        'storyText': body,
        'language': 'ja-JP',
        'audioPath': path,
        'audioUrl': url,
        'imageUrl': image,
        'duration': duration,
        'isActive': active,
        'createdAt': created.toIso8601String(),
        'approvalStatus': approval,
        'humanApproved': approved,
        'audioStatus': audio,
        'audioSourceRevision': source,
        'displayOrder': order,
      }),
      emotion,
      pet,
      created,
    );
  }

  Map<String, Object?> toJson() => Map.of(_data);

  /// The future cloud_firestore adapter passes Timestamp.fromDate here.
  Map<String, Object?> toFirestore({
    required Object Function(DateTime) encodeTimestamp,
  }) => {...toJson(), 'createdAt': encodeTimestamp(createdAt)};

  /// The future adapter passes (value) => (value as Timestamp).toDate().
  factory Story.fromFirestore(
    Map<String, Object?> data, {
    required DateTime Function(Object) decodeTimestamp,
  }) {
    try {
      final raw = data['createdAt'];
      if (raw == null) throw const FormatException();
      return Story.fromJson({
        ...data,
        'createdAt': decodeTimestamp(raw).toUtc().toIso8601String(),
      });
    } catch (_) {
      throw const FormatException('Invalid Firestore story metadata.');
    }
  }

  /// Issue #10's snake_case library remains readable after explicit enrichment
  /// with Issue #11's description/isActive/createdAt/imageUrl metadata.
  factory Story.fromLibraryJson(Map<String, Object?> data) {
    final emotion = data['emotion'];
    final pet = data['pet'];
    final audio = data['audio'];
    if (emotion is! Map<String, dynamic> ||
        pet is! Map<String, dynamic> ||
        audio is! Map<String, dynamic>) {
      throw const FormatException('Invalid story library entry.');
    }
    final story = Story.fromJson({
      'storyId': data['story_id'],
      'revision': data['revision'],
      'emotion': emotion['key'],
      'petType': pet['key'],
      'title': data['title'],
      'storyText': data['story_text'],
      'description': data['description'],
      'imageUrl': data['imageUrl'],
      'language': data['language'],
      'isActive': data['isActive'],
      'createdAt': data['createdAt'],
      'approvalStatus': data['status'],
      'humanApproved': data['human_approved'],
      'displayOrder': data['display_order'],
      'audioPath': audio['asset_path'],
      'audioUrl': audio['audio_url'],
      'duration': audio['duration_seconds'],
      'audioStatus': audio['status'],
      'audioSourceRevision': audio['source_revision'],
    });
    if (emotion['label'] != story.emotion.japanese ||
        pet['label'] != story.petType.japanese) {
      throw const FormatException('Inconsistent story labels.');
    }
    return story;
  }
}
