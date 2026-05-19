import 'package:medo/main.dart';
import 'package:medo/block_item.dart';
import 'package:medo/billing/gate_helper.dart';
import 'package:medo/models.dart';
import 'package:medo/persistence/app_database.dart';
import 'package:medo/persistence/persistence_providers.dart';
import 'package:medo/persistence/plan_repository.dart';
import 'package:medo/plan_panel.dart';
import 'package:medo/state.dart';
import 'package:medo/theme.dart';
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
          effectiveProAccessProvider.overrideWithValue(
            effectiveIsPro
                ? const ProAccessState.pro()
                : const ProAccessState.free(),
          ),
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
      expect(container.read(timelineProvider).blocks[0].bufferMinutes, 15);

      notifier.incrementActionBuffer('a1');
      expect(container.read(timelineProvider).blocks[0].bufferMinutes, 15);

      notifier.setActionBufferMinutes('p1', 30);
      expect(
        container.read(timelineProvider).blocks[1].normalizedBufferMinutes,
        0,
      );
    });

    test('duration clamp keeps desired buffer for later recovery', () {
      const block = Block(
        id: 'a1',
        type: BlockType.action,
        title: '移動',
        duration: 20,
        bufferMinutes: 60,
        colorIndex: 0,
      );

      expect(block.normalizedBufferMinutes, 15);
      expect(block.effectiveDuration, 35);

      final shortened = block.copyWith(duration: 10);
      expect(shortened.bufferMinutes, 60);
      expect(shortened.normalizedBufferMinutes, 5);
      expect(shortened.effectiveDuration, 15);

      final restored = shortened.copyWith(duration: 20);
      expect(restored.bufferMinutes, 60);
      expect(restored.normalizedBufferMinutes, 15);
      expect(restored.effectiveDuration, 35);
    });

    test('type toggle preserves raw duration and buffer for recovery', () {
      const block = Block(
        id: 'a1',
        type: BlockType.action,
        title: '移動',
        duration: 20,
        bufferMinutes: 10,
        colorIndex: 0,
      );

      final point = block.copyWith(type: BlockType.actionPoint);
      expect(point.duration, 20);
      expect(point.bufferMinutes, 10);
      expect(point.normalizedBufferMinutes, 0);
      expect(point.effectiveDuration, 0);

      final restored = point.copyWith(type: BlockType.action);
      expect(restored.duration, 20);
      expect(restored.bufferMinutes, 10);
      expect(restored.normalizedBufferMinutes, 10);
      expect(restored.effectiveDuration, 30);
    });

    test('notifier restores action settings when toggling a point back', () {
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
              bufferMinutes: 10,
              colorIndex: 0,
            ),
          ],
        ),
      );

      notifier.setBlockType('a1', BlockType.actionPoint);
      var block = container.read(timelineProvider).blocks.single;
      expect(block.type, BlockType.actionPoint);
      expect(block.duration, 20);
      expect(block.bufferMinutes, 10);
      expect(block.effectiveDuration, 0);

      notifier.setBlockType('a1', BlockType.action);
      block = container.read(timelineProvider).blocks.single;
      expect(block.type, BlockType.action);
      expect(block.duration, 20);
      expect(block.bufferMinutes, 10);
      expect(block.effectiveDuration, 30);
    });

    test(
      'notifier gives legacy zero-duration point a default action duration',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(timelineProvider.notifier);
        notifier.loadState(
          const TimelineState(
            blocks: [
              Block(
                id: 'p1',
                type: BlockType.actionPoint,
                title: '受付',
                duration: 0,
                bufferMinutes: 10,
                colorIndex: 0,
              ),
            ],
          ),
        );

        notifier.setBlockType('p1', BlockType.action);
        final block = container.read(timelineProvider).blocks.single;
        expect(block.type, BlockType.action);
        expect(block.duration, 15);
        expect(block.bufferMinutes, 10);
        expect(block.effectiveDuration, 25);
      },
    );

    test('manual buffer edit clears pending buffer recovery', () {
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
              duration: 10,
              bufferMinutes: 15,
              colorIndex: 0,
            ),
          ],
        ),
      );

      expect(
        container.read(timelineProvider).blocks.single.normalizedBufferMinutes,
        5,
      );

      notifier.setActionBufferMinutes('a1', 0);
      final edited = container.read(timelineProvider).blocks.single;
      expect(edited.bufferMinutes, 0);
      expect(edited.normalizedBufferMinutes, 0);
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

    test('restores a deleted block at the original clamped index', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(timelineProvider.notifier);
      const deleted = Block(
        id: 'deleted',
        type: BlockType.action,
        title: '削除した行動',
        duration: 20,
        colorIndex: 1,
      );
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
          ],
        ),
      );

      notifier.restoreDeletedBlock(deleted, 99);

      final state = container.read(timelineProvider);
      expect(state.blocks.map((b) => b.id), ['a1', 'deleted']);
      expect(state.selectedBlockId, isNull);

      notifier.restoreDeletedBlock(deleted, 0);
      expect(container.read(timelineProvider).blocks, hasLength(2));
    });
  });

  group('TimelineNotifier block ordering', () {
    test('moveBlockByIndex reorders blocks and clamps the target index', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(timelineProvider.notifier);
      notifier.loadState(
        const TimelineState(
          blocks: [
            Block(
              id: 'first',
              type: BlockType.action,
              title: '最初',
              duration: 10,
              colorIndex: 0,
            ),
            Block(
              id: 'second',
              type: BlockType.action,
              title: '次',
              duration: 10,
              colorIndex: 1,
            ),
            Block(
              id: 'third',
              type: BlockType.action,
              title: '最後',
              duration: 10,
              colorIndex: 2,
            ),
          ],
        ),
      );

      notifier.moveBlockByIndex(0, 99);

      expect(container.read(timelineProvider).blocks.map((block) => block.id), [
        'second',
        'third',
        'first',
      ]);
    });
  });

  group('current time rail marker positioning', () {
    test('places marker inside the current action block', () {
      const blocks = [
        Block(
          id: 'early-action',
          type: BlockType.action,
          title: '早い行動',
          duration: 30,
          colorIndex: 0,
        ),
        Block(
          id: 'mid-point',
          type: BlockType.actionPoint,
          title: '通過点',
          duration: 0,
          colorIndex: 1,
        ),
        Block(
          id: 'late-action',
          type: BlockType.action,
          title: '遅い行動',
          duration: 30,
          colorIndex: 2,
        ),
      ];
      final computed = computeBlocks(blocks, 13 * 60);

      final offset = currentTimelineMarkerOffsetForBlock(
        computedBlock: computed[0],
        currentTimelineMinute: 12 * 60 + 15,
        visualHeight: timelineBlockVisualHeight(
          computed[0].block,
          kPixelsPerMinute,
        ),
      );

      expect(offset, 15 * kPixelsPerMinute);
      expect(
        currentTimelineMarkerOffsetForBlock(
          computedBlock: computed[1],
          currentTimelineMinute: 12 * 60 + 15,
          visualHeight: kTimelinePointBlockVisualHeight,
        ),
        isNull,
      );
    });

    test('uses the previous action at an exact boundary between actions', () {
      const blocks = [
        Block(
          id: 'early-action',
          type: BlockType.action,
          title: '早い行動',
          duration: 30,
          colorIndex: 0,
        ),
        Block(
          id: 'late-action',
          type: BlockType.action,
          title: '遅い行動',
          duration: 30,
          colorIndex: 1,
        ),
      ];
      final computed = computeBlocks(blocks, 13 * 60);

      expect(
        currentTimelineMarkerOffsetForBlock(
          computedBlock: computed[0],
          currentTimelineMinute: 12 * 60 + 30,
          visualHeight: timelineBlockVisualHeight(
            computed[0].block,
            kPixelsPerMinute,
          ),
        ),
        30 * kPixelsPerMinute,
      );
      expect(
        currentTimelineMarkerOffsetForBlock(
          computedBlock: computed[1],
          currentTimelineMinute: 12 * 60 + 30,
          visualHeight: timelineBlockVisualHeight(
            computed[1].block,
            kPixelsPerMinute,
          ),
        ),
        isNull,
      );
    });

    test(
      'normalizes late-night current time into an after-midnight action',
      () {
        const blocks = [
          Block(
            id: 'night-action',
            type: BlockType.action,
            title: '深夜の行動',
            duration: 60,
            colorIndex: 0,
          ),
        ];
        final computed = computeBlocks(blocks, 30);
        final currentTimelineMinute = normalizeTimelineMinuteNearTarget(
          minutes: 23 * 60 + 45,
          targetTime: 30,
        );

        final offset = currentTimelineMarkerOffsetForBlock(
          computedBlock: computed[0],
          currentTimelineMinute: currentTimelineMinute,
          visualHeight: timelineBlockVisualHeight(
            computed[0].block,
            kPixelsPerMinute,
          ),
        );

        expect(currentTimelineMinute, -15);
        expect(offset, 15 * kPixelsPerMinute);
      },
    );

    test('marks an action point only when current time equals the point', () {
      const blocks = [
        Block(
          id: 'point',
          type: BlockType.actionPoint,
          title: '通過点',
          duration: 0,
          colorIndex: 0,
        ),
      ];
      final computed = computeBlocks(blocks, 12 * 60);

      final offset = currentTimelineMarkerOffsetForBlock(
        computedBlock: computed[0],
        currentTimelineMinute: 12 * 60,
        visualHeight: kTimelinePointBlockVisualHeight,
      );

      expect(offset, kTimelinePointBlockVisualHeight / 2);
      expect(
        currentTimelineMarkerOffsetForBlock(
          computedBlock: computed[0],
          currentTimelineMinute: 12 * 60 + 1,
          visualHeight: kTimelinePointBlockVisualHeight,
        ),
        isNull,
      );
    });
  });

  testWidgets('shows current time as rail marker and current action outline', (
    tester,
  ) async {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final targetTime = (nowMinutes + 30) % (24 * 60);

    await pumpMedoApp(tester);
    containerFor(tester)
        .read(timelineProvider.notifier)
        .loadState(
          TimelineState(
            targetTime: targetTime,
            blocks: const [
              Block(
                id: 'current-action',
                type: BlockType.action,
                title: '現在の行動',
                duration: 60,
                colorIndex: 0,
              ),
            ],
          ),
        );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('current-time-rail-marker:current-action')),
      findsOneWidget,
    );
    expect(find.text('now'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('current-block-border:current-action')),
      findsNothing,
    );
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

  testWidgets('density toggle switches between edit and overview densities', (
    tester,
  ) async {
    await pumpMedoApp(tester);

    expect(find.byIcon(PhosphorIcons.slidersHorizontal()), findsNothing);
    expect(
      containerFor(tester).read(timelineProvider).pixelsPerMinute,
      kPixelsPerMinute,
    );
    expect(
      containerFor(tester).read(timelineProvider).viewMode,
      TimelineViewMode.edit,
    );
    expect(
      tester.getBottomLeft(find.text('目標時刻')).dy,
      lessThan(tester.getTopLeft(find.byIcon(PhosphorIcons.squaresFour())).dy),
    );

    await tester.tap(find.byIcon(PhosphorIcons.squaresFour()));
    await tester.pumpAndSettle();

    expect(
      containerFor(tester).read(timelineProvider).viewMode,
      TimelineViewMode.compact,
    );
    expect(
      containerFor(tester).read(timelineProvider).pixelsPerMinute,
      kOverviewPixelsPerMinute,
    );

    await tester.tap(find.byIcon(PhosphorIcons.listDashes()));
    await tester.pumpAndSettle();

    expect(
      containerFor(tester).read(timelineProvider).viewMode,
      TimelineViewMode.edit,
    );
    expect(
      containerFor(tester).read(timelineProvider).pixelsPerMinute,
      kPixelsPerMinute,
    );
  });

  testWidgets('reorder handle waits for hold before drag preview', (
    tester,
  ) async {
    await pumpMedoApp(tester);
    containerFor(tester)
        .read(timelineProvider.notifier)
        .loadState(
          const TimelineState(
            blocks: [
              Block(
                id: 'other-action',
                type: BlockType.action,
                title: '別の作業',
                duration: 5,
                colorIndex: 1,
              ),
              Block(
                id: 'long-action',
                type: BlockType.action,
                title: '長い作業',
                duration: 5,
                colorIndex: 0,
              ),
            ],
          ),
        );
    await tester.pump();

    final blockItemFinder = find.byType(BlockItem);
    expect(blockItemFinder, findsNWidgets(2));
    final initialPpm = tester
        .widgetList<BlockItem>(blockItemFinder)
        .first
        .pixelsPerMinute;
    final handlePosition = tester.getCenter(
      find.byKey(const ValueKey('reorder-handle:long-action')),
    );

    final gesture = await tester.startGesture(handlePosition);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('reorder-drag-preview:long-action')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('reorder-insertion-line')), findsNothing);
    expect(
      tester.widgetList<BlockItem>(blockItemFinder).first.pixelsPerMinute,
      initialPpm,
    );

    await tester.pump(const Duration(milliseconds: 150));

    expect(
      find.byKey(const ValueKey('reorder-drag-preview:long-action')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('reorder-insertion-line')), findsNothing);
    expect(
      tester.widgetList<BlockItem>(blockItemFinder).first.pixelsPerMinute,
      initialPpm,
    );

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('reorder-drag-preview:long-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reorder-insertion-line')),
      findsOneWidget,
    );
    expect(find.byType(BlockItem), findsOneWidget);
    expect(find.byType(BlockItem, skipOffstage: false), findsNWidgets(2));
    expect(
      tester.widget<BlockItem>(blockItemFinder).pixelsPerMinute,
      initialPpm,
    );
    expect(
      containerFor(tester).read(timelineProvider).pixelsPerMinute,
      kPixelsPerMinute,
    );
    expect(
      containerFor(tester).read(timelineProvider).viewMode,
      TimelineViewMode.edit,
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reorder-drag-preview:long-action')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('reorder-insertion-line')), findsNothing);
    expect(find.byType(BlockItem), findsNWidgets(2));
    expect(
      tester.widgetList<BlockItem>(blockItemFinder).first.pixelsPerMinute,
      initialPpm,
    );
  });

  testWidgets('reorder preview commits the stashed block on pointer up', (
    tester,
  ) async {
    await pumpMedoApp(tester);
    final container = containerFor(tester);
    container
        .read(timelineProvider.notifier)
        .loadState(
          const TimelineState(
            blocks: [
              Block(
                id: 'first-action',
                type: BlockType.action,
                title: '最初の作業',
                duration: 5,
                colorIndex: 0,
              ),
              Block(
                id: 'middle-action',
                type: BlockType.action,
                title: '真ん中の作業',
                duration: 5,
                colorIndex: 1,
              ),
              Block(
                id: 'last-action',
                type: BlockType.action,
                title: '最後の作業',
                duration: 5,
                colorIndex: 2,
              ),
            ],
          ),
        );
    await tester.pump();

    final handlePosition = tester.getCenter(
      find.byKey(const ValueKey('reorder-handle:last-action')),
    );
    final firstHandlePosition = tester.getCenter(
      find.byKey(const ValueKey('reorder-handle:first-action')),
    );

    final gesture = await tester.startGesture(handlePosition);
    await tester.pump(const Duration(milliseconds: 210));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('reorder-drag-preview:last-action')),
      findsOneWidget,
    );
    expect(find.byType(BlockItem), findsNWidgets(2));

    await gesture.moveTo(
      Offset(handlePosition.dx, firstHandlePosition.dy - 80),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(container.read(timelineProvider).blocks.map((block) => block.id), [
      'last-action',
      'first-action',
      'middle-action',
    ]);
    expect(
      find.byKey(const ValueKey('reorder-drag-preview:last-action')),
      findsNothing,
    );
    expect(find.byType(BlockItem), findsNWidgets(3));
  });

  testWidgets(
    'reorder pointer move updates overlay without rebuilding visible blocks',
    (tester) async {
      await pumpMedoApp(tester);
      containerFor(tester)
          .read(timelineProvider.notifier)
          .loadState(
            const TimelineState(
              blocks: [
                Block(
                  id: 'first-action',
                  type: BlockType.action,
                  title: '最初の作業',
                  duration: 5,
                  colorIndex: 0,
                ),
                Block(
                  id: 'middle-action',
                  type: BlockType.action,
                  title: '真ん中の作業',
                  duration: 5,
                  colorIndex: 1,
                ),
                Block(
                  id: 'last-action',
                  type: BlockType.action,
                  title: '最後の作業',
                  duration: 5,
                  colorIndex: 2,
                ),
              ],
            ),
          );
      await tester.pump();

      final handlePosition = tester.getCenter(
        find.byKey(const ValueKey('reorder-handle:last-action')),
      );
      final gesture = await tester.startGesture(handlePosition);
      await tester.pump(const Duration(milliseconds: 210));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('reorder-drag-preview:last-action')),
        findsOneWidget,
      );
      expect(find.byType(BlockItem), findsNWidgets(2));

      final visibleBlocksBefore = tester
          .widgetList<BlockItem>(find.byType(BlockItem))
          .toList(growable: false);
      final insertionLineBefore = tester.widget(
        find.byKey(const ValueKey('reorder-insertion-line')),
      );

      await gesture.moveBy(const Offset(1, 0));
      await tester.pump();

      final visibleBlocksAfter = tester
          .widgetList<BlockItem>(find.byType(BlockItem))
          .toList(growable: false);
      expect(visibleBlocksAfter, hasLength(visibleBlocksBefore.length));
      for (var i = 0; i < visibleBlocksBefore.length; i++) {
        expect(identical(visibleBlocksBefore[i], visibleBlocksAfter[i]), true);
      }
      expect(
        identical(
          insertionLineBefore,
          tester.widget(find.byKey(const ValueKey('reorder-insertion-line'))),
        ),
        true,
      );

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'reorder preview keeps order when released in the original slot',
    (tester) async {
      await pumpMedoApp(tester);
      final container = containerFor(tester);
      container
          .read(timelineProvider.notifier)
          .loadState(
            const TimelineState(
              blocks: [
                Block(
                  id: 'early-action',
                  type: BlockType.action,
                  title: '早い作業',
                  duration: 5,
                  colorIndex: 0,
                ),
                Block(
                  id: 'late-action',
                  type: BlockType.action,
                  title: '遅い作業',
                  duration: 5,
                  colorIndex: 1,
                ),
              ],
            ),
          );
      await tester.pump();

      final handlePosition = tester.getCenter(
        find.byKey(const ValueKey('reorder-handle:late-action')),
      );

      final gesture = await tester.startGesture(handlePosition);
      await tester.pump(const Duration(milliseconds: 210));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('reorder-drag-preview:late-action')),
        findsOneWidget,
      );

      await gesture.up();
      await tester.pumpAndSettle();

      expect(container.read(timelineProvider).blocks.map((block) => block.id), [
        'early-action',
        'late-action',
      ]);
      expect(
        find.byKey(const ValueKey('reorder-drag-preview:late-action')),
        findsNothing,
      );
      expect(find.byType(BlockItem), findsNWidgets(2));
    },
  );

  testWidgets('reorder preview cancels when timeline structure changes', (
    tester,
  ) async {
    await pumpMedoApp(tester);
    final container = containerFor(tester);
    container
        .read(timelineProvider.notifier)
        .loadState(
          const TimelineState(
            blocks: [
              Block(
                id: 'early-action',
                type: BlockType.action,
                title: '早い作業',
                duration: 5,
                colorIndex: 0,
              ),
              Block(
                id: 'late-action',
                type: BlockType.action,
                title: '遅い作業',
                duration: 5,
                colorIndex: 1,
              ),
            ],
          ),
        );
    await tester.pump();

    final handlePosition = tester.getCenter(
      find.byKey(const ValueKey('reorder-handle:late-action')),
    );
    final gesture = await tester.startGesture(handlePosition);
    await tester.pump(const Duration(milliseconds: 210));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('reorder-drag-preview:late-action')),
      findsOneWidget,
    );
    expect(find.byType(BlockItem), findsOneWidget);

    container.read(timelineProvider.notifier).addBlock(0, BlockType.action);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('reorder-drag-preview:late-action')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('reorder-insertion-line')), findsNothing);
    expect(find.byType(BlockItem), findsNWidgets(3));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('reorder handle drag after hold does not scroll the timeline', (
    tester,
  ) async {
    await pumpMedoApp(tester);
    containerFor(tester)
        .read(timelineProvider.notifier)
        .loadState(
          const TimelineState(
            blocks: [
              Block(
                id: 'first-action',
                type: BlockType.action,
                title: '最初の作業',
                duration: 60,
                colorIndex: 0,
              ),
              Block(
                id: 'middle-action',
                type: BlockType.action,
                title: '真ん中の作業',
                duration: 60,
                colorIndex: 1,
              ),
              Block(
                id: 'last-action',
                type: BlockType.action,
                title: '最後の作業',
                duration: 60,
                colorIndex: 2,
              ),
            ],
          ),
        );
    await tester.pump();

    final scrollView = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    final scrollController = scrollView.controller!;
    final handlePosition = tester.getCenter(
      find.byKey(const ValueKey('reorder-handle:last-action')),
    );

    final gesture = await tester.startGesture(handlePosition);
    await tester.pump(const Duration(milliseconds: 210));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('reorder-drag-preview:last-action')),
      findsOneWidget,
    );
    final offsetBeforeMove = scrollController.offset;

    await gesture.moveBy(const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 300));

    expect(scrollController.offset, moreOrLessEquals(offsetBeforeMove));

    await gesture.moveBy(const Offset(0, 1200));
    await tester.pump(const Duration(milliseconds: 300));

    expect(scrollController.offset, moreOrLessEquals(offsetBeforeMove));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('header search closes when timeline focus moves elsewhere', (
    tester,
  ) async {
    await pumpMedoApp(tester);

    await tester.tap(find.byIcon(PhosphorIcons.magnifyingGlass()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '朝');
    await tester.pumpAndSettle();

    expect(find.text('行動タイトルを検索'), findsOneWidget);
    expect(containerFor(tester).read(timelineProvider).searchQuery, '朝');

    await tester.tap(find.text('前の行動を追加しましょう'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('行動タイトルを検索'), findsNothing);
    expect(containerFor(tester).read(timelineProvider).searchQuery, isEmpty);
    expect(find.text('新しい行動'), findsNothing);
  });

  testWidgets('export panel consumes the next header action while closing', (
    tester,
  ) async {
    await pumpMedoApp(tester);

    await tester.tap(find.byIcon(PhosphorIcons.calendarBlank()));
    await tester.pumpAndSettle();

    expect(find.text('エクスポート'), findsOneWidget);

    await tester.tap(find.byIcon(PhosphorIcons.magnifyingGlass()));
    await tester.pumpAndSettle();

    expect(find.text('エクスポート'), findsNothing);
    expect(find.text('行動タイトルを検索'), findsNothing);
  });

  testWidgets('export panel keeps spacing below image share button', (
    tester,
  ) async {
    await pumpMedoApp(tester);

    await tester.tap(find.byIcon(PhosphorIcons.calendarBlank()));
    await tester.pumpAndSettle();

    final panelRect = tester.getRect(find.byType(ExportPanel));
    final imageShareRect = tester.getRect(find.text('画像で共有'));

    expect(panelRect.bottom - imageShareRect.bottom, greaterThanOrEqualTo(24));
  });

  testWidgets(
    'export quick overlay closes outside without firing toolbar action',
    (tester) async {
      await pumpMedoApp(tester);

      await tester.tap(find.byIcon(PhosphorIcons.calendarBlank()));
      await tester.pumpAndSettle();

      expect(find.text('エクスポート'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Container && widget.color == AppColors.scrim,
        ),
        findsNothing,
      );

      await tester.tapAt(tester.getCenter(find.text('前の行動を追加')));
      await tester.pumpAndSettle();

      expect(find.text('エクスポート'), findsNothing);
      expect(containerFor(tester).read(timelineProvider).blocks, isEmpty);
    },
  );

  testWidgets('edit sheet consumes header action while closing', (
    tester,
  ) async {
    await pumpMedoApp(tester);

    await tester.tap(find.text('前の行動を追加'));
    await tester.pump();

    final blockId = containerFor(
      tester,
    ).read(timelineProvider).blocks.single.id;
    containerFor(tester).read(timelineProvider.notifier).selectBlock(blockId);
    await tester.pumpAndSettle();

    expect(find.text('行動を編集'), findsOneWidget);

    await tester.tap(find.byIcon(PhosphorIcons.magnifyingGlass()));
    await tester.pumpAndSettle();

    expect(find.text('行動を編集'), findsNothing);
    expect(find.text('行動タイトルを検索'), findsNothing);
  });

  testWidgets('condensed density renders a short action block', (tester) async {
    await pumpMedoApp(tester);

    containerFor(tester)
        .read(timelineProvider.notifier)
        .loadState(
          const TimelineState(
            pixelsPerMinute: 3.0,
            blocks: [
              Block(
                id: 'short-action',
                type: BlockType.action,
                title: '短い行動',
                duration: 5,
                colorIndex: 0,
              ),
            ],
          ),
        );
    await tester.pumpAndSettle();

    expect(find.text('短い行動'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

      final blockId = containerFor(
        tester,
      ).read(timelineProvider).blocks.single.id;
      containerFor(tester).read(timelineProvider.notifier).selectBlock(blockId);
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

    final blockId = containerFor(
      tester,
    ).read(timelineProvider).blocks.single.id;
    containerFor(tester).read(timelineProvider.notifier).selectBlock(blockId);
    await tester.pumpAndSettle();

    expect(find.text('行動を編集'), findsOneWidget);
    expect(find.text('余裕時間'), findsOneWidget);

    await tester.tap(find.byIcon(PhosphorIcons.plus()).last);
    await tester.pumpAndSettle();

    final block = containerFor(tester).read(timelineProvider).blocks.single;
    expect(block.bufferMinutes, 5);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets(
    'detail sheet toggles an action to a point and restores settings',
    (tester) async {
      await pumpMedoApp(tester, effectiveIsPro: true);
      containerFor(tester)
          .read(timelineProvider.notifier)
          .loadState(
            const TimelineState(
              blocks: [
                Block(
                  id: 'toggle',
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
      ).read(timelineProvider.notifier).selectBlock('toggle');
      await tester.pumpAndSettle();

      expect(find.text('行動を編集'), findsOneWidget);
      expect(find.text('所要時間'), findsOneWidget);
      expect(find.text('余裕時間'), findsOneWidget);

      await tester.tap(find.text('ピン'));
      await tester.pumpAndSettle();

      var block = containerFor(tester).read(timelineProvider).blocks.single;
      expect(block.type, BlockType.actionPoint);
      expect(block.duration, 20);
      expect(block.bufferMinutes, 10);
      expect(block.effectiveDuration, 0);
      expect(find.text('所要時間'), findsNothing);
      expect(find.text('余裕時間'), findsNothing);

      await tester.tap(find.text('ブロック'));
      await tester.pumpAndSettle();

      block = containerFor(tester).read(timelineProvider).blocks.single;
      expect(block.type, BlockType.action);
      expect(block.duration, 20);
      expect(block.bufferMinutes, 10);
      expect(block.effectiveDuration, 30);
      expect(find.text('所要時間'), findsOneWidget);
      expect(find.text('余裕時間'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    },
  );

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

  testWidgets('detail sheet close button dismisses the sheet', (tester) async {
    await pumpMedoApp(tester);

    await tester.tap(find.text('前の行動を追加'));
    await tester.pump();

    final blockId = containerFor(
      tester,
    ).read(timelineProvider).blocks.single.id;
    containerFor(tester).read(timelineProvider.notifier).selectBlock(blockId);
    await tester.pumpAndSettle();

    expect(find.text('行動を編集'), findsOneWidget);

    await tester.tap(find.byIcon(PhosphorIcons.x()).last);
    await tester.pumpAndSettle();

    expect(find.text('行動を編集'), findsNothing);
    expect(containerFor(tester).read(timelineProvider).selectedBlockId, isNull);
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

      expect(
        find.byKey(const ValueKey('reorder-insertion-line')),
        findsNothing,
      );

      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('16分'), findsOneWidget);
    },
  );

  testWidgets('action block affordances are contained in swipe target', (
    tester,
  ) async {
    await pumpMedoApp(tester);

    await tester.tap(find.text('前の行動を追加'));
    await tester.pump();

    final block = containerFor(tester).read(timelineProvider).blocks.single;
    final swipeTarget = find.byType(Dismissible);

    expect(
      find.descendant(of: swipeTarget, matching: find.text('15分')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: swipeTarget,
        matching: find.byKey(ValueKey('reorder-handle:${block.id}')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: swipeTarget,
        matching: find.byKey(ValueKey('duration-drag-handle:${block.id}')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('right swipe deletes an action block', (tester) async {
    await pumpMedoApp(tester);

    await tester.tap(find.text('前の行動を追加'));
    await tester.pump();

    expect(find.text('新しい行動'), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('新しい行動'), findsNothing);
    expect(find.text('「新しい行動」を削除しました'), findsOneWidget);
    expect(find.text('元に戻す'), findsOneWidget);
    expect(containerFor(tester).read(timelineProvider).blocks, isEmpty);
  });

  testWidgets('swipe delete snackbar restores an action block', (tester) async {
    await pumpMedoApp(tester);

    await tester.tap(find.text('前の行動を追加'));
    await tester.pump();

    final original = containerFor(tester).read(timelineProvider).blocks.single;

    await tester.drag(find.byType(Dismissible), const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 500));

    expect(containerFor(tester).read(timelineProvider).blocks, isEmpty);

    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pumpAndSettle();

    final state = containerFor(tester).read(timelineProvider);
    expect(state.blocks, [original]);
    expect(state.selectedBlockId, isNull);
    expect(find.text('新しい行動'), findsOneWidget);
    expect(find.text('行動を編集'), findsNothing);
  });

  testWidgets('swipe delete snackbar times out after three seconds', (
    tester,
  ) async {
    await pumpMedoApp(tester);

    await tester.tap(find.text('前の行動を追加'));
    await tester.pump();

    await tester.drag(find.byType(Dismissible), const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('「新しい行動」を削除しました'), findsOneWidget);
    expect(find.text('元に戻す'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pumpAndSettle();

    expect(find.text('「新しい行動」を削除しました'), findsNothing);
    expect(find.text('元に戻す'), findsNothing);
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
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('受付'), findsNothing);
    expect(find.text('「受付」を削除しました'), findsOneWidget);
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
