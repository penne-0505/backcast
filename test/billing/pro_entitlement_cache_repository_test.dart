import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medo/billing/pro_entitlement_cache_repository.dart';
import 'package:medo/billing/pro_entitlement_repository.dart';
import 'package:medo/persistence/app_database.dart';

void main() {
  late AppDatabase db;
  late ProEntitlementCacheRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = ProEntitlementCacheRepository(
      db,
      now: () => DateTime.utc(2026, 5, 11, 12),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('returns null when no cached entitlement exists', () async {
    expect(await repository.fetch('user-1'), isNull);
  });

  test('saves and replaces a cached entitlement snapshot', () async {
    await repository.save(
      'user-1',
      ProEntitlementState(
        isPro: true,
        status: 'active',
        productId: 'medo_pro_monthly',
        expiresAt: DateTime.utc(2026, 6),
        lastSyncedAt: DateTime.utc(2026, 5, 10),
      ),
    );

    final cachedPro = await repository.fetch('user-1');
    expect(cachedPro, isNotNull);
    expect(cachedPro!.isPro, isTrue);
    expect(cachedPro.status, 'active');
    expect(cachedPro.productId, 'medo_pro_monthly');
    expect(cachedPro.expiresAt?.toUtc(), DateTime.utc(2026, 6));
    expect(cachedPro.lastSyncedAt?.toUtc(), DateTime.utc(2026, 5, 10));

    await repository.save('user-1', const ProEntitlementState.free());

    final cachedFree = await repository.fetch('user-1');
    expect(cachedFree, isNotNull);
    expect(cachedFree!.isPro, isFalse);
    expect(cachedFree.status, 'inactive');
    expect(cachedFree.productId, isNull);
    expect(cachedFree.lastSyncedAt?.toUtc(), DateTime.utc(2026, 5, 11, 12));
  });

  test('clears every cached entitlement snapshot', () async {
    await repository.save(
      'user-1',
      const ProEntitlementState(
        isPro: true,
        status: 'active',
        productId: 'medo_pro_monthly',
      ),
    );
    await repository.save('user-2', const ProEntitlementState.free());

    await repository.clearAll();

    expect(await repository.fetch('user-1'), isNull);
    expect(await repository.fetch('user-2'), isNull);
  });
}
