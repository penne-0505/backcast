import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../persistence/app_database.dart';
import '../persistence/persistence_providers.dart';

const _uuid = Uuid();
const _analyticsConsentPreferenceKey = 'analyticsConsent';
const _analyticsInstallIdPreferenceKey = 'analyticsInstallId';
const _analyticsLastFlushAtPreferenceKey = 'analyticsLastFlushAt';

enum AnalyticsConsent { enabled, disabled }

enum AnalyticsUploadState { pending, failed }

enum UsageAnalyticsEvent {
  appOpened('app_opened'),
  firstPlanCreated('first_plan_created'),
  planCreated('plan_created'),
  planSaved('plan_saved'),
  blockAdded('block_added'),
  blockReordered('block_reordered'),
  templateCreated('template_created'),
  templateApplied('template_applied'),
  calendarExportStarted('calendar_export_started'),
  calendarExportCompleted('calendar_export_completed'),
  textShareCompleted('text_share_completed'),
  imageShareCompleted('image_share_completed'),
  paywallViewed('paywall_viewed'),
  purchaseStarted('purchase_started'),
  purchaseCompleted('purchase_completed'),
  accountDeleted('account_deleted');

  const UsageAnalyticsEvent(this.wireName);

  final String wireName;
}

final _allowedProperties = <UsageAnalyticsEvent, Map<String, Object>>{
  UsageAnalyticsEvent.appOpened: {
    'launch_source': {'cold_start', 'resume'},
    'platform': _platformValues,
  },
  UsageAnalyticsEvent.firstPlanCreated: {
    'block_count_bucket': _countBucketValues,
  },
  UsageAnalyticsEvent.planCreated: {
    'source': {'initial_bootstrap', 'timeline_list', 'fallback'},
    'block_count_bucket': _countBucketValues,
  },
  UsageAnalyticsEvent.planSaved: {
    'block_count_bucket': _countBucketValues,
    'has_buffer': bool,
  },
  UsageAnalyticsEvent.blockAdded: {
    'block_type': {'action', 'actionPoint'},
    'block_count_bucket': _countBucketValues,
  },
  UsageAnalyticsEvent.blockReordered: {
    'block_count_bucket': _countBucketValues,
  },
  UsageAnalyticsEvent.templateCreated: {
    'block_count_bucket': _countBucketValues,
  },
  UsageAnalyticsEvent.templateApplied: {
    'block_count_bucket': _countBucketValues,
  },
  UsageAnalyticsEvent.calendarExportStarted: {
    'event_count_bucket': _eventCountBucketValues,
    'platform': _platformValues,
  },
  UsageAnalyticsEvent.calendarExportCompleted: {
    'event_count_bucket': _eventCountBucketValues,
    'result': {
      'success',
      'permission_denied',
      'no_writable_calendar',
      'invalid_payload',
      'unsupported_platform',
      'save_failed',
      'exception',
    },
  },
  UsageAnalyticsEvent.textShareCompleted: {
    'block_count_bucket': _countBucketValues,
  },
  UsageAnalyticsEvent.imageShareCompleted: {
    'block_count_bucket': _countBucketValues,
    'result': {'success', 'failure'},
  },
  UsageAnalyticsEvent.paywallViewed: {
    'source': {'templates', 'timeline_count', 'image_export', 'action_buffer'},
  },
  UsageAnalyticsEvent.purchaseStarted: {
    'source': {'paywall'},
  },
  UsageAnalyticsEvent.purchaseCompleted: {
    'result': {'pending', 'cancelled', 'failed', 'restored'},
  },
  UsageAnalyticsEvent.accountDeleted: {'had_pro_cache': bool},
};

const _countBucketValues = {'0', '1', '2-3', '4-5', '6-10', '11+'};
const _eventCountBucketValues = {'1', '2-3', '4-5', '6-10', '11+'};
const _platformValues = {
  'android',
  'ios',
  'macos',
  'linux',
  'windows',
  'web',
  'unknown',
};

final usageAnalyticsRepositoryProvider = Provider<UsageAnalyticsRepository>((
  ref,
) {
  return UsageAnalyticsRepository(ref.watch(databaseProvider));
});

final usageAnalyticsUploaderProvider = Provider<UsageAnalyticsUploader>((ref) {
  return const SupabaseUsageAnalyticsUploader();
});

final usageAnalyticsServiceProvider = Provider<UsageAnalyticsService>((ref) {
  UsageAnalyticsRepository repository;
  try {
    repository = ref.watch(usageAnalyticsRepositoryProvider);
  } catch (_) {
    return UsageAnalyticsService.disabled();
  }
  return UsageAnalyticsService(
    repository: repository,
    uploader: ref.watch(usageAnalyticsUploaderProvider),
  );
});

final analyticsConsentProvider = FutureProvider<AnalyticsConsent>((ref) {
  return ref.watch(usageAnalyticsRepositoryProvider).fetchConsent();
});

@immutable
class PendingAnalyticsEvent {
  const PendingAnalyticsEvent({
    required this.id,
    required this.eventName,
    required this.properties,
    required this.occurredAt,
    required this.sessionId,
    required this.installId,
    required this.attemptCount,
  });

  final String id;
  final String eventName;
  final Map<String, Object?> properties;
  final DateTime occurredAt;
  final String sessionId;
  final String installId;
  final int attemptCount;
}

class UsageAnalyticsRepository {
  UsageAnalyticsRepository(this._db, {DateTime Function()? now}) : _now = now;

  final AppDatabase _db;
  final DateTime Function()? _now;

  Future<AnalyticsConsent> fetchConsent() async {
    final value = await _fetchPreference(_analyticsConsentPreferenceKey);
    return value == AnalyticsConsent.enabled.name
        ? AnalyticsConsent.enabled
        : AnalyticsConsent.disabled;
  }

  Future<void> setConsent(AnalyticsConsent consent) async {
    await _upsertPreference(_analyticsConsentPreferenceKey, consent.name);
    if (consent == AnalyticsConsent.disabled) {
      await clearPendingEvents();
      await _deletePreference(_analyticsInstallIdPreferenceKey);
      await _deletePreference(_analyticsLastFlushAtPreferenceKey);
    }
  }

  Future<String> ensureInstallId() async {
    final existing = await _fetchPreference(_analyticsInstallIdPreferenceKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final installId = _uuid.v4();
    await _upsertPreference(_analyticsInstallIdPreferenceKey, installId);
    return installId;
  }

  Future<void> enqueue({
    required UsageAnalyticsEvent event,
    required Map<String, Object?> properties,
    required String sessionId,
    required String installId,
  }) async {
    final now = _clock();
    await _db
        .into(_db.analyticsEvents)
        .insert(
          AnalyticsEventsCompanion.insert(
            id: _uuid.v4(),
            eventName: event.wireName,
            propertiesJson: jsonEncode(properties),
            occurredAt: now,
            sessionId: sessionId,
            installId: installId,
            uploadState: AnalyticsUploadState.pending.name,
            createdAt: now,
          ),
        );
  }

  Future<List<PendingAnalyticsEvent>> pendingEvents({int limit = 50}) async {
    final rows =
        await (_db.select(_db.analyticsEvents)
              ..where(
                (row) => row.uploadState.isIn([
                  AnalyticsUploadState.pending.name,
                  AnalyticsUploadState.failed.name,
                ]),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.occurredAt)])
              ..limit(limit))
            .get();

    return rows
        .map(
          (row) => PendingAnalyticsEvent(
            id: row.id,
            eventName: row.eventName,
            properties: _decodeProperties(row.propertiesJson),
            occurredAt: row.occurredAt,
            sessionId: row.sessionId,
            installId: row.installId,
            attemptCount: row.attemptCount,
          ),
        )
        .toList(growable: false);
  }

  Future<void> markAttempted(List<String> ids) async {
    if (ids.isEmpty) return;
    final now = _clock();
    await _db.transaction(() async {
      for (final id in ids) {
        final row = await (_db.select(
          _db.analyticsEvents,
        )..where((row) => row.id.equals(id))).getSingleOrNull();
        if (row == null) continue;
        await (_db.update(
          _db.analyticsEvents,
        )..where((row) => row.id.equals(id))).write(
          AnalyticsEventsCompanion(
            attemptCount: Value(row.attemptCount + 1),
            lastAttemptAt: Value(now),
          ),
        );
      }
    });
  }

  Future<void> markUploaded(List<String> ids) async {
    if (ids.isEmpty) return;
    await (_db.delete(
      _db.analyticsEvents,
    )..where((row) => row.id.isIn(ids))).go();
    await _upsertPreference(
      _analyticsLastFlushAtPreferenceKey,
      _clock().toIso8601String(),
    );
  }

  Future<void> markFailed(List<String> ids) async {
    if (ids.isEmpty) return;
    await (_db.update(
      _db.analyticsEvents,
    )..where((row) => row.id.isIn(ids))).write(
      AnalyticsEventsCompanion(
        uploadState: Value(AnalyticsUploadState.failed.name),
        lastAttemptAt: Value(_clock()),
      ),
    );
  }

  Future<void> clearPendingEvents() async {
    await _db.delete(_db.analyticsEvents).go();
  }

  Future<void> clearAnalyticsPreferences() async {
    await (_db.delete(_db.appPreferences)..where(
          (row) => row.key.isIn([
            _analyticsConsentPreferenceKey,
            _analyticsInstallIdPreferenceKey,
            _analyticsLastFlushAtPreferenceKey,
          ]),
        ))
        .go();
  }

  Future<String?> _fetchPreference(String key) async {
    final row = await (_db.select(
      _db.appPreferences,
    )..where((row) => row.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _upsertPreference(String key, String value) async {
    await _db
        .into(_db.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            key: key,
            value: value,
            updatedAt: _clock(),
          ),
        );
  }

  Future<void> _deletePreference(String key) async {
    await (_db.delete(
      _db.appPreferences,
    )..where((row) => row.key.equals(key))).go();
  }

  DateTime _clock() => (_now ?? DateTime.now)().toUtc();
}

class UsageAnalyticsService {
  UsageAnalyticsService({
    required UsageAnalyticsRepository repository,
    required UsageAnalyticsUploader uploader,
    String? sessionId,
  }) : _repository = repository,
       _uploader = uploader,
       _sessionId = sessionId ?? _uuid.v4(),
       _disabled = false;

  UsageAnalyticsService.disabled()
    : _repository = null,
      _uploader = null,
      _sessionId = '',
      _disabled = true;

  final UsageAnalyticsRepository? _repository;
  final UsageAnalyticsUploader? _uploader;
  final String _sessionId;
  final bool _disabled;
  Future<void>? _activeFlush;

  Future<AnalyticsConsent> fetchConsent() async =>
      _disabled ? AnalyticsConsent.disabled : _repository!.fetchConsent();

  Future<void> setConsent(AnalyticsConsent consent) =>
      _disabled ? Future.value() : _repository!.setConsent(consent);

  Future<void> track(
    UsageAnalyticsEvent event, {
    Map<String, Object?> properties = const {},
  }) async {
    if (_disabled) return;
    final repository = _repository!;
    if (await repository.fetchConsent() != AnalyticsConsent.enabled) return;

    final sanitized = sanitizeAnalyticsProperties(event, properties);
    final installId = await repository.ensureInstallId();
    await repository.enqueue(
      event: event,
      properties: sanitized,
      sessionId: _sessionId,
      installId: installId,
    );
    unawaited(flush());
  }

  Future<void> flush() {
    if (_disabled) return Future<void>.value();
    final activeFlush = _activeFlush;
    if (activeFlush != null) return activeFlush;

    late final Future<void> nextFlush;
    nextFlush = _flush().whenComplete(() {
      if (identical(_activeFlush, nextFlush)) {
        _activeFlush = null;
      }
    });
    _activeFlush = nextFlush;
    return nextFlush;
  }

  Future<void> _flush() async {
    final repository = _repository!;
    final uploader = _uploader!;
    if (await repository.fetchConsent() != AnalyticsConsent.enabled) return;

    final events = await repository.pendingEvents();
    final ids = events.map((event) => event.id).toList(growable: false);
    try {
      if (events.isEmpty) return;
      await repository.markAttempted(ids);
      await uploader.upload(events);
      await repository.markUploaded(ids);
    } catch (_) {
      await repository.markFailed(ids);
    }
  }
}

abstract class UsageAnalyticsUploader {
  Future<void> upload(List<PendingAnalyticsEvent> events);
}

class SupabaseUsageAnalyticsUploader implements UsageAnalyticsUploader {
  const SupabaseUsageAnalyticsUploader([this._client]);

  final SupabaseClient? _client;

  @override
  Future<void> upload(List<PendingAnalyticsEvent> events) async {
    if (events.isEmpty) return;
    final client = _client ?? Supabase.instance.client;
    await client.functions.invoke(
      'usage-analytics',
      body: {
        'app_version': '0.1.0+1',
        'platform': currentAnalyticsPlatform(),
        'events': [
          for (final event in events)
            {
              'id': event.id,
              'event_name': event.eventName,
              'properties': event.properties,
              'occurred_at': event.occurredAt.toIso8601String(),
              'session_id': event.sessionId,
              'install_id': event.installId,
            },
        ],
      },
    );
  }
}

Map<String, Object?> sanitizeAnalyticsProperties(
  UsageAnalyticsEvent event,
  Map<String, Object?> properties,
) {
  final schema = _allowedProperties[event] ?? const <String, Object>{};
  final sanitized = <String, Object?>{};
  for (final entry in properties.entries) {
    final rule = schema[entry.key];
    if (rule == null) continue;
    final value = entry.value;
    if (rule == bool && value is bool) {
      sanitized[entry.key] = value;
    } else if (rule is Set<String> && value is String && rule.contains(value)) {
      sanitized[entry.key] = value;
    }
  }
  return sanitized;
}

String analyticsCountBucket(int count) {
  if (count <= 0) return '0';
  if (count == 1) return '1';
  if (count <= 3) return '2-3';
  if (count <= 5) return '4-5';
  if (count <= 10) return '6-10';
  return '11+';
}

String analyticsEventCountBucket(int count) {
  if (count <= 1) return '1';
  if (count <= 3) return '2-3';
  if (count <= 5) return '4-5';
  if (count <= 10) return '6-10';
  return '11+';
}

String currentAnalyticsPlatform() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.linux => 'linux',
    TargetPlatform.windows => 'windows',
    _ => 'unknown',
  };
}

Map<String, Object?> _decodeProperties(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) return const {};
  return Map<String, Object?>.from(decoded);
}
