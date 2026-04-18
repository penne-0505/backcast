import 'package:backcast/main.dart';
import 'package:backcast/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
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
            colorIndex: 0),
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
            colorIndex: 0),
        const Block(
            id: '2',
            type: BlockType.action,
            title: 'B',
            duration: 20,
            colorIndex: 1),
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
            colorIndex: 0),
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
    test('wraps negative values correctly',
        () => expect(formatTime(-60), '23:00'));
    test('wraps over 24h correctly',
        () => expect(formatTime(25 * 60), '01:00'));
  });

  // ---------------------------------------------------------------------------
  // Widget smoke test
  // ---------------------------------------------------------------------------

  testWidgets('renders header and target anchor', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BackcastApp()));
    await tester.pump();

    expect(find.text('逆算タイムライン'), findsOneWidget);
    expect(find.text('目標時刻'), findsOneWidget);
  });
}
