import 'package:medo/calendar_export.dart';
import 'package:medo/calendar_export_request_builder.dart';
import 'package:medo/models.dart';
import 'package:medo/state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildCalendarExportRequest', () {
    final fixedClock = DateTime.utc(2026, 5, 2, 10, 30);

    test('builds a same-day request when timeline fits within the day', () {
      const state = TimelineState(
        targetTime: 13 * 60,
        targetTimeTitle: '会議開始',
        blocks: [
          Block(
            id: 'b1',
            type: BlockType.action,
            title: '移動',
            duration: 30,
            colorIndex: 0,
          ),
          Block(
            id: 'b2',
            type: BlockType.action,
            title: '準備',
            duration: 15,
            colorIndex: 1,
          ),
        ],
      );

      final request = buildCalendarExportRequest(
        state: state,
        baseDate: DateTime(2026, 5, 10),
        clock: () => fixedClock,
      );

      expect(request.startDateTime, DateTime(2026, 5, 10, 12, 15));
      expect(request.blocks, hasLength(2));
      expect(request.anchor.title, '会議開始');
      expect(request.generatedAt, fixedClock);
    });

    test('rolls start to the previous day when timeline crosses midnight', () {
      const state = TimelineState(
        targetTime: 8 * 60,
        targetTimeTitle: '出発',
        blocks: [
          Block(
            id: 'b1',
            type: BlockType.action,
            title: '睡眠',
            duration: 8 * 60,
            colorIndex: 0,
          ),
        ],
      );

      final request = buildCalendarExportRequest(
        state: state,
        baseDate: DateTime(2026, 5, 10),
        clock: () => fixedClock,
      );

      expect(request.startDateTime, DateTime(2026, 5, 10, 0, 0));
    });

    test('handles multi-day spans by repeatedly rolling back', () {
      const state = TimelineState(
        targetTime: 6 * 60,
        targetTimeTitle: '到着',
        blocks: [
          Block(
            id: 'b1',
            type: BlockType.action,
            title: '長距離移動',
            duration: 28 * 60,
            colorIndex: 0,
          ),
        ],
      );

      final request = buildCalendarExportRequest(
        state: state,
        baseDate: DateTime(2026, 5, 10),
        clock: () => fixedClock,
      );

      expect(request.startDateTime, DateTime(2026, 5, 9, 2, 0));
    });

    test('preserves zero-duration blocks as 0-minute events', () {
      const state = TimelineState(
        targetTime: 12 * 60,
        targetTimeTitle: '打ち合わせ',
        blocks: [
          Block(
            id: 'b1',
            type: BlockType.actionPoint,
            title: 'チェックポイント',
            duration: 0,
            colorIndex: 0,
          ),
          Block(
            id: 'b2',
            type: BlockType.action,
            title: '移動',
            duration: 30,
            colorIndex: 1,
          ),
        ],
      );

      final request = buildCalendarExportRequest(
        state: state,
        baseDate: DateTime(2026, 5, 10),
        clock: () => fixedClock,
      );

      expect(request.blocks[0].duration, Duration.zero);
      expect(request.startDateTime, DateTime(2026, 5, 10, 11, 30));
    });

    test('builds anchor-only request when blocks are empty', () {
      const state = TimelineState(
        targetTime: 15 * 60,
        targetTimeTitle: '目標',
        blocks: [],
      );

      final request = buildCalendarExportRequest(
        state: state,
        baseDate: DateTime(2026, 5, 10),
        clock: () => fixedClock,
      );

      expect(request.blocks, isEmpty);
      expect(request.startDateTime, DateTime(2026, 5, 10, 15, 0));
    });
  });

  group('CalendarExportPreview', () {
    test('derives preview for a same-day timeline', () {
      final request = CalendarExportRequest(
        startDateTime: DateTime.utc(2026, 5, 10, 10, 0),
        blocks: const [
          CalendarExportBlock(
            id: 'b1',
            title: '作業',
            duration: Duration(minutes: 60),
          ),
        ],
        anchor: const CalendarExportAnchor(id: 'a', title: '完了'),
      );

      final preview = CalendarExportPreview.fromRequest(request);

      expect(preview.startDateTime, DateTime.utc(2026, 5, 10, 10, 0));
      expect(preview.anchorDateTime, DateTime.utc(2026, 5, 10, 11, 0));
      expect(preview.eventCount, 2);
      expect(preview.spansMultipleDays, false);
    });

    test('detects multi-day span', () {
      final request = CalendarExportRequest(
        startDateTime: DateTime.utc(2026, 5, 10, 22, 0),
        blocks: const [
          CalendarExportBlock(
            id: 'b1',
            title: '夜勤',
            duration: Duration(minutes: 4 * 60),
          ),
        ],
        anchor: const CalendarExportAnchor(id: 'a', title: '終了'),
      );

      final preview = CalendarExportPreview.fromRequest(request);

      expect(preview.startDateTime, DateTime.utc(2026, 5, 10, 22, 0));
      expect(preview.anchorDateTime, DateTime.utc(2026, 5, 11, 2, 0));
      expect(preview.spansMultipleDays, true);
    });

    test('counts zero-duration blocks and anchor correctly', () {
      final request = CalendarExportRequest(
        startDateTime: DateTime.utc(2026, 5, 10, 10, 0),
        blocks: const [
          CalendarExportBlock(
            id: 'b1',
            title: 'ポイント',
            duration: Duration.zero,
          ),
        ],
        anchor: const CalendarExportAnchor(id: 'a', title: '到着'),
      );

      final preview = CalendarExportPreview.fromRequest(request);

      expect(preview.eventCount, 2);
      expect(preview.startDateTime, preview.anchorDateTime);
    });
  });
}
