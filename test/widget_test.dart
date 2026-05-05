import 'package:medo/main.dart';
import 'package:medo/block_item.dart';
import 'package:medo/models.dart';
import 'package:medo/persistence/app_database.dart';
import 'package:medo/persistence/persistence_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

late AppDatabase db;

Future<void> pumpMedoApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MedoApp(),
    ),
  );
  await tester.pump();
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
}
