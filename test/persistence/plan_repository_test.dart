import 'package:medo/models.dart';
import 'package:medo/persistence/app_database.dart';
import 'package:medo/persistence/plan_repository.dart';
import 'package:medo/persistence/timeline_state_codec.dart';
import 'package:medo/state.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PlanRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = PlanRepository(db, now: () => DateTime.utc(2026, 4, 23, 12));
  });

  tearDown(() async {
    await db.close();
  });

  TimelineState sampleState() {
    return const TimelineState(
      targetTime: 9 * 60,
      targetTimeTitle: '会議開始',
      selectedBlockId: 'transient-selection',
      preciseDraggingId: 'transient-drag',
      activeInlineEditorId: 'transient-editor',
      blocks: [
        Block(
          id: 'block-1',
          type: BlockType.action,
          title: '移動',
          duration: 30,
          bufferMinutes: 10,
          colorIndex: 1,
        ),
        Block(
          id: 'block-2',
          type: BlockType.actionPoint,
          title: '受付',
          duration: 0,
          colorIndex: 2,
        ),
      ],
    );
  }

  TimelineState sampleStateWithBlockSuffix(String suffix) {
    return sampleState().copyWith(
      blocks: sampleState().blocks
          .map((block) => block.copyWith(id: '${block.id}-$suffix'))
          .toList(growable: false),
    );
  }

  test('codec preserves persistent state and clears transient UI state', () {
    final restored = decodeTimelineState(encodeTimelineState(sampleState()));

    expect(restored.targetTime, 9 * 60);
    expect(restored.targetTimeTitle, '会議開始');
    expect(restored.blocks, sampleState().blocks);
    expect(restored.selectedBlockId, isNull);
    expect(restored.preciseDraggingId, isNull);
    expect(restored.activeInlineEditorId, isNull);
  });

  test('codec reads older snapshots without bufferMinutes as zero buffer', () {
    final restored = timelineStateFromJson({
      'schemaVersion': 1,
      'targetTime': 9 * 60,
      'targetTimeTitle': '会議開始',
      'blocks': [
        {
          'id': 'block-1',
          'type': BlockType.action.name,
          'title': '移動',
          'duration': 30,
          'colorIndex': 1,
        },
      ],
    });

    expect(restored.blocks.single.bufferMinutes, 0);
    expect(restored.blocks.single.effectiveDuration, 30);
  });

  test('creates, lists, and loads a plan with ordered blocks', () async {
    final created = await repository.createPlan(
      state: sampleState(),
      title: '朝の準備',
    );

    final summaries = await repository.listPlans();
    expect(summaries, hasLength(1));
    expect(summaries.single.id, created.id);
    expect(summaries.single.title, '朝の準備');
    expect(summaries.single.blockCount, 2);

    final loaded = await repository.loadPlan(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.title, '朝の準備');
    expect(loaded.state.targetTimeTitle, '会議開始');
    expect(loaded.state.blocks.map((block) => block.id), [
      'block-1',
      'block-2',
    ]);
    expect(loaded.state.blocks.first.bufferMinutes, 10);
    expect(loaded.state.selectedBlockId, isNull);

    final snapshots = await repository.listSnapshots(created.id);
    expect(snapshots, hasLength(1));
    expect(snapshots.single.label, 'Initial save');
  });

  test('saves current plan and records snapshot history', () async {
    final created = await repository.createPlan(
      state: sampleState(),
      createInitialSnapshot: false,
    );

    final updatedState = sampleState().copyWith(
      targetTime: 10 * 60,
      blocks: [
        const Block(
          id: 'block-3',
          type: BlockType.action,
          title: '資料確認',
          duration: 20,
          colorIndex: 3,
        ),
      ],
    );

    await repository.savePlan(
      planId: created.id,
      state: updatedState,
      title: '更新済みプラン',
      snapshotLabel: 'After edit',
    );

    final loaded = await repository.loadPlan(created.id);
    expect(loaded!.title, '更新済みプラン');
    expect(loaded.state.targetTime, 10 * 60);
    expect(loaded.state.blocks.single.title, '資料確認');

    final snapshots = await repository.listSnapshots(created.id);
    expect(snapshots, hasLength(1));
    expect(snapshots.single.label, 'After edit');

    final snapshot = await repository.loadSnapshot(snapshots.single.id);
    expect(snapshot!.state.blocks.single.id, 'block-3');
  });

  test('persists action buffer to plan rows and snapshots', () async {
    final state = sampleState().copyWith(
      blocks: const [
        Block(
          id: 'buffered',
          type: BlockType.action,
          title: '移動',
          duration: 10,
          bufferMinutes: 15,
          colorIndex: 0,
        ),
      ],
    );
    final created = await repository.createPlan(state: state, title: '余裕あり');

    final loaded = await repository.loadPlan(created.id);
    expect(loaded!.state.blocks.single.bufferMinutes, 15);
    expect(loaded.state.blocks.single.normalizedBufferMinutes, 5);
    expect(loaded.state.blocks.single.effectiveDuration, 15);

    final snapshots = await repository.listSnapshots(created.id);
    final snapshot = await repository.loadSnapshot(snapshots.single.id);
    expect(snapshot!.state.blocks.single.bufferMinutes, 15);
    expect(snapshot.state.blocks.single.normalizedBufferMinutes, 5);
  });

  test('restores a plan from a saved snapshot', () async {
    final initialState = sampleState();
    final created = await repository.createPlan(
      state: initialState,
      createInitialSnapshot: false,
    );
    final snapshotId = await repository.createSnapshot(
      planId: created.id,
      state: initialState,
      label: 'Before changes',
    );

    await repository.savePlan(
      planId: created.id,
      state: initialState.copyWith(blocks: const []),
      createSnapshot: false,
    );
    expect((await repository.loadPlan(created.id))!.state.blocks, isEmpty);

    await repository.restoreSnapshot(
      snapshotId: snapshotId,
      createSnapshotBeforeRestore: false,
    );

    final restored = await repository.loadPlan(created.id);
    expect(restored!.state.blocks, initialState.blocks);
    expect(restored.state.targetTimeTitle, '会議開始');
  });

  test('persists and validates the current plan id preference', () async {
    final first = await repository.createPlan(
      state: sampleState(),
      title: '最初のタイムライン',
    );
    final second = await repository.createPlan(
      state: sampleStateWithBlockSuffix(
        'second',
      ).copyWith(targetTimeTitle: '帰宅'),
      title: '次のタイムライン',
    );

    await repository.saveCurrentPlanId(first.id);
    expect(await repository.loadCurrentPlanId(), first.id);

    await repository.saveCurrentPlanId(second.id);
    expect(await repository.loadCurrentPlanId(), second.id);
  });

  test('counts saved plans for Free timeline gate decisions', () async {
    expect(await repository.countPlans(), 0);

    await repository.createPlan(
      state: sampleStateWithBlockSuffix('a'),
      title: 'A',
    );
    await repository.createPlan(
      state: sampleStateWithBlockSuffix('b'),
      title: 'B',
    );

    expect(await repository.countPlans(), 2);
  });

  test('renames a plan without changing blocks or snapshots', () async {
    var now = DateTime.utc(2026, 4, 23, 12);
    repository = PlanRepository(db, now: () => now);
    final created = await repository.createPlan(
      state: sampleState(),
      title: '旧名前',
    );
    final before = await repository.listPlans();
    final snapshotsBefore = await repository.listSnapshots(created.id);

    now = DateTime.utc(2026, 4, 23, 13);
    await repository.renamePlan(created.id, ' 新しい名前 ');

    final loaded = await repository.loadPlan(created.id);
    expect(loaded!.title, '新しい名前');
    expect(loaded.state.blocks.map((block) => block.title), ['移動', '受付']);

    final after = await repository.listPlans();
    expect(after.single.updatedAt, isNot(before.single.updatedAt));
    expect(after.single.blockCount, 2);
    final snapshotsAfter = await repository.listSnapshots(created.id);
    expect(snapshotsAfter.map((snapshot) => snapshot.id), [
      snapshotsBefore.single.id,
    ]);
  });

  test('renames blank plan title to untitled timeline', () async {
    final created = await repository.createPlan(
      state: sampleState(),
      title: '旧名前',
    );

    await repository.renamePlan(created.id, '   ');

    final loaded = await repository.loadPlan(created.id);
    expect(loaded!.title, '無題のタイムライン');
  });

  test('renamePlan throws StateError when plan does not exist', () async {
    expect(
      () => repository.renamePlan('missing-plan', '新しい名前'),
      throwsA(isA<StateError>()),
    );
  });
}
