import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../state.dart';
import 'app_database.dart';
import 'timeline_state_codec.dart';

const _uuid = Uuid();

class TimelinePlanSummary {
  const TimelinePlanSummary({
    required this.id,
    required this.title,
    required this.targetTime,
    required this.targetTimeTitle,
    required this.blockCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final int targetTime;
  final String targetTimeTitle;
  final int blockCount;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TimelinePlan {
  const TimelinePlan({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.state,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TimelineState state;
}

class TimelineSnapshotSummary {
  const TimelineSnapshotSummary({
    required this.id,
    required this.planId,
    required this.label,
    required this.createdAt,
  });

  final String id;
  final String planId;
  final String? label;
  final DateTime createdAt;
}

class TimelineSnapshot {
  const TimelineSnapshot({
    required this.id,
    required this.planId,
    required this.label,
    required this.createdAt,
    required this.state,
  });

  final String id;
  final String planId;
  final String? label;
  final DateTime createdAt;
  final TimelineState state;
}

class PlanRepository {
  PlanRepository(this._db, {DateTime Function()? now}) : _now = now;

  final AppDatabase _db;
  final DateTime Function()? _now;

  Future<TimelinePlan> createPlan({
    required TimelineState state,
    String? title,
    bool createInitialSnapshot = true,
  }) async {
    final planId = _uuid.v4();
    final planTitle = title ?? _defaultPlanTitle(state);
    final now = _clock();

    return _db.transaction(() async {
      await _db
          .into(_db.plans)
          .insert(
            PlansCompanion.insert(
              id: planId,
              title: planTitle,
              targetTime: state.targetTime,
              targetTimeTitle: state.targetTimeTitle,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _replaceBlocks(planId, state.blocks);

      if (createInitialSnapshot) {
        await _insertSnapshot(
          planId: planId,
          state: state,
          createdAt: now,
          label: 'Initial save',
        );
      }

      return TimelinePlan(
        id: planId,
        title: planTitle,
        createdAt: now,
        updatedAt: now,
        state: _stateForPersistence(state),
      );
    });
  }

  Future<List<TimelinePlanSummary>> listPlans() async {
    final rows = await (_db.select(
      _db.plans,
    )..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])).get();

    final summaries = <TimelinePlanSummary>[];
    for (final row in rows) {
      summaries.add(
        TimelinePlanSummary(
          id: row.id,
          title: row.title,
          targetTime: row.targetTime,
          targetTimeTitle: row.targetTimeTitle,
          blockCount: await _countBlocks(row.id),
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        ),
      );
    }
    return summaries;
  }

  Future<TimelinePlan?> loadPlan(String planId) async {
    final plan = await (_db.select(
      _db.plans,
    )..where((row) => row.id.equals(planId))).getSingleOrNull();
    if (plan == null) return null;

    final blocks =
        await (_db.select(_db.planBlocks)
              ..where((row) => row.planId.equals(planId))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();

    return TimelinePlan(
      id: plan.id,
      title: plan.title,
      createdAt: plan.createdAt,
      updatedAt: plan.updatedAt,
      state: TimelineState(
        targetTime: plan.targetTime,
        targetTimeTitle: plan.targetTimeTitle,
        blocks: blocks.map(_blockFromRow).toList(growable: false),
      ),
    );
  }

  Future<void> savePlan({
    required String planId,
    required TimelineState state,
    String? title,
    bool createSnapshot = true,
    String? snapshotLabel,
  }) async {
    final existing = await (_db.select(
      _db.plans,
    )..where((row) => row.id.equals(planId))).getSingleOrNull();
    if (existing == null) {
      throw StateError('Plan not found: $planId');
    }

    final now = _clock();
    await _db.transaction(() async {
      await (_db.update(
        _db.plans,
      )..where((row) => row.id.equals(planId))).write(
        PlansCompanion(
          title: title == null ? const Value.absent() : Value(title),
          targetTime: Value(state.targetTime),
          targetTimeTitle: Value(state.targetTimeTitle),
          updatedAt: Value(now),
        ),
      );
      await _replaceBlocks(planId, state.blocks);

      if (createSnapshot) {
        await _insertSnapshot(
          planId: planId,
          state: state,
          createdAt: now,
          label: snapshotLabel,
        );
      }
    });
  }

  Future<void> deletePlan(String planId) async {
    await (_db.delete(_db.plans)..where((row) => row.id.equals(planId))).go();
  }

  Future<String> createSnapshot({
    required String planId,
    required TimelineState state,
    String? label,
  }) async {
    final existing = await (_db.select(
      _db.plans,
    )..where((row) => row.id.equals(planId))).getSingleOrNull();
    if (existing == null) {
      throw StateError('Plan not found: $planId');
    }

    return _insertSnapshot(
      planId: planId,
      state: state,
      createdAt: _clock(),
      label: label,
    );
  }

  Future<List<TimelineSnapshotSummary>> listSnapshots(String planId) async {
    final rows =
        await (_db.select(_db.planSnapshots)
              ..where((row) => row.planId.equals(planId))
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
            .get();

    return rows
        .map(
          (row) => TimelineSnapshotSummary(
            id: row.id,
            planId: row.planId,
            label: row.label,
            createdAt: row.createdAt,
          ),
        )
        .toList(growable: false);
  }

  Future<TimelineSnapshot?> loadSnapshot(String snapshotId) async {
    final row = await (_db.select(
      _db.planSnapshots,
    )..where((row) => row.id.equals(snapshotId))).getSingleOrNull();
    if (row == null) return null;

    return TimelineSnapshot(
      id: row.id,
      planId: row.planId,
      label: row.label,
      createdAt: row.createdAt,
      state: decodeTimelineState(row.stateJson),
    );
  }

  Future<void> restoreSnapshot({
    required String snapshotId,
    bool createSnapshotBeforeRestore = true,
  }) async {
    final snapshot = await loadSnapshot(snapshotId);
    if (snapshot == null) {
      throw StateError('Snapshot not found: $snapshotId');
    }

    final current = await loadPlan(snapshot.planId);
    if (current == null) {
      throw StateError('Plan not found: ${snapshot.planId}');
    }

    if (createSnapshotBeforeRestore) {
      await createSnapshot(
        planId: current.id,
        state: current.state,
        label: 'Before restore',
      );
    }

    await savePlan(
      planId: snapshot.planId,
      state: snapshot.state,
      createSnapshot: true,
      snapshotLabel: 'Restored from ${snapshot.createdAt.toIso8601String()}',
    );
  }

  DateTime _clock() => (_now ?? DateTime.now)().toUtc();

  String _defaultPlanTitle(TimelineState state) {
    final title = state.targetTimeTitle.trim();
    return title.isEmpty ? 'Untitled plan' : title;
  }

  TimelineState _stateForPersistence(TimelineState state) {
    return TimelineState(
      targetTime: state.targetTime,
      targetTimeTitle: state.targetTimeTitle,
      blocks: List<Block>.unmodifiable(state.blocks),
    );
  }

  Future<int> _countBlocks(String planId) async {
    final count = _db.planBlocks.id.count();
    final query = _db.selectOnly(_db.planBlocks)
      ..addColumns([count])
      ..where(_db.planBlocks.planId.equals(planId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> _replaceBlocks(String planId, List<Block> blocks) async {
    await (_db.delete(
      _db.planBlocks,
    )..where((row) => row.planId.equals(planId))).go();

    await _db.batch((batch) {
      final companions = <PlanBlocksCompanion>[];
      for (var i = 0; i < blocks.length; i++) {
        final block = blocks[i];
        companions.add(
          PlanBlocksCompanion.insert(
            id: block.id,
            planId: planId,
            type: block.type.name,
            title: block.title,
            duration: block.duration,
            colorIndex: block.colorIndex,
            position: i,
          ),
        );
      }
      batch.insertAll(_db.planBlocks, companions);
    });
  }

  Future<String> _insertSnapshot({
    required String planId,
    required TimelineState state,
    required DateTime createdAt,
    required String? label,
  }) async {
    final snapshotId = _uuid.v4();
    await _db
        .into(_db.planSnapshots)
        .insert(
          PlanSnapshotsCompanion.insert(
            id: snapshotId,
            planId: planId,
            label: Value(label),
            stateJson: encodeTimelineState(state),
            createdAt: createdAt,
          ),
        );
    return snapshotId;
  }

  Block _blockFromRow(PlanBlock row) {
    final type = BlockType.values
        .where((value) => value.name == row.type)
        .firstOrNull;
    if (type == null) {
      throw FormatException('Unsupported persisted block type: ${row.type}');
    }

    return Block(
      id: row.id,
      type: type,
      title: row.title,
      duration: row.duration,
      colorIndex: row.colorIndex,
    );
  }
}
