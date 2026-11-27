import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../domain/emotions/emotion_analysis_result.dart';
import '../domain/stories/story.dart';
import '../domain/stories/story_draft.dart';
import 'story_repository.dart';

enum StoryCatalogIssue {
  missingDocument,
  schemaVersionMismatch,
  languageMismatch,
  publicationStatusMismatch,
}

class StoryCatalogException extends StoryDataException {
  const StoryCatalogException(this.issue)
    : super(StoryDataError.invalidCatalog);
  final StoryCatalogIssue issue;

  @override
  String toString() => 'StoryCatalogException(${issue.name})';
}

/// Retain strict validation: draft is valid metadata, not a release approval.
StoryCatalogIssue? storyLibraryIssue(Map<String, dynamic>? data) {
  if (data == null) return StoryCatalogIssue.missingDocument;
  if (data['schemaVersion'] != 'yorisoi-story-data-v1') {
    return StoryCatalogIssue.schemaVersionMismatch;
  }
  if (data['language'] != 'ja-JP') return StoryCatalogIssue.languageMismatch;
  if (!['approved', 'draft'].contains(data['publicationStatus'])) {
    return StoryCatalogIssue.publicationStatusMismatch;
  }
  return null;
}

/// Diagnose only known keys. Never log arbitrary fields or unexpected values.
Map<String, Object?> storyLibraryDiagnostics(Map<String, dynamic>? data) {
  const expected = {
    'schemaVersion': ['yorisoi-story-data-v1'],
    'language': ['ja-JP'],
    'publicationStatus': ['draft', 'approved'],
  };
  return {
    'documentExists': data != null,
    'issue': storyLibraryIssue(data)?.name,
    for (final field in expected.entries)
      field.key: {
        'state': data?.containsKey(field.key) != true
            ? 'missing'
            : data![field.key] is! String
            ? 'wrong_type'
            : field.value.contains(data[field.key])
            ? 'valid'
            : 'unexpected_value',
        'recognizedValue': field.value.contains(data?[field.key])
            ? data![field.key]
            : null,
        'matchesAfterTrim':
            data?[field.key] is String &&
            field.value.contains((data![field.key] as String).trim()),
      },
  };
}

/// Small I/O boundary: tests replace this, not Firebase's global instance.
abstract class StoryFirestoreSource {
  Future<Map<String, dynamic>?> readLibrary();
  Future<List<FirestoreStoryRecord>> readPage(
    EmotionCategory emotion, {
    FirestoreStoryRecord? after,
  });
  Future<FirestoreStoryRecord?> readById(String id);
}

class FirestoreStoryRecord {
  const FirestoreStoryRecord(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}

/// Real cloud_firestore reads, always server-only (never a stale cache success).
class FirebaseStorySource implements StoryFirestoreSource {
  FirebaseStorySource(this.firestore);
  final FirebaseFirestore firestore;
  static const pageSize = 10;
  static const _server = GetOptions(source: Source.server);

  @override
  Future<Map<String, dynamic>?> readLibrary() async =>
      (await firestore.doc('storyLibraries/current').get(_server)).data();

  // All publication conditions are also in the query: rules are not filters.
  Query<Map<String, dynamic>> queryForEmotion(EmotionCategory emotion) =>
      firestore
          .collection('stories')
          .where('emotion', isEqualTo: emotion.englishKey)
          .where(
            'petType',
            isEqualTo: StorySelection.approvedPets[emotion]!.name,
          )
          .where('language', isEqualTo: 'ja-JP')
          .where('isActive', isEqualTo: true)
          .where('humanApproved', isEqualTo: true)
          .where('approvalStatus', isEqualTo: 'approved_text')
          .where('audioStatus', isEqualTo: 'ready')
          .orderBy('displayOrder')
          .orderBy(FieldPath.documentId)
          .limit(pageSize);

  @override
  Future<List<FirestoreStoryRecord>> readPage(
    EmotionCategory emotion, {
    FirestoreStoryRecord? after,
  }) async {
    var query = queryForEmotion(emotion);
    if (after != null) {
      query = query.startAfter([after.data['displayOrder'], after.id]);
    }
    final page = await query.get(_server);
    return [
      for (final doc in page.docs) FirestoreStoryRecord(doc.id, doc.data()),
    ];
  }

  @override
  Future<FirestoreStoryRecord?> readById(String id) async {
    final doc = await firestore.collection('stories').doc(id).get(_server);
    final data = doc.data();
    return data == null ? null : FirestoreStoryRecord(doc.id, data);
  }
}

class FirestoreStoryRepository extends StoryRepository {
  FirestoreStoryRepository({
    required this.source,
    required this.audioAvailable,
    this.readTimeout = const Duration(seconds: 15),
  });

  factory FirestoreStoryRepository.firebase({
    required FirebaseFirestore firestore,
    AssetBundle? bundle,
  }) => FirestoreStoryRepository(
    source: FirebaseStorySource(firestore),
    audioAvailable: bundledStoryAudio(bundle ?? rootBundle),
  );

  final StoryFirestoreSource source;
  final Future<bool> Function(Story) audioAvailable;
  final Duration readTimeout;

  Future<T> _read<T>(Future<T> Function() operation) async {
    try {
      return await operation().timeout(readTimeout);
    } on TimeoutException {
      throw const StoryDataException(StoryDataError.network);
    } on FirebaseException catch (e) {
      throw StoryDataException(switch (e.code) {
        'permission-denied' ||
        'unauthenticated' => StoryDataError.permissionDenied,
        'unavailable' || 'deadline-exceeded' => StoryDataError.network,
        'failed-precondition' || 'not-found' => StoryDataError.configuration,
        _ => StoryDataError.readFailed,
      });
    } on StoryDataException {
      rethrow;
    } catch (_) {
      throw const StoryDataException(StoryDataError.readFailed);
    }
  }

  Future<bool> _released() async {
    final library = await _read(source.readLibrary);
    final issue = storyLibraryIssue(library);
    if (issue != null) throw StoryCatalogException(issue);
    return library!['publicationStatus'] == 'approved';
  }

  Story? _parse(FirestoreStoryRecord record) {
    try {
      final story = Story.fromFirestore(
        record.data,
        decodeTimestamp: (value) => (value as Timestamp).toDate(),
      );
      // MVP is bundled MP3 only. Legacy URL stories remain usable in JSON,
      // but can never silently become remote audio in the Firestore path.
      if (record.id != story.storyId ||
          !story.isPublishable ||
          story.audioPath == null ||
          story.audioUrl != null) {
        return null;
      }
      return story;
    } on FormatException {
      return null;
    }
  }

  Future<bool> _hasAudio(Story story) async {
    try {
      return await audioAvailable(story);
    } catch (_) {
      throw const StoryDataException(StoryDataError.audioCheckFailed);
    }
  }

  @override
  Future<List<Story>> findByEmotion(EmotionCategory mainEmotion) async {
    if (!await _released()) return const [];
    final matches = <Story>[];
    final seen = <String>{};
    FirestoreStoryRecord? cursor;
    // Bounded to 100 candidates, no automatic network retries/full scans.
    for (var page = 0; page < 10; page++) {
      final records = await _read(
        () => source.readPage(mainEmotion, after: cursor),
      );
      if (records.isEmpty) break;
      for (final record in records) {
        if (!seen.add(record.id)) continue;
        final story = _parse(record);
        if (story != null &&
            story.emotion == mainEmotion &&
            await _hasAudio(story)) {
          matches.add(story);
        }
        if (matches.length == 3) return List.unmodifiable(matches);
      }
      cursor = records.last;
      if (records.length < FirebaseStorySource.pageSize) break;
    }
    return List.unmodifiable(matches);
  }

  @override
  Future<Story?> findById(String storyId) async {
    if (!RegExp(r'^[a-z]+_[a-z]+_[0-9]{3}$').hasMatch(storyId)) return null;
    if (!await _released()) return null;
    final record = await _read(() => source.readById(storyId));
    if (record == null) return null;
    final story = _parse(record);
    return story != null && await _hasAudio(story) ? story : null;
  }
}

/// Checks the shipped manifest, not a URL, Storage bucket, or fake readiness.
Future<bool> Function(Story) bundledStoryAudio(AssetBundle bundle) =>
    (story) async {
      final path = story.audioPath;
      if (path == null || story.audioUrl != null) return false;
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      return manifest.listAssets().contains(path);
    };
