import 'package:medo/main.dart';
import 'package:medo/block_item.dart';
import 'package:medo/billing/gate_helper.dart';
import 'package:medo/models.dart';
import 'package:medo/persistence/app_database.dart';
import 'package:medo/persistence/persistence_providers.dart';
import 'package:medo/persistence/plan_repository.dart';
import 'package:medo/state.dart';
import 'package:medo/timeline_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

late AppDatabase db;

Future<void> pumpMedoApp(WidgetTester tester, {bool? effectiveIsPro}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        if (effectiveIsPro != null)
          effectiveIsProProvider.overrideWithValue(effectiveIsPro),
      ],
      child: const MedoApp(),
    ),
  );
  await tester.pump();
}

ProviderContainer containerFor(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(MedoApp)));
}

void main() {
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });
  // ---------------------------------------------------------------------------
  // Unit tests: computeBlocks pure function
  // ---------------------------------------------------------------------------

  group('computeBlocks', () {
    test('empty blocks returns empty list', () {
      final result = computeBlocks([], 13 * 60);
      expect(result, isEmpty);
    });

    test('single block: startTime = targetTime - duration', () {
      final blocks = [
        const Block(
          id: '1',
          type: BlockType.action,
          title: 'A',
          duration: 30,
          colorIndex: 0,
        ),
      ];
      final result = computeBlocks(blocks, 13 * 60);
      expect(result.length, 1);
      expect(result[0].endTime, 13 * 60);
      expect(result[0].startTime, 13 * 60 - 30);
    });

    test('action buffer extends the effective duration', () {
      final blocks = [
        const Block(
          id: '1',
          type: BlockType.action,
          title: 'A',
          duration: 30,
          bufferMinutes: 10,
          colorIndex: 0,
        ),
      ];
      final result = computeBlocks(blocks, 13 * 60);
      expect(result.length, 1);
      expect(result[0].block.duration, 30);
      expect(result[0].block.normalizedBufferMinutes, 10);
      expect(result[0].block.effectiveDuration, 40);
      expect(result[0].endTime, 13 * 60);
      expect(result[0].startTime, 13 * 60 - 40);
    });

    test('multiple blocks chain correctly', () {
      final blocks = [
        const Block(
          id: '1',
          type: BlockType.action,
          title: 'A',
          duration: 30,
          colorIndex: 0,
        ),
        const Block(
          id: '2',
          type: BlockType.action,
          title: 'B',
          duration: 20,
          colorIndex: 1,
        ),
      ];
      final result = computeBlocks(blocks, 13 * 60);
      // Block B ends at target, starts at target-20
      expect(result[1].endTime, 13 * 60);
      expect(result[1].startTime, 13 * 60 - 20);
      // Block A ends where B starts
      expect(result[0].endTime, 13 * 60 - 20);
      expect(result[0].startTime, 13 * 60 - 20 - 30);
    });

    test('point block has zero duration', () {
      final blocks = [
        const Block(
          id: '1',
          type: BlockType.actionPoint,
          title: 'P',
          duration: 0,
          bufferMinutes: 15,
          colorIndex: 0,
        ),
      ];
      final result = computeBlocks(blocks, 10 * 60);
      expect(result[0].block.normalizedBufferMinutes, 0);
      expect(result[0].startTime, 10 * 60);
      expect(result[0].endTime, 10 * 60);
    });
  });

  group('TimelineNotifier action buffer', () {
    test('increments, clamps, and ignores action points', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(timelineProvider.notifier);
      notifier.loadState(
        const TimelineState(
          blocks: [
            Block(
              id: 'a1',
              type: BlockType.action,
              title: '移動',
              duration: 20,
              colorIndex: 0,
            ),
            Block(
              id: 'p1',
              type: BlockType.actionPoint,
              title: '受付',
              duration: 0,
              colorIndex: 1,
            ),
          ],
        ),
      );

      notifier.incrementActionBuffer('a1');
      expect(container.read(timelineProvider).blocks[0].bufferMinutes, 5);

      notifier.setActionBufferMinutes('a1', 99);
      expect(
        container.read(timelineProvider).blocks[0].bufferMinutes,
        kMaxActionBufferMinutes,
      );

      notifier.incrementActionBuffer('a1');
      expect(
        container.read(timelineProvider).blocks[0].bufferMinutes,
        kMaxActionBufferMinutes,
      );

      notifier.setActionBufferMinutes('p1', 30);
      expect(
        container.read(timelineProvider).blocks[1].normalizedBufferMinutes,
        0,
      );
    });

    test('start-time editing keeps buffer separate from action duration', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(timelineProvider.notifier);
      notifier.loadState(
        const TimelineState(
          targetTime: 13 * 60,
          blocks: [
            Block(
              id: 'a1',
              type: BlockType.action,
              title: '移動',
              duration: 20,
              bufferMinutes: 10,
              colorIndex: 0,
            ),
          ],
        ),
      );

      notifier.applyStartTimeEdit('a1', 12 * 60 + 20);

      final block = container.read(timelineProvider).blocks.single;
      expect(block.duration, 30);
      expect(block.bufferMinutes, 10);
      expect(block.effectiveDuration, 40);
    });
  });

  // ---------------------------------------------------------------------------
  // Unit tests: formatTime
  // ---------------------------------------------------------------------------

  group('formatTime', () {
    test('formats 0 as 00:00', () => expect(formatTime(0), '00:00'));
    test('formats 780 as 13:00', () => expect(formatTime(780), '13:00'));
    test(
      'wraps negative values correctly',
      () => expect(formatTime(-60), '23:00'),
    );
    test(
      'wraps over 24h correctly',
      () => expect(formatTime(25 * 60), '01:00'),
    );
  });

  // ---------------------------------------------------------------------------
  // Widget smoke test
  // ---------------------------------------------------------------------------

  testWidgets('renders header and target anchor', (tester) async {
    await pumpMedoApp(tester);

    expect(find.text('目標時刻'), findsOneWidget);
    expect(find.text('前の行動を追加しましょう'), findsOneWidget);
  });

  testWidgets('header keeps only the export plan action', (tester) async {
    await pumpMedoApp(tester);

    expect(find.byIcon(PhosphorIcons.floppyDisk()), findsNothing);
    expect(find.byIcon(PhosphorIcons.folderOpen()), findsNothing);
    expect(find.byIcon(PhosphorIcons.calendarBlank()), findsOneWidget);

    await tester.tap(find.byIcon(PhosphorIcons.calendarBlank()));
    await tester.pumpAndSettle();

    expect(find.text('エクスポート'), findsOneWidget);
    expect(find.text('現在の状態を保存'), findsNothing);
    expect(find.text('プランを読み込む'), findsNothing);
    expect(find.text('カレンダーにエクスポート'), findsOneWidget);
    expect(find.text('テキストで共有'), findsOneWidget);
    expect(find.text('画像で共有'), findsOneWidget);
  });

  testWidgets(
    'inline editing consumes the next block tap before opening edit sheet',
    (tester) async {
      await pumpMedoApp(tester);

      await tester.tap(find.text('前の行動を追加'));
      await tester.pump();

      await tester.tap(find.text('新しい行動'));
      await tester.pump();

      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(find.text('行動を編集'), findsNothing);

      final blockCenter = tester.getCenter(find.byType(BlockItem));
      await tester.tapAt(blockCenter);
      await tester.pumpAndSettle();

      expect(tester.testTextInput.hasAnyClients, isFalse);
      expect(find.text('行動を編集'), findsNothing);

      await tester.tapAt(blockCenter);
      await tester.pumpAndSettle();

      expect(find.text('行動を編集'), findsOneWidget);
    },
  );

  testWidgets('double tapping an action body adds Pro buffer time', (
    tester,
  ) async {
    await pumpMedoApp(tester, effectiveIsPro: true);

    await tester.tap(find.text('前の行動を追加'));
    await tester.pump();

    final blockRect = tester.getRect(find.byType(BlockItem));
    final bodyPosition = Offset(blockRect.left + 120, blockRect.bottom - 14);

    await tester.tapAt(bodyPosition);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(bodyPosition);
    await tester.pumpAndSettle();

    final block = containerFor(tester).read(timelineProvider).blocks.single;
    expect(block.bufferMinutes, 5);
    expect(find.text('余裕 +5分'), findsOneWidget);
    expect(find.text('行動を編集'), findsNothing);
  });

  testWidgets(
    'double tapping an action body shows a locked snack for Free users',
    (tester) async {
      await pumpMedoApp(tester, effectiveIsPro: false);

      await tester.tap(find.text('前の行動を追加'));
      await tester.pump();

      final blockRect = tester.getRect(find.byType(BlockItem));
      final bodyPosition = Offset(blockRect.left + 120, blockRect.bottom - 14);

      await tester.tapAt(bodyPosition);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tapAt(bodyPosition);
      await tester.pumpAndSettle();

      expect(
        containerFor(tester).read(timelineProvider).blocks.single.bufferMinutes,
        0,
      );
      expect(find.text('余裕時間の編集はPro機能です'), findsNothing);
      expect(find.text('余裕時間の追加はProで使えます'), findsOneWidget);
      final snackTop = tester.getTopLeft(find.byType(SnackBar)).dy;
      expect(snackTop, greaterThan(58));
      expect(snackTop, lessThan(140));
      expect(find.text('行動を編集'), findsNothing);
    },
  );

  testWidgets('detail sheet buffer stepper edits buffer for Pro users', (
    tester,
  ) async {
    await pumpMedoApp(tester, effectiveIsPro: true);

    await tester.tap(find.text('前の行動を追加'));
    await tester.pump();

    await tester.tapAt(tester.getCenter(find.byType(BlockItem)));
    await tester.pumpAndSettle();

    expect(find.text('行動を編集'), findsOneWidget);
    expect(find.text('余裕時間'), findsOneWidget);

    await tester.tap(find.byIcon(PhosphorIcons.plus()).last);
    await tester.pumpAndSettle();

    final block = containerFor(tester).read(timelineProvider).blocks.single;
    expect(block.bufferMinutes, 5);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('detail sheet preserves existing buffer for Free users', (
    tester,
  ) async {
    await pumpMedoApp(tester, effectiveIsPro: false);
    containerFor(tester)
        .read(timelineProvider.notifier)
        .loadState(
          const TimelineState(
            blocks: [
              Block(
                id: 'buffered',
                type: BlockType.action,
                title: '移動',
                duration: 20,
                bufferMinutes: 10,
                colorIndex: 0,
              ),
            ],
          ),
        );
    await tester.pump();

    containerFor(
      tester,
    ).read(timelineProvider.notifier).selectBlock('buffered');
    await tester.pumpAndSettle();

    expect(find.text('行動を編集'), findsOneWidget);
    expect(find.text('10分'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);

    await tester.tap(find.text('10分'));
    await tester.pumpAndSettle();

    final block = containerFor(tester).read(timelineProvider).blocks.single;
    expect(block.bufferMinutes, 10);
    expect(find.text('余裕時間の編集はPro機能です'), findsOneWidget);
  });

  testWidgets(
    'drag handle enters precise mode after hold and allows 1-minute adjustment',
    (tester) async {
      await pumpMedoApp(tester);

      await tester.tap(find.text('前の行動を追加'));
      await tester.pump();

      expect(find.text('15分'), findsOneWidget);

      final blockRect = tester.getRect(find.byType(BlockItem));
      final handlePosition = Offset(blockRect.center.dx, blockRect.top + 8);

      final gesture = await tester.startGesture(handlePosition);
      await tester.pump(const Duration(milliseconds: 450));
      await gesture.moveBy(const Offset(0, -6));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('16分'), findsOneWidget);
    },
  );

  testWidgets('right swipe deletes an action block', (tester) async {
    await pumpMedoApp(tester);

    await tester.tap(find.text('前の行動を追加'));
    await tester.pump();

    expect(find.text('新しい行動'), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('新しい行動'), findsNothing);
    expect(containerFor(tester).read(timelineProvider).blocks, isEmpty);
  });

  testWidgets('short right swipe does not delete an action block', (
    tester,
  ) async {
    await pumpMedoApp(tester);

    await tester.tap(find.text('前の行動を追加'));
    await tester.pump();

    expect(find.text('新しい行動'), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(find.text('新しい行動'), findsOneWidget);
    expect(containerFor(tester).read(timelineProvider).blocks, hasLength(1));
  });

  testWidgets('right swipe deletes an action point', (tester) async {
    await pumpMedoApp(tester);
    containerFor(tester)
        .read(timelineProvider.notifier)
        .loadState(
          const TimelineState(
            blocks: [
              Block(
                id: 'point-1',
                type: BlockType.actionPoint,
                title: '受付',
                duration: 0,
                colorIndex: 0,
              ),
            ],
          ),
        );
    await tester.pump();

    expect(find.text('受付'), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('受付'), findsNothing);
    expect(containerFor(tester).read(timelineProvider).blocks, isEmpty);
  });

  testWidgets('timeline island modal opens from floating button', (
    tester,
  ) async {
    final repo = PlanRepository(db);
    final first = await repo.createPlan(
      state: const TimelineState(targetTimeTitle: '出発'),
      title: '朝の予定',
    );
    await repo.createPlan(
      state: const TimelineState(targetTimeTitle: '帰宅'),
      title: '夜の予定',
    );
    await repo.saveCurrentPlanId(first.id);

    await pumpMedoApp(tester, effectiveIsPro: false);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIcons.stack()));
    await tester.pumpAndSettle();

    expect(find.byType(TimelineListIslandModal), findsOneWidget);
    expect(find.text('朝の予定'), findsOneWidget);
    expect(find.text('夜の予定'), findsOneWidget);
    expect(find.text('Freeは2件まで'), findsOneWidget);
  });

  testWidgets('timeline island creates a named timeline from the top form', (
    tester,
  ) async {
    final repo = PlanRepository(db);
    final first = await repo.createPlan(
      state: const TimelineState(targetTimeTitle: '出発'),
      title: '朝の予定',
    );
    await repo.saveCurrentPlanId(first.id);

    await pumpMedoApp(tester, effectiveIsPro: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIcons.stack()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新しいタイムライン'));
    await tester.pumpAndSettle();

    expect(find.text('タイムライン名'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '昼の予定');
    await tester.tap(find.text('作成'));
    await tester.pumpAndSettle();

    expect(find.text('昼の予定'), findsOneWidget);
    final currentId = containerFor(tester).read(currentPlanIdProvider);
    final current = await repo.loadPlan(currentId!);
    expect(current!.title, '昼の予定');
  });

  testWidgets('timeline island creates an untitled timeline from blank input', (
    tester,
  ) async {
    final repo = PlanRepository(db);
    final first = await repo.createPlan(
      state: const TimelineState(targetTimeTitle: '出発'),
      title: '朝の予定',
    );
    await repo.saveCurrentPlanId(first.id);

    await pumpMedoApp(tester, effectiveIsPro: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIcons.stack()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新しいタイムライン'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作成'));
    await tester.pumpAndSettle();

    expect(find.text('無題のタイムライン'), findsOneWidget);
    final currentId = containerFor(tester).read(currentPlanIdProvider);
    final current = await repo.loadPlan(currentId!);
    expect(current!.title, '無題のタイムライン');
  });

  testWidgets('timeline island renames an existing timeline inline', (
    tester,
  ) async {
    final repo = PlanRepository(db);
    final first = await repo.createPlan(
      state: const TimelineState(targetTimeTitle: '出発'),
      title: '朝の予定',
    );
    await repo.saveCurrentPlanId(first.id);

    await pumpMedoApp(tester, effectiveIsPro: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIcons.stack()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('timeline-rename-${first.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '朝の支度');
    await tester.tap(
      find.byKey(ValueKey('timeline-rename-submit-${first.id}')),
    );
    await tester.pumpAndSettle();

    expect(find.text('朝の支度'), findsOneWidget);
    final renamed = await repo.loadPlan(first.id);
    expect(renamed!.title, '朝の支度');
  });

  testWidgets('timeline island renames blank input to untitled timeline', (
    tester,
  ) async {
    final repo = PlanRepository(db);
    final first = await repo.createPlan(
      state: const TimelineState(targetTimeTitle: '出発'),
      title: '朝の予定',
    );
    await repo.saveCurrentPlanId(first.id);

    await pumpMedoApp(tester, effectiveIsPro: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIcons.stack()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('timeline-rename-${first.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '   ');
    await tester.tap(
      find.byKey(ValueKey('timeline-rename-submit-${first.id}')),
    );
    await tester.pumpAndSettle();

    expect(find.text('無題のタイムライン'), findsOneWidget);
    final renamed = await repo.loadPlan(first.id);
    expect(renamed!.title, '無題のタイムライン');
  });

  testWidgets('timeline island deletes a non-current timeline', (tester) async {
    final repo = PlanRepository(db);
    final first = await repo.createPlan(
      state: const TimelineState(targetTimeTitle: '出発'),
      title: '朝の予定',
    );
    final second = await repo.createPlan(
      state: const TimelineState(targetTimeTitle: '帰宅'),
      title: '夜の予定',
    );
    await repo.saveCurrentPlanId(first.id);

    await pumpMedoApp(tester, effectiveIsPro: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIcons.stack()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('timeline-delete-${second.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('タイムラインを削除しますか？'), findsOneWidget);
    await tester.tap(find.text('削除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('夜の予定'), findsNothing);
    expect(containerFor(tester).read(currentPlanIdProvider), first.id);
    expect(await repo.loadPlan(second.id), isNull);
  });

  testWidgets(
    'timeline island deleting current timeline switches to remaining',
    (tester) async {
      final repo = PlanRepository(db);
      final first = await repo.createPlan(
        state: const TimelineState(targetTimeTitle: '出発'),
        title: '朝の予定',
      );
      final second = await repo.createPlan(
        state: const TimelineState(targetTimeTitle: '帰宅'),
        title: '夜の予定',
      );
      await repo.saveCurrentPlanId(first.id);

      await pumpMedoApp(tester, effectiveIsPro: true);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(PhosphorIcons.stack()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('timeline-delete-${first.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('削除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(containerFor(tester).read(currentPlanIdProvider), second.id);
      expect(find.text('帰宅'), findsOneWidget);
      expect(await repo.loadPlan(first.id), isNull);
    },
  );

  testWidgets('timeline island deleting the last timeline creates a fallback', (
    tester,
  ) async {
    final repo = PlanRepository(db);
    final first = await repo.createPlan(
      state: const TimelineState(targetTimeTitle: '出発'),
      title: '朝の予定',
    );
    await repo.saveCurrentPlanId(first.id);

    await pumpMedoApp(tester, effectiveIsPro: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIcons.stack()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('timeline-delete-${first.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('削除'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('無題のタイムライン'), findsOneWidget);
    expect(containerFor(tester).read(currentPlanIdProvider), isNot(first.id));
  });

  testWidgets(
    'timeline switch flushes pending edits before loading next plan',
    (tester) async {
      final repo = PlanRepository(db);
      final first = await repo.createPlan(
        state: const TimelineState(targetTimeTitle: '出発'),
        title: '朝の予定',
      );
      final second = await repo.createPlan(
        state: const TimelineState(targetTimeTitle: '帰宅'),
        title: '夜の予定',
      );
      await repo.saveCurrentPlanId(first.id);

      await pumpMedoApp(tester, effectiveIsPro: true);
      await tester.pumpAndSettle();

      await tester.tap(find.text('前の行動を追加'));
      await tester.pump();
      await tester.tap(find.byIcon(PhosphorIcons.stack()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('夜の予定'));
      await tester.pumpAndSettle();

      expect(containerFor(tester).read(currentPlanIdProvider), second.id);
      expect(find.text('帰宅'), findsOneWidget);

      final savedFirst = await repo.loadPlan(first.id);
      expect(savedFirst!.state.blocks.map((block) => block.title), ['新しい行動']);
    },
  );

  testWidgets('startup fallback persists a replacement current plan id', (
    tester,
  ) async {
    final repo = PlanRepository(db);
    final first = await repo.createPlan(
      state: const TimelineState(targetTimeTitle: '出発'),
      title: '朝の予定',
    );
    final second = await repo.createPlan(
      state: const TimelineState(targetTimeTitle: '帰宅'),
      title: '夜の予定',
    );
    await repo.saveCurrentPlanId(first.id);
    await repo.deletePlan(first.id);

    await pumpMedoApp(tester, effectiveIsPro: true);
    await tester.pumpAndSettle();

    expect(containerFor(tester).read(currentPlanIdProvider), second.id);
    expect(await repo.loadCurrentPlanId(), second.id);
  });

  testWidgets('timeline island fits a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = PlanRepository(db);
    final first = await repo.createPlan(
      state: const TimelineState(targetTimeTitle: '出発'),
      title: '朝の予定',
    );
    await repo.createPlan(
      state: const TimelineState(targetTimeTitle: '帰宅'),
      title: '夜の予定',
    );
    await repo.saveCurrentPlanId(first.id);

    await pumpMedoApp(tester, effectiveIsPro: false);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIcons.stack()));
    await tester.pumpAndSettle();

    expect(find.byType(TimelineListIslandModal), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
