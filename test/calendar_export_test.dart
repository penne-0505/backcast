import 'package:medo/calendar_export.dart';
import 'package:medo/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('projectCalendarExportEvents', () {
    test('projects absolute event ranges including the anchor', () {
      final events = projectCalendarExportEvents(
        CalendarExportRequest(
          startDateTime: DateTime.utc(2026, 4, 23, 8),
          blocks: const [
            CalendarExportBlock(
              id: 'move',
              title: '移動',
              duration: Duration(minutes: 30),
            ),
          ],
          anchor: const CalendarExportAnchor(id: 'target', title: '会議開始'),
        ),
      );

      expect(events, hasLength(2));
      expect(events[0].kind, CalendarExportEventKind.block);
      expect(events[0].id, 'move');
      expect(events[0].title, '移動');
      expect(events[0].startDateTime, DateTime.utc(2026, 4, 23, 8));
      expect(events[0].endDateTime, DateTime.utc(2026, 4, 23, 8, 30));
      expect(events[0].sequence, 0);

      expect(events[1].kind, CalendarExportEventKind.anchor);
      expect(events[1].id, 'target');
      expect(events[1].title, '会議開始');
      expect(events[1].startDateTime, DateTime.utc(2026, 4, 23, 8, 30));
      expect(events[1].endDateTime, DateTime.utc(2026, 4, 23, 8, 30));
      expect(events[1].sequence, isNull);
    });

    test('normalizes blank block titles to 無題', () {
      final events = projectCalendarExportEvents(
        CalendarExportRequest(
          startDateTime: DateTime.utc(2026, 4, 23, 8),
          blocks: const [
            CalendarExportBlock(
              id: 'empty',
              title: '',
              duration: Duration(minutes: 10),
            ),
            CalendarExportBlock(
              id: 'whitespace',
              title: '   ',
              duration: Duration(minutes: 10),
            ),
          ],
          anchor: const CalendarExportAnchor(id: 'target', title: '会議開始'),
        ),
      );

      expect(events[0].title, '無題');
      expect(events[1].title, '無題');
    });

    test('normalizes blank anchor titles to 目標時刻', () {
      final events = projectCalendarExportEvents(
        CalendarExportRequest(
          startDateTime: DateTime.utc(2026, 4, 23, 8),
          blocks: const [
            CalendarExportBlock(
              id: 'move',
              title: '移動',
              duration: Duration(minutes: 30),
            ),
          ],
          anchor: const CalendarExportAnchor(id: 'target', title: ''),
        ),
      );

      expect(events.last.title, '目標時刻');
    });

    test('normalizes whitespace-only anchor titles to 目標時刻', () {
      final events = projectCalendarExportEvents(
        CalendarExportRequest(
          startDateTime: DateTime.utc(2026, 4, 23, 8),
          blocks: const [],
          anchor: const CalendarExportAnchor(id: 'target', title: '  \t  '),
        ),
      );

      expect(events.last.title, '目標時刻');
    });
  });

  group('generateCalendarIcs', () {
    test('chains block times from the supplied start DateTime', () {
      final ics = generateCalendarIcs(
        CalendarExportRequest(
          startDateTime: DateTime.utc(2026, 4, 23, 8),
          generatedAt: DateTime.utc(2026, 4, 23, 7, 30),
          blocks: const [
            CalendarExportBlock(
              id: 'move',
              title: '移動',
              duration: Duration(minutes: 30),
            ),
            CalendarExportBlock(
              id: 'prep',
              title: '準備',
              duration: Duration(minutes: 15),
            ),
          ],
          anchor: const CalendarExportAnchor(id: 'target', title: '会議開始'),
        ),
      );

      expect(ics, contains('DTSTAMP:20260423T073000Z'));
      expect(ics, contains('SUMMARY:移動'));
      expect(ics, contains('DTSTART:20260423T080000Z'));
      expect(ics, contains('DTEND:20260423T083000Z'));
      expect(ics, contains('SUMMARY:準備'));
      expect(ics, contains('DTSTART:20260423T083000Z'));
      expect(ics, contains('DTEND:20260423T084500Z'));
      expect(ics, contains('SUMMARY:会議開始'));
      expect(ics, contains('DTSTART:20260423T084500Z'));
      expect(ics, contains('DTEND:20260423T084500Z'));
    });

    test('exports zero-duration blocks and anchor as zero-duration events', () {
      final ics = generateCalendarIcs(
        CalendarExportRequest(
          startDateTime: DateTime.utc(2026, 4, 23, 8),
          blocks: const [
            CalendarExportBlock(
              id: 'checkpoint',
              title: 'チェックポイント',
              duration: Duration.zero,
            ),
          ],
          anchor: const CalendarExportAnchor(id: 'target', title: '到着'),
        ),
      );

      final zeroDurationPattern = RegExp(
        'SUMMARY:チェックポイント\\r\\n'
        'DTSTART:20260423T080000Z\\r\\n'
        'DTEND:20260423T080000Z',
      );
      final anchorPattern = RegExp(
        'SUMMARY:到着\\r\\n'
        'DTSTART:20260423T080000Z\\r\\n'
        'DTEND:20260423T080000Z',
      );

      expect(ics, contains(zeroDurationPattern));
      expect(ics, contains(anchorPattern));
    });

    test('escapes text fields for iCalendar text values', () {
      final ics = generateCalendarIcs(
        CalendarExportRequest(
          startDateTime: DateTime.utc(2026, 4, 23, 8),
          calendarName: '予定,一覧;A\\B\nC',
          blocks: const [
            CalendarExportBlock(
              id: 'escape',
              title: '買い物,確認;A\\B\nC',
              duration: Duration(minutes: 5),
            ),
          ],
          anchor: const CalendarExportAnchor(id: 'target', title: '完了'),
        ),
      );

      expect(ics, contains(r'X-WR-CALNAME:予定\,一覧\;A\\B\nC'));
      expect(ics, contains(r'SUMMARY:買い物\,確認\;A\\B\nC'));
    });

    test('exports an anchor-only calendar when blocks are empty', () {
      final ics = generateCalendarIcs(
        CalendarExportRequest(
          startDateTime: DateTime.utc(2026, 4, 23, 8),
          blocks: const [],
          anchor: const CalendarExportAnchor(id: 'target', title: '出発'),
        ),
      );

      expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
      expect(ics, contains('SUMMARY:出発'));
      expect(ics, contains('DTSTART:20260423T080000Z'));
      expect(ics, contains('DTEND:20260423T080000Z'));
      expect(ics, endsWith('END:VCALENDAR\r\n'));
    });

    test('uses normalized titles in ICS output', () {
      final ics = generateCalendarIcs(
        CalendarExportRequest(
          startDateTime: DateTime.utc(2026, 4, 23, 8),
          blocks: const [
            CalendarExportBlock(
              id: 'empty',
              title: '',
              duration: Duration(minutes: 5),
            ),
          ],
          anchor: const CalendarExportAnchor(id: 'target', title: '   '),
        ),
      );

      expect(ics, contains('SUMMARY:無題'));
      expect(ics, contains('SUMMARY:目標時刻'));
    });

    test('uses normalized titles in native payload', () {
      final events = projectCalendarExportEvents(
        CalendarExportRequest(
          startDateTime: DateTime.utc(2026, 4, 23, 8),
          blocks: const [
            CalendarExportBlock(
              id: 'empty',
              title: '',
              duration: Duration(minutes: 5),
            ),
          ],
          anchor: const CalendarExportAnchor(id: 'target', title: '\t'),
        ),
      );

      expect(events[0].toNativePayload()['title'], '無題');
      expect(events[1].toNativePayload()['title'], '目標時刻');
    });

    test(
      'converts existing timeline blocks through the helper constructor',
      () {
        const block = Block(
          id: 'block-1',
          type: BlockType.action,
          title: '移動',
          duration: 20,
          colorIndex: 0,
        );

        final exportBlock = CalendarExportBlock.fromBlock(block);

        expect(exportBlock.id, 'block-1');
        expect(exportBlock.title, '移動');
        expect(exportBlock.duration, const Duration(minutes: 20));
      },
    );

    test('helper constructor includes action buffer in calendar duration', () {
      const block = Block(
        id: 'block-1',
        type: BlockType.action,
        title: '移動',
        duration: 20,
        bufferMinutes: 10,
        colorIndex: 0,
      );

      final exportBlock = CalendarExportBlock.fromBlock(block);

      expect(exportBlock.duration, const Duration(minutes: 30));
    });

    test('rejects negative durations', () {
      expect(
        () => generateCalendarIcs(
          CalendarExportRequest(
            startDateTime: DateTime.utc(2026, 4, 23, 8),
            blocks: const [
              CalendarExportBlock(
                id: 'bad',
                title: 'Invalid',
                duration: Duration(minutes: -1),
              ),
            ],
            anchor: const CalendarExportAnchor(id: 'target', title: 'Target'),
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}
