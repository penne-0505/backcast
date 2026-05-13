import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medo/analytics/usage_analytics.dart';
import 'package:medo/persistence/app_database.dart';

void main() {
  late AppDatabase db;
  late UsageAnalyticsRepository repository;
  late _FakeUsageAnalyticsUploader uploader;
  late UsageAnalyticsService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = UsageAnalyticsRepository(
      db,
      now: () => DateTime.utc(2026, 5, 13, 9),
    );
    uploader = _FakeUsageAnalyticsUploader();
    service = UsageAnalyticsService(
      repository: repository,
      uploader: uploader,
      sessionId: '22222222-2222-4222-8222-222222222222',
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('sanitizes unsupported properties before storage', () async {
    await service.setConsent(AnalyticsConsent.enabled);

    await service.track(
      UsageAnalyticsEvent.blockAdded,
      properties: const {
        'block_type': 'action',
        'block_count_bucket': '2-3',
        'title': '朝の準備',
      },
    );
    await service.flush();

    expect(uploader.uploads, hasLength(1));
    expect(uploader.uploads.single.single.properties, {
      'block_type': 'action',
      'block_count_bucket': '2-3',
    });
  });

  test('does not queue events while consent is disabled', () async {
    await service.track(UsageAnalyticsEvent.appOpened);

    expect(await repository.pendingEvents(), isEmpty);
    expect(uploader.uploads, isEmpty);
  });

  test('opt-out clears pending events and install identifier', () async {
    uploader.fail = true;
    await service.setConsent(AnalyticsConsent.enabled);
    await service.track(
      UsageAnalyticsEvent.appOpened,
      properties: const {'launch_source': 'cold_start', 'platform': 'android'},
    );
    await service.flush();

    expect(await repository.pendingEvents(), hasLength(1));

    await service.setConsent(AnalyticsConsent.disabled);

    expect(await repository.pendingEvents(), isEmpty);
    expect(await repository.fetchConsent(), AnalyticsConsent.disabled);
  });

  test('flush removes uploaded events', () async {
    await service.setConsent(AnalyticsConsent.enabled);
    await service.track(
      UsageAnalyticsEvent.appOpened,
      properties: const {'launch_source': 'cold_start', 'platform': 'android'},
    );
    await service.flush();

    expect(uploader.uploads, hasLength(1));
    expect(await repository.pendingEvents(), isEmpty);
  });

  test('track returns before background upload completes', () async {
    final uploadStarted = Completer<void>();
    final uploadGate = Completer<void>();
    uploader.uploadStarted = uploadStarted;
    uploader.uploadGate = uploadGate;
    await service.setConsent(AnalyticsConsent.enabled);

    await service
        .track(
          UsageAnalyticsEvent.appOpened,
          properties: const {
            'launch_source': 'cold_start',
            'platform': 'android',
          },
        )
        .timeout(const Duration(milliseconds: 100));
    await uploadStarted.future.timeout(const Duration(milliseconds: 100));

    final rows = await _analyticsRows(db);
    expect(rows, hasLength(1));
    expect(rows.single.uploadState, AnalyticsUploadState.pending.name);
    expect(rows.single.attemptCount, 1);

    uploadGate.complete();
    await service.flush();

    expect(await repository.pendingEvents(), isEmpty);
  });

  test('failed uploads remain retryable and increment attempt count', () async {
    uploader.fail = true;
    await service.setConsent(AnalyticsConsent.enabled);
    await service.track(
      UsageAnalyticsEvent.appOpened,
      properties: const {'launch_source': 'cold_start', 'platform': 'android'},
    );
    await service.flush();

    var rows = await _analyticsRows(db);
    expect(rows, hasLength(1));
    expect(rows.single.uploadState, AnalyticsUploadState.failed.name);
    expect(rows.single.attemptCount, 1);

    uploader.fail = false;
    await service.flush();

    expect(uploader.uploads, hasLength(2));
    expect(await repository.pendingEvents(), isEmpty);
  });

  test('bucket helpers classify boundary values', () {
    expect(analyticsCountBucket(0), '0');
    expect(analyticsCountBucket(1), '1');
    expect(analyticsCountBucket(3), '2-3');
    expect(analyticsCountBucket(5), '4-5');
    expect(analyticsCountBucket(10), '6-10');
    expect(analyticsCountBucket(11), '11+');

    expect(analyticsEventCountBucket(0), '1');
    expect(analyticsEventCountBucket(3), '2-3');
    expect(analyticsEventCountBucket(10), '6-10');
    expect(analyticsEventCountBucket(11), '11+');
  });
}

Future<List<AnalyticsEvent>> _analyticsRows(AppDatabase db) {
  return db.select(db.analyticsEvents).get();
}

class _FakeUsageAnalyticsUploader implements UsageAnalyticsUploader {
  bool fail = false;
  Completer<void>? uploadStarted;
  Completer<void>? uploadGate;
  final uploads = <List<PendingAnalyticsEvent>>[];

  @override
  Future<void> upload(List<PendingAnalyticsEvent> events) async {
    uploads.add(List<PendingAnalyticsEvent>.from(events));
    uploadStarted?.complete();
    final gate = uploadGate;
    if (gate != null) {
      await gate.future;
    }
    if (fail) {
      throw StateError('upload failed');
    }
  }
}
