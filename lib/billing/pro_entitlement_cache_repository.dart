import 'package:drift/drift.dart';

import '../persistence/app_database.dart';
import 'pro_entitlement_repository.dart';

class ProEntitlementCacheRepository {
  const ProEntitlementCacheRepository(this._db, {DateTime Function()? now})
    : _now = now;

  final AppDatabase _db;
  final DateTime Function()? _now;

  Future<ProEntitlementState?> fetch(String userId) async {
    final row = await (_db.select(
      _db.cachedProEntitlements,
    )..where((table) => table.userId.equals(userId))).getSingleOrNull();

    if (row == null) return null;
    return ProEntitlementState(
      isPro: row.isPro,
      status: row.status,
      productId: row.productId,
      expiresAt: row.expiresAt,
      lastSyncedAt: row.lastSyncedAt ?? row.cachedAt,
    );
  }

  Future<void> save(String userId, ProEntitlementState entitlement) async {
    await _db
        .into(_db.cachedProEntitlements)
        .insertOnConflictUpdate(
          CachedProEntitlementsCompanion(
            userId: Value(userId),
            isPro: Value(entitlement.isPro),
            status: Value(entitlement.status),
            productId: Value(entitlement.productId),
            expiresAt: Value(entitlement.expiresAt),
            lastSyncedAt: Value(entitlement.lastSyncedAt),
            cachedAt: Value((_now ?? DateTime.now)()),
          ),
        );
  }

  Future<void> clearAll() async {
    await _db.delete(_db.cachedProEntitlements).go();
  }
}
