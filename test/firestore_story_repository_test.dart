import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/domain/emotions/emotion_analysis_result.dart';
import 'package:yorisoi/domain/stories/story.dart';
import 'package:yorisoi/repositories/fallback_story_repository.dart';
import 'package:yorisoi/repositories/firestore_story_repository.dart';
import 'package:yorisoi/repositories/json_story_repository.dart';
import 'package:yorisoi/repositories/story_repository.dart';

class _Source implements StoryFirestoreSource {
  Map<String, dynamic>? library = {
    'schemaVersion': 'yorisoi-story-data-v1',
    'language': 'ja-JP',
    'publicationStatus': 'approved',
  };
  List<List<FirestoreStoryRecord>> pages = [];
  Object? error;
  int reads = 0;
  FirestoreStoryRecord? byId;
  @override
  Future<Map<String, dynamic>?> readLibrary() async {
    if (error != null) throw error!;
    return library;
  }

  @override
  Future<List<FirestoreStoryRecord>> readPage(
    EmotionCategory emotion, {
    FirestoreStoryRecord? after,
  }) async {
    reads++;
    return reads <= pages.length ? pages[reads - 1] : [];
  }

  @override
  Future<FirestoreStoryRecord?> readById(String id) async => byId;
}

class _ManifestBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key != 'AssetManifest.bin') throw StateError('unexpected asset');
    return const StandardMessageCodec().encodeMessage({
      'assets/audio/happy/dog/story_001.mp3': [
        {'asset': 'assets/audio/happy/dog/story_001.mp3'},
      ],
    })!;
  }
}

// Query-building spy only. Never described as a real Firestore test.
// The SDK marks Query sealed; this isolated test double only records calls.
// ignore: subtype_of_sealed_class
class _QuerySpy implements CollectionReference<Map<String, dynamic>> {
  final calls = <Invocation>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    return this;
  }
}

class _DbSpy implements FirebaseFirestore {
  final query = _QuerySpy();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'stories');
    return query;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Map<String, dynamic> row([int n = 1]) {
    final fixture = jsonDecode(
      File('test/fixtures/story_library_demo.json').readAsStringSync(),
    ) as Map;
    return Map<String, dynamic>.from((fixture['stories'] as List).first as Map)
      ..['storyId'] = 'happy_dog_${n.toString().padLeft(3, '0')}'
      ..['displayOrder'] = n
      ..['audioUrl'] = null
      ..['audioPath'] =
          'assets/audio/happy/dog/story_${n.toString().padLeft(3, '0')}.mp3'
      ..['createdAt'] = Timestamp.fromDate(DateTime.utc(2026, 11, 2));
  }

  FirestoreStoryRecord record([int n = 1, Map<String, dynamic>? edits]) {
    final data = row(n)..addAll(edits ?? {});
    return FirestoreStoryRecord(data['storyId'] as String, data);
  }

  FirestoreStoryRepository repo(
    _Source source, {
    Future<bool> Function(Story)? audio,
  }) => FirestoreStoryRepository(
    source: source,
    audioAvailable: audio ?? (_) async => true,
  );
  Matcher code(StoryDataError error) =>
      isA<StoryDataException>().having((e) => e.code, 'code', error);

  test('real SDK Timestamp roundtrip and nested asset path', () {
    final story = Story.fromFirestore(
      row(),
      decodeTimestamp: (v) => (v as Timestamp).toDate(),
    );
    expect(story.toFirestore(encodeTimestamp: Timestamp.fromDate), row());
    expect(story.audioPath, 'assets/audio/happy/dog/story_001.mp3');
    for (final path in [
      'assets/audio/happy/cat/story_001.mp3',
      'assets/audio/happy/dog/story_002.mp3',
      'assets/audio/../secret.mp3',
      'gs://bucket/story.mp3',
    ]) {
      expect(
        () => Story.fromJson({...story.toJson(), 'audioPath': path}),
        throwsFormatException,
      );
    }
  });
  test(
    'SDK query includes publication gates, main emotion, order and limit',
    () {
      final db = _DbSpy();
      FirebaseStorySource(db).queryForEmotion(EmotionCategory.happy);
      final filters = {
        for (final c in db.query.calls.where((c) => c.memberName == #where))
          c.positionalArguments.first: c.namedArguments[#isEqualTo],
      };
      expect(filters, {
        'emotion': 'happy',
        'petType': 'dog',
        'language': 'ja-JP',
        'isActive': true,
        'humanApproved': true,
        'approvalStatus': 'approved_text',
        'audioStatus': 'ready',
      });
      final order = db.query.calls
          .where((c) => c.memberName == #orderBy)
          .toList();
      expect(order.first.positionalArguments.first, 'displayOrder');
      expect(order.last.positionalArguments.first, FieldPath.documentId);
      expect(db.query.calls.last.positionalArguments, [10]);
    },
  );
  test('main emotion only; returns at most three ordered records', () async {
    final source = _Source()
      ..pages = [
        [for (var n = 1; n <= 4; n++) record(n)],
      ];
    final result = await repo(source).findForAnalysis(
      const EmotionAnalysisResult(
        main: EmotionCategory.happy,
        secondary: EmotionCategory.lonely,
      ),
    );
    expect(result.map((s) => s.storyId), [
      'happy_dog_001',
      'happy_dog_002',
      'happy_dog_003',
    ]);
    expect(() => result.clear(), throwsUnsupportedError);
  });
  test(
    'invalid, mismatched ID, unpublished, URL-only and missing assets excluded',
    () async {
      final source = _Source()
        ..pages = [
          [
            record(1, {'humanApproved': false, 'approvalStatus': 'draft'}),
            record(2, {'isActive': false}),
            record(3, {'audioStatus': 'not_generated'}),
            record(4, {'createdAt': 'not a Timestamp'}),
            record(5, {'emotion': 'lonely'}),
            record(6, {
              'audioPath': null,
              'audioUrl': 'https://example.invalid/audio.mp3',
            }),
            FirestoreStoryRecord('wrong', row(7)),
            record(8),
            record(9),
          ],
        ];
      expect(
        (await repo(
          source,
          audio: (s) async => s.storyId.endsWith('009'),
        ).findByEmotion(EmotionCategory.happy)).map((s) => s.storyId),
        ['happy_dog_009'],
      );
    },
  );
  test(
    'pagination continues after invalid and unavailable first page',
    () async {
      final source = _Source()
        ..pages = [
          [for (var n = 1; n <= 10; n++) record(n)],
          [record(11), record(12)],
        ];
      final result = await repo(
        source,
        audio: (s) async => s.displayOrder > 10,
      ).findByEmotion(EmotionCategory.happy);
      expect(result.map((s) => s.displayOrder), [11, 12]);
      expect(source.reads, 2);
    },
  );
  test('empty and draft catalogs do not manufacture stories', () async {
    final source = _Source();
    expect(await repo(source).findByEmotion(EmotionCategory.happy), isEmpty);
    source.library!['publicationStatus'] = 'draft';
    source.reads = 0;
    expect(await repo(source).findByEmotion(EmotionCategory.happy), isEmpty);
    expect(source.reads, 0);
  });
  test('missing catalog is explicit invalidCatalog', () async {
    await expectLater(
      repo(_Source()..library = null).findByEmotion(EmotionCategory.happy),
      throwsA(code(StoryDataError.invalidCatalog)),
    );
  });
  test(
    'exact reported three-field draft is valid and never queries stories',
    () async {
      final source = _Source()
        ..library = {
          'publicationStatus': 'draft',
          'language': 'ja-JP',
          'schemaVersion': 'yorisoi-story-data-v1',
        };
      expect(storyLibraryIssue(source.library), isNull);
      expect(
        await repo(
          source,
          audio: (_) async => throw StateError('must not read audio'),
        ).findByEmotion(EmotionCategory.happy),
        isEmpty,
      );
      expect(source.reads, 0);
      final details = storyLibraryDiagnostics(source.library);
      expect(details['documentExists'], isTrue);
      expect(details['issue'], isNull);
      expect((details['publicationStatus'] as Map)['recognizedValue'], 'draft');
    },
  );
  for (final entry in {
    'schemaVersion': StoryCatalogIssue.schemaVersionMismatch,
    'language': StoryCatalogIssue.languageMismatch,
    'publicationStatus': StoryCatalogIssue.publicationStatusMismatch,
  }.entries) {
    test(
      'missing ${entry.key} identifies the exact invalid metadata field',
      () async {
        final source = _Source();
        source.library!.remove(entry.key);
        await expectLater(
          repo(source).findByEmotion(EmotionCategory.happy),
          throwsA(
            isA<StoryCatalogException>().having(
              (e) => e.issue,
              'issue',
              entry.value,
            ),
          ),
        );
        expect(
          (storyLibraryDiagnostics(source.library)[entry.key] as Map)['state'],
          'missing',
        );
        expect(source.reads, 0);
      },
    );
  }
  test('missing document differs from an existing empty document', () async {
    final source = _Source()..library = null;
    await expectLater(
      repo(source).findByEmotion(EmotionCategory.happy),
      throwsA(
        isA<StoryCatalogException>().having(
          (e) => e.issue,
          'issue',
          StoryCatalogIssue.missingDocument,
        ),
      ),
    );
    expect(storyLibraryDiagnostics(null)['documentExists'], isFalse);
    expect(storyLibraryDiagnostics({})['documentExists'], isTrue);
  });
  test(
    'whitespace mismatches are diagnosed without weakening validation',
    () async {
      final source = _Source()
        ..library!['schemaVersion'] = 'yorisoi-story-data-v1 ';
      await expectLater(
        repo(source).findByEmotion(EmotionCategory.happy),
        throwsA(isA<StoryCatalogException>()),
      );
      final field =
          storyLibraryDiagnostics(source.library)['schemaVersion'] as Map;
      expect(field['state'], 'unexpected_value');
      expect(field['matchesAfterTrim'], isTrue);
    },
  );
  test(
    'wrong types and unexpected contents are diagnosed without raw data leaks',
    () {
      final source = _Source()
        ..library!['publicationStatus'] = {'value': 'private-example'};
      var diagnostic = storyLibraryDiagnostics(source.library);
      expect((diagnostic['publicationStatus'] as Map)['state'], 'wrong_type');
      source.library!['schemaVersion'] = 'private-example';
      source.library!['internalNotes'] = 'private-example';
      diagnostic = storyLibraryDiagnostics(source.library);
      expect((diagnostic['schemaVersion'] as Map)['state'], 'unexpected_value');
      expect(jsonEncode(diagnostic), isNot(contains('private-example')));
      expect(jsonEncode(diagnostic), isNot(contains('internalNotes')));
      expect(
        const StoryCatalogException(StoryCatalogIssue.schemaVersionMismatch)
            .toString(),
        'StoryCatalogException(schemaVersionMismatch)',
      );
    },
  );
  for (final entry in {
    'permission-denied': StoryDataError.permissionDenied,
    'unauthenticated': StoryDataError.permissionDenied,
    'unavailable': StoryDataError.network,
    'deadline-exceeded': StoryDataError.network,
    'failed-precondition': StoryDataError.configuration,
    'not-found': StoryDataError.configuration,
    'unknown': StoryDataError.readFailed,
  }.entries) {
    test('safe SDK error mapping ${entry.key}', () async {
      final source = _Source()
        ..error = FirebaseException(
          plugin: 'cloud_firestore',
          code: entry.key,
          message: 'private backend detail',
        );
      await expectLater(
        repo(source).findByEmotion(EmotionCategory.happy),
        throwsA(code(entry.value)),
      );
    });
  }
  test('timeout and unexpected failures are safe', () async {
    for (final error in [TimeoutException('private'), StateError('private')]) {
      await expectLater(
        repo(_Source()..error = error).findByEmotion(EmotionCategory.happy),
        throwsA(
          code(
            error is TimeoutException
                ? StoryDataError.network
                : StoryDataError.readFailed,
          ),
        ),
      );
    }
  });
  test('ID lookup applies same gates and rejects path traversal', () async {
    final source = _Source()..byId = record();
    expect(
      (await repo(source).findById('happy_dog_001'))?.storyId,
      'happy_dog_001',
    );
    source.byId = record(1, {'isActive': false});
    expect(await repo(source).findById('happy_dog_001'), isNull);
    expect(await repo(source).findById('../secret'), isNull);
    source.byId = null;
    expect(await repo(source).findById('happy_dog_001'), isNull);
  });
  test(
    'actual asset-manifest check rejects absent files and remote URLs',
    () async {
      final checker = bundledStoryAudio(_ManifestBundle());
      Story parse(Map<String, dynamic> data) => Story.fromFirestore(
        data,
        decodeTimestamp: (v) => (v as Timestamp).toDate(),
      );
      expect(await checker(parse(row())), isTrue);
      expect(await checker(parse(row(2))), isFalse);
      expect(
        await checker(
          parse(
            row()
              ..['audioPath'] = null
              ..['audioUrl'] = 'https://example.invalid/audio.mp3',
          ),
        ),
        isFalse,
      );
    },
  );
  test('asset verification failure is explicit', () async {
    final source = _Source()
      ..pages = [
        [record()],
      ];
    await expectLater(
      repo(
        source,
        audio: (_) async => throw StateError('private'),
      ).findByEmotion(EmotionCategory.happy),
      throwsA(code(StoryDataError.audioCheckFailed)),
    );
  });
  test(
    'JSON fallback only on network; no fallback for empty, draft or denied',
    () async {
      var offlineReads = 0;
      final offline = JsonStoryRepository(
        readCatalog: () async {
          offlineReads++;
          return File('test/fixtures/story_library_demo.json')
              .readAsStringSync();
        },
        audioAvailable: (_) async => true,
      );
      final source = _Source()
        ..error = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );
      final fallback = FallbackStoryRepository(
        primary: repo(source),
        offline: offline,
      );
      expect((await fallback.findByEmotion(EmotionCategory.happy)).length, 3);
      source.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      await expectLater(
        fallback.findByEmotion(EmotionCategory.happy),
        throwsA(code(StoryDataError.permissionDenied)),
      );
      source.error = null;
      expect(await fallback.findByEmotion(EmotionCategory.happy), isEmpty);
      source.library!['publicationStatus'] = 'draft';
      expect(await fallback.findByEmotion(EmotionCategory.happy), isEmpty);
      expect(offlineReads, 1);
    },
  );
}
