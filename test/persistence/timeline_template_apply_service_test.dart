import 'package:medo/models.dart';
import 'package:medo/persistence/app_database.dart';
import 'package:medo/persistence/persistence_providers.dart';
import 'package:medo/persistence/plan_repository.dart';
import 'package:medo/persistence/timeline_template_apply_service.dart';
import 'package:medo/persistence/timeline_template_repository.dart';
import 'package:medo/state.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  TimelineState samplePlanState() {
    return const TimelineState(
      targetTime: 13 * 60,
      targetTimeTitle: '現在の目標',
      selectedBlockId: 'sel-1',
      preciseDraggingId: 'drag-1',
      activeInlineEditorId: 'edit-1',
      blocks: [
        Block(
          id: 'plan-block-1',
          type: BlockType.action,
          title: '現在の行動',
          duration: 20,
          colorIndex: 0,
        ),
      ],
    );
  }

  TimelineState sampleTemplateState() {
    return const TimelineState(
      targetTime: 9 * 60,
      targetTimeTitle: 'テンプレート目標',
      blocks: [
        Block(
          id: 'tmpl-block-1',
          type: BlockType.action,
          title: 'テンプレート行動',
          duration: 30,
          colorIndex: 2,
        ),
        Block(
          id: 'tmpl-block-2',
          type: BlockType.actionPoint,
          title: 'テンプレートポイント',
          duration: 0,
          colorIndex: 3,
        ),
      ],
    );
  }

  Future<void> _setupPlanAndTemplate() async {
    final planRepo = container.read(planRepositoryProvider);
    final templateRepo = container.read(timelineTemplateRepositoryProvider);

    final plan = await planRepo.createPlan(
      state: samplePlanState(),
      createInitialSnapshot: false,
    );
    final template = await templateRepo.createTemplate(
      state: sampleTemplateState(),
      title: '朝の準備テンプレート',
    );

    container.read(currentPlanIdProvider.notifier).set(plan.id);
    container.read(timelineProvider.notifier).loadState(samplePlanState());

    return;
  }

  test('throws when no current plan is loaded', () async {
    final service = container.read(timelineTemplateApplyServiceProvider);
    expect(
      () => service.applyTemplate('any-id'),
      throwsA(isA<StateError>()),
    );
  });

  test('applies template state with fresh block IDs and clears transient UI state',
      () async {
    await _setupPlanAndTemplate();

    final templateRepo = container.read(timelineTemplateRepositoryProvider);
    final templates = await templateRepo.listTemplates();
    final templateId = templates.single.id;

    final service = container.read(timelineTemplateApplyServiceProvider);
    await service.applyTemplate(templateId);

    final currentState = container.read(timelineProvider);

    // Template content applied
    expect(currentState.targetTime, 9 * 60);
    expect(currentState.targetTimeTitle, 'テンプレート目標');
    expect(currentState.blocks, hasLength(2));
    expect(currentState.blocks.first.title, 'テンプレート行動');
    expect(currentState.blocks.last.title, 'テンプレートポイント');

    // Transient UI state cleared
    expect(currentState.selectedBlockId, isNull);
    expect(currentState.preciseDraggingId, isNull);
    expect(currentState.activeInlineEditorId, isNull);

    // Block IDs are fresh (different from original template block IDs)
    expect(currentState.blocks.first.id, isNot('tmpl-block-1'));
    expect(currentState.blocks.last.id, isNot('tmpl-block-2'));
  });

  test('creates a before-apply snapshot', () async {
    await _setupPlanAndTemplate();

    final planRepo = container.read(planRepositoryProvider);
    final planId = container.read(currentPlanIdProvider)!;

    final templateRepo = container.read(timelineTemplateRepositoryProvider);
    final templates = await templateRepo.listTemplates();
    final templateId = templates.single.id;

    final service = container.read(timelineTemplateApplyServiceProvider);
    await service.applyTemplate(templateId);

    final snapshots = await planRepo.listSnapshots(planId);
    final beforeSnapshots = snapshots
        .where((s) => s.label == 'Before template apply')
        .toList();
    expect(beforeSnapshots, hasLength(1));

    final loaded = await planRepo.loadSnapshot(beforeSnapshots.single.id);
    expect(loaded, isNotNull);
    expect(loaded!.state.targetTimeTitle, '現在の目標');
    expect(loaded.state.blocks.single.id, 'plan-block-1');
  });

  test('persists the applied state to the current plan', () async {
    await _setupPlanAndTemplate();

    final planRepo = container.read(planRepositoryProvider);
    final planId = container.read(currentPlanIdProvider)!;

    final templateRepo = container.read(timelineTemplateRepositoryProvider);
    final templates = await templateRepo.listTemplates();
    final templateId = templates.single.id;

    final service = container.read(timelineTemplateApplyServiceProvider);
    await service.applyTemplate(templateId);

    final loadedPlan = await planRepo.loadPlan(planId);
    expect(loadedPlan, isNotNull);
    expect(loadedPlan!.state.targetTime, 9 * 60);
    expect(loadedPlan.state.targetTimeTitle, 'テンプレート目標');
    expect(loadedPlan.state.blocks, hasLength(2));
    expect(loadedPlan.state.blocks.first.title, 'テンプレート行動');
  });

  test('applies an empty-blocks template', () async {
    final planRepo = container.read(planRepositoryProvider);
    final templateRepo = container.read(timelineTemplateRepositoryProvider);

    final plan = await planRepo.createPlan(
      state: samplePlanState(),
      createInitialSnapshot: false,
    );
    final emptyTemplate = await templateRepo.createTemplate(
      state: const TimelineState(
        targetTime: 15 * 60,
        targetTimeTitle: '空テンプレート',
        blocks: [],
      ),
    );

    container.read(currentPlanIdProvider.notifier).set(plan.id);
    container.read(timelineProvider.notifier).loadState(samplePlanState());

    final service = container.read(timelineTemplateApplyServiceProvider);
    await service.applyTemplate(emptyTemplate.id);

    final currentState = container.read(timelineProvider);
    expect(currentState.blocks, isEmpty);
    expect(currentState.targetTime, 15 * 60);
    expect(currentState.selectedBlockId, isNull);

    final loadedPlan = await planRepo.loadPlan(plan.id);
    expect(loadedPlan!.state.blocks, isEmpty);
  });
}
