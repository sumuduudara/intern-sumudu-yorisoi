import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/domain/emotions/emotion_analysis_result.dart';
import 'package:yorisoi/domain/stories/story.dart';
import 'package:yorisoi/domain/stories/story_draft.dart';
import 'package:yorisoi/repositories/json_story_repository.dart';
import 'package:yorisoi/repositories/story_repository.dart';

class _FakeTimestamp {
  _FakeTimestamp(this.value);
  final DateTime value;
}

void main() {
  Map<String, dynamic> fixture() => jsonDecode(
    File('test/fixtures/story_library_demo.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  Map<String, dynamic> first() =>
      Map.of((fixture()['stories'] as List).first as Map<String, dynamic>);
  JsonStoryRepository repository(
    Map<String, dynamic> catalog, {
    Future<bool> Function(Story)? check,
  }) => JsonStoryRepository(
    readCatalog: () async => jsonEncode(catalog),
    audioAvailable: check ?? (_) async => true,
  );

  test('Happy returns only 3 eligible dogs in editorial order', () async {
    final result = await repository(fixture()).findForAnalysis(
      const EmotionAnalysisResult(
        main: EmotionCategory.happy,
        secondary: EmotionCategory.lonely,
      ),
    );
    expect(result.map((s) => s.storyId), [
      'happy_dog_002',
      'happy_dog_001',
      'happy_dog_003',
    ]);
    expect(
      result.every(
        (s) =>
            s.emotion == EmotionCategory.happy &&
            s.petType == StoryPet.dog &&
            s.isPublishable,
      ),
      isTrue,
    );
    expect(() => result.clear(), throwsUnsupportedError);
  });
  test('missing emotion is empty, never falls back to other', () async {
    expect(
      await repository(fixture()).findByEmotion(EmotionCategory.anxious),
      isEmpty,
    );
  });
  test(
    'ID lookup never returns draft, inactive, pending or invalid entries',
    () async {
      final repo = repository(fixture());
      expect((await repo.findById('happy_dog_001'))?.title, '散歩道の小さな花');
      for (final id in [
        'happy_dog_004',
        'happy_dog_005',
        'happy_dog_006',
        'happy_dog_007',
        'happy_dog_008',
        'missing',
      ]) {
        expect(await repo.findById(id), isNull);
      }
    },
  );
  test('valid JSON round trip preserves all fields and UTC timestamp', () {
    final story = Story.fromJson(first());
    expect(
      Story.fromJson(
        jsonDecode(jsonEncode(story.toJson())) as Map<String, dynamic>,
      ).toJson(),
      story.toJson(),
    );
    expect(story.createdAt.isUtc, isTrue);
    final exported = story.toJson()..['humanApproved'] = false;
    expect(story.humanApproved, isTrue); // No external mutation of model state.
    expect(exported['humanApproved'], isFalse);
  });
  test('Firestore timestamp converters round trip without Firebase SDK', () {
    final story = Story.fromJson(first());
    final map = story.toFirestore(encodeTimestamp: _FakeTimestamp.new);
    expect(map['createdAt'], isA<_FakeTimestamp>());
    final restored = Story.fromFirestore(
      map,
      decodeTimestamp: (value) => (value as _FakeTimestamp).value,
    );
    expect(restored.toJson(), story.toJson());
    expect(
      () => Story.fromFirestore({
        ...map,
        'createdAt': null,
      }, decodeTimestamp: (_) => throw StateError('secret')),
      throwsFormatException,
    );
  });
  for (final entry in StorySelection.approvedPets.entries) {
    test('preserves mapping ${entry.key.englishKey}/${entry.value.name}', () {
      final raw = first();
      raw['emotion'] = entry.key.englishKey;
      raw['petType'] = entry.value.name;
      raw['storyId'] = '${entry.key.englishKey}_${entry.value.name}_001';
      final s = Story.fromJson(raw);
      expect(s.emotion, entry.key);
      expect(s.petType, entry.value);
    });
  }
  final invalid = <String, Object?>{
    'storyId': 'happy_dog_000',
    'emotion': 'relieved',
    'petType': 'cat',
    'title': '',
    'description': '',
    'storyText': null,
    'language': 'en-US',
    'isActive': 'true',
    'humanApproved': false,
    'approvalStatus': 'unknown',
    'audioStatus': 'unknown',
    'revision': 0,
    'displayOrder': 1.5,
    'audioSourceRevision': 2,
    'duration': 0,
    'createdAt': '2026-11-02',
    'audioUrl': 'http://example.invalid/audio.mp3',
    'imageUrl': 'https://user:secret@example.invalid/image.png',
  };
  for (final entry in invalid.entries) {
    test('invalid ${entry.key} is safely rejected', () {
      final raw = first()..[entry.key] = entry.value;
      try {
        Story.fromJson(raw);
        fail('Expected invalid metadata');
      } on FormatException catch (e) {
        expect(e.toString(), isNot(contains('secret')));
      }
    });
  }
  test(
    'asset paths are versioned, traversal and multiple audio sources rejected',
    () {
      final raw = first()..['audioUrl'] = null;
      raw['audioPath'] = 'assets/audio/happy_dog_001_r001.mp3';
      expect(Story.fromJson(raw).audioPath, raw['audioPath']);
      expect(
        () => Story.fromJson({...raw, 'audioPath': '../secret.mp3'}),
        throwsFormatException,
      );
      expect(
        () => Story.fromJson({
          ...raw,
          'audioUrl': 'https://example.invalid/audio.mp3',
        }),
        throwsFormatException,
      );
    },
  );
  test('nonfinite duration, wrong timestamp and missing fields rejected', () {
    for (final duration in [double.nan, double.infinity, -1]) {
      expect(
        () => Story.fromJson({...first(), 'duration': duration}),
        throwsFormatException,
      );
    }
    final raw = first()..remove('createdAt');
    expect(() => Story.fromJson(raw), throwsFormatException);
    for (final date in [
      '2026-02-30T00:00:00Z',
      '2026-13-01T00:00:00Z',
      '2026-11-02T25:00:00Z',
      '2026-11-02T00:00:00+99:99',
      '2026-11-02T00:00:00+14:01',
    ]) {
      expect(
        () => Story.fromJson({...first(), 'createdAt': date}),
        throwsFormatException,
      );
    }
    expect(
      () => Story.fromFirestore(
        first(),
        decodeTimestamp: (_) => throw StateError('private'),
      ),
      throwsFormatException,
    );
  });
  test('draft library gates every record without checking audio', () async {
    final raw = fixture()..['publicationStatus'] = 'draft';
    expect(
      await repository(
        raw,
        check: (_) async => throw StateError('must not run'),
      ).findByEmotion(EmotionCategory.happy),
      isEmpty,
    );
  });
  test('missing or invalid publication metadata fails closed', () async {
    for (final edit in <Map<String, dynamic>>[
      {'publicationStatus': 'unknown'},
      {'schemaVersion': 'unknown'},
      {'stories': null},
    ]) {
      await expectLater(
        repository({...fixture(), ...edit})
            .findByEmotion(EmotionCategory.happy),
        throwsA(isA<StoryDataException>()),
      );
    }
  });
  test('mixed catalog namespaces cannot override a draft gate', () async {
    for (final extra in <Map<String, dynamic>>[
      {'schema_version': 'yorisoi-story-library-v1'},
      {'publication_status': 'draft'},
    ]) {
      await expectLater(
        repository({...fixture(), ...extra})
            .findByEmotion(EmotionCategory.happy),
        throwsA(isA<StoryDataException>()),
      );
    }
  });
  test('malformed catalog and read failures have safe codes', () async {
    for (final source in ['not json', '[]', '{}']) {
      await expectLater(
        JsonStoryRepository(
          readCatalog: () async => source,
          audioAvailable: (_) async => true,
        ).findByEmotion(EmotionCategory.happy),
        throwsA(
          isA<StoryDataException>().having(
            (e) => e.code,
            'code',
            StoryDataError.invalidCatalog,
          ),
        ),
      );
    }
    await expectLater(
      JsonStoryRepository(
        readCatalog: () async => throw StateError('private'),
        audioAvailable: (_) async => true,
      ).findByEmotion(EmotionCategory.happy),
      throwsA(
        isA<StoryDataException>().having(
          (e) => e.code,
          'code',
          StoryDataError.readFailed,
        ),
      ),
    );
  });
  test(
    'all duplicate IDs excluded, including active revision ambiguity',
    () async {
      final raw = fixture();
      (raw['stories'] as List).add(first());
      final result = await repository(raw).findByEmotion(EmotionCategory.happy);
      expect(result.map((s) => s.storyId), ['happy_dog_002', 'happy_dog_003']);
    },
  );
  test('missing audio excludes record; verifier failure is explicit', () async {
    final result = await repository(
      fixture(),
      check: (s) async => s.storyId != 'happy_dog_002',
    ).findByEmotion(EmotionCategory.happy);
    expect(result.length, 2);
    await expectLater(
      repository(
        fixture(),
        check: (_) async => throw StateError('private'),
      ).findByEmotion(EmotionCategory.happy),
      throwsA(
        isA<StoryDataException>().having(
          (e) => e.code,
          'code',
          StoryDataError.audioCheckFailed,
        ),
      ),
    );
  });
  test(
    'caps at 3 and deterministic tie sorting; can return 1 honestly',
    () async {
      final base = first();
      final rows = <Object>[];
      for (final n in [4, 3, 2, 1]) {
        rows.add({...base, 'storyId': 'happy_dog_00$n', 'displayOrder': 1});
      }
      final catalog = {...fixture(), 'stories': rows};
      expect(
        (await repository(catalog).findByEmotion(EmotionCategory.happy))
            .map((s) => s.storyId),
        ['happy_dog_001', 'happy_dog_002', 'happy_dog_003'],
      );
      catalog['stories'] = [base];
      expect(
        (await repository(catalog).findByEmotion(EmotionCategory.happy)).length,
        1,
      );
    },
  );
  test('Issue #10 empty draft template remains compatible', () async {
    final source = File('docs/story_library_template.json').readAsStringSync();
    expect(
      await JsonStoryRepository(
        readCatalog: () async => source,
        audioAvailable: (_) async => true,
      ).findByEmotion(EmotionCategory.happy),
      isEmpty,
    );
  });
  test('enriched Issue #10 snake_case entry conversion is explicit', () async {
    final s = Story.fromJson(first());
    final entry = {
      'story_id': s.storyId,
      'revision': s.revision,
      'emotion': {'key': 'happy', 'label': '嬉しい'},
      'pet': {'key': 'dog', 'label': '犬'},
      'title': s.title,
      'story_text': s.storyText,
      'language': 'ja-JP',
      'description': s.description,
      'isActive': s.isActive,
      'createdAt': s.createdAt.toIso8601String(),
      'imageUrl': null,
      'status': s.approvalStatus,
      'human_approved': s.humanApproved,
      'display_order': s.displayOrder,
      'audio': {
        'status': s.audioStatus,
        'asset_path': null,
        'audio_url': s.audioUrl,
        'duration_seconds': s.duration,
        'source_revision': s.audioSourceRevision,
      },
    };
    expect(Story.fromLibraryJson(entry).toJson(), s.toJson());
    final catalog = {
      'schema_version': 'yorisoi-story-library-v1',
      'language': 'ja-JP',
      'publication_status': 'approved',
      'stories': [entry],
    };
    expect(
      (await repository(catalog).findByEmotion(EmotionCategory.happy)).length,
      1,
    );
    expect(
      () => Story.fromLibraryJson({
        ...entry,
        'pet': {'key': 'dog', 'label': '猫'},
      }),
      throwsFormatException,
    );
  });
}
