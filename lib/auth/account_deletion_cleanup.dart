import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../billing/pro_entitlement_cache_repository.dart';
import '../notifications/reminder_notifications.dart';
import '../persistence/app_database.dart';
import '../persistence/persistence_providers.dart';
import 'share_temporary_file_cleanup.dart';

const _pendingAccountDeletionCleanupKey = 'pendingAccountDeletionCleanup';

final accountDeletionLocalCleanupProvider =
    Provider<AccountDeletionLocalCleanup>((ref) {
      final db = ref.watch(databaseProvider);
      final shareCleanup = const ShareTemporaryFileCleanup();
      return AccountDeletionLocalCleanup(
        localData: LocalAccountDataCleanupRepository(db),
        proCache: ProEntitlementCacheRepository(db),
        notificationScheduler: ReminderNotificationScheduler(),
        deleteShareTemporaryFiles: shareCleanup.deleteShareTemporaryFiles,
      );
    });

class AccountDeletionLocalCleanup {
  const AccountDeletionLocalCleanup({
    required LocalAccountDataCleanupRepository localData,
    required ProEntitlementCacheRepository proCache,
    required ReminderNotificationScheduler notificationScheduler,
    required Future<void> Function() deleteShareTemporaryFiles,
  }) : _localData = localData,
       _proCache = proCache,
       _notificationScheduler = notificationScheduler,
       _deleteShareTemporaryFiles = deleteShareTemporaryFiles;

  final LocalAccountDataCleanupRepository _localData;
  final ProEntitlementCacheRepository _proCache;
  final ReminderNotificationScheduler _notificationScheduler;
  final Future<void> Function() _deleteShareTemporaryFiles;

  Future<void> markPending() => _localData.markAccountDeletionCleanupPending();

  Future<bool> hasPendingCleanup() =>
      _localData.hasPendingAccountDeletionCleanup();

  Future<void> run() async {
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } catch (e, st) {
        firstError ??= e;
        firstStackTrace ??= st;
      }
    }

    await attempt(_localData.clearUserCreatedData);
    await attempt(_proCache.clearAll);
    await attempt(_notificationScheduler.cancelAllReminderNotifications);

    try {
      await _deleteShareTemporaryFiles();
    } catch (_) {
      // Temporary share files are best-effort cleanup. Core account deletion
      // should not be blocked by an OS-level temp directory failure.
    }

    final error = firstError;
    if (error != null) {
      Error.throwWithStackTrace(
        AccountDeletionLocalCleanupException(error),
        firstStackTrace ?? StackTrace.current,
      );
    }

    await _localData.clearAppPreferences();
  }
}

class AccountDeletionLocalCleanupException implements Exception {
  const AccountDeletionLocalCleanupException(this.cause);

  final Object cause;

  @override
  String toString() => 'Account deletion local cleanup failed: $cause';
}

class LocalAccountDataCleanupRepository {
  const LocalAccountDataCleanupRepository(this._db);

  final AppDatabase _db;

  Future<void> markAccountDeletionCleanupPending() async {
    await _db
        .into(_db.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            key: _pendingAccountDeletionCleanupKey,
            value: 'true',
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<bool> hasPendingAccountDeletionCleanup() async {
    final row =
        await (_db.select(_db.appPreferences)..where(
              (table) => table.key.equals(_pendingAccountDeletionCleanupKey),
            ))
            .getSingleOrNull();
    return row?.value == 'true';
  }

  Future<void> clearUserCreatedData() async {
    await _db.transaction(() async {
      await _db.delete(_db.planBlocks).go();
      await _db.delete(_db.planSnapshots).go();
      await _db.delete(_db.plans).go();
      await _db.delete(_db.timelineTemplateBlocks).go();
      await _db.delete(_db.timelineTemplates).go();
    });
  }

  Future<void> clearAppPreferences() async {
    await _db.delete(_db.appPreferences).go();
  }
}
