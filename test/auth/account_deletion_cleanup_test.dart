import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medo/analytics/usage_analytics.dart';
import 'package:medo/auth/account_deletion_cleanup.dart';
import 'package:medo/billing/pro_entitlement_cache_repository.dart';
import 'package:medo/billing/pro_entitlement_repository.dart';
import 'package:medo/models.dart';
import 'package:medo/notifications/reminder_notifications.dart';
import 'package:medo/persistence/app_database.dart';
import 'package:medo/persistence/plan_repository.dart';
import 'package:medo/persistence/timeline_template_repository.dart';
import 'package:medo/state.dart';

void main() {
  late AppDatabase db;
  late PlanRepository planRepository;
  late TimelineTemplateRepository templateRepository;
  late ProEntitlementCacheRepository proCacheRepository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    planRepository = PlanRepository(
      db,
      now: () => DateTime.utc(2026, 5, 12, 9),
    );
    templateRepository = TimelineTemplateRepository(
      db,
      now: () => DateTime.utc(2026, 5, 12, 9),
    );
    proCacheRepository = ProEntitlementCacheRepository(
      db,
      now: () => DateTime.utc(2026, 5, 12, 9),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'clears local user data, pro cache, preferences, and notifications',
    () async {
      final plan = await planRepository.createPlan(
        state: _sampleState(),
        title: '削除対象の予定',
      );
      await planRepository.saveCurrentPlanId(plan.id);
      await templateRepository.createTemplate(
        state: _sampleStateWithBlockId('template-block'),
        title: '削除対象のテンプレート',
      );
      await proCacheRepository.save(
        'user-1',
        const ProEntitlementState(
          isPro: true,
          status: 'active',
          productId: 'medo_pro_monthly',
        ),
      );

      final notificationClient = _FakeReminderNotificationClient();
      final localData = LocalAccountDataCleanupRepository(db);
      final analytics = UsageAnalyticsRepository(db);
      await analytics.setConsent(AnalyticsConsent.enabled);
      await analytics.enqueue(
        event: UsageAnalyticsEvent.appOpened,
        properties: const {
          'launch_source': 'cold_start',
          'platform': 'android',
        },
        sessionId: 'session-1',
        installId: 'install-1',
      );
      final cleanup = AccountDeletionLocalCleanup(
        localData: localData,
        analytics: analytics,
        proCache: proCacheRepository,
        notificationScheduler: ReminderNotificationScheduler(
          client: notificationClient,
        ),
        deleteShareTemporaryFiles: () async {},
      );

      await cleanup.markPending();
      expect(await localData.hasPendingAccountDeletionCleanup(), isTrue);

      await cleanup.run();

      expect(await planRepository.listPlans(), isEmpty);
      expect(await templateRepository.listTemplates(), isEmpty);
      expect(await planRepository.loadCurrentPlanId(), isNull);
      expect(await analytics.pendingEvents(), isEmpty);
      expect(await analytics.fetchConsent(), AnalyticsConsent.disabled);
      expect(await proCacheRepository.fetch('user-1'), isNull);
      expect(await localData.hasPendingAccountDeletionCleanup(), isFalse);
      expect(notificationClient.cancelAllCount, 1);
    },
  );

  test('keeps pending cleanup marker when critical cleanup fails', () async {
    final notificationClient = _FakeReminderNotificationClient(
      cancelAllError: StateError('notification failure'),
    );
    final localData = LocalAccountDataCleanupRepository(db);
    final cleanup = AccountDeletionLocalCleanup(
      localData: localData,
      analytics: UsageAnalyticsRepository(db),
      proCache: proCacheRepository,
      notificationScheduler: ReminderNotificationScheduler(
        client: notificationClient,
      ),
      deleteShareTemporaryFiles: () async {},
    );

    await cleanup.markPending();

    await expectLater(
      cleanup.run(),
      throwsA(isA<AccountDeletionLocalCleanupException>()),
    );

    expect(await localData.hasPendingAccountDeletionCleanup(), isTrue);
  });
}

TimelineState _sampleState() => _sampleStateWithBlockId('block-1');

TimelineState _sampleStateWithBlockId(String blockId) {
  return TimelineState(
    targetTime: 9 * 60,
    targetTimeTitle: '会議開始',
    blocks: [
      Block(
        id: blockId,
        type: BlockType.action,
        title: '移動',
        duration: 30,
        colorIndex: 1,
      ),
    ],
  );
}

class _FakeReminderNotificationClient implements ReminderNotificationClient {
  _FakeReminderNotificationClient({this.cancelAllError});

  final Object? cancelAllError;
  var cancelAllCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> schedule(ReminderNotificationPlan plan) async {}

  @override
  Future<void> cancel(int notificationId) async {}

  @override
  Future<void> cancelAll() async {
    cancelAllCount += 1;
    final error = cancelAllError;
    if (error != null) {
      throw error;
    }
  }
}
