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
          colorIndex: 0,
        ),
      ];
      final result = computeBlocks(blocks, 10 * 60);
      expect(result[0].startTime, 10 * 60);
      expect(result[0].endTime, 10 * 60);
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
}
