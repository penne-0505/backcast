import 'calendar_export.dart';
import 'models.dart';
import 'state.dart';

/// Builds a [CalendarExportRequest] from the current [TimelineState] and a
/// user-selected base date.  The base date's time component is ignored; the
/// timeline's target time and block effective durations determine the actual
/// start and anchor datetimes. This function is pure (aside from [clock]) and
/// fully testable.
CalendarExportRequest buildCalendarExportRequest({
  required TimelineState state,
  required DateTime baseDate,
  required DateTime Function() clock,
}) {
  final totalMin = totalTimelineDuration(state.blocks);
  var startMin = state.targetTime - totalMin;
  var date = DateTime(baseDate.year, baseDate.month, baseDate.day);
  while (startMin < 0) {
    startMin += 24 * 60;
    date = DateTime(date.year, date.month, date.day - 1);
  }

  return CalendarExportRequest(
    startDateTime: DateTime(
      date.year,
      date.month,
      date.day,
      startMin ~/ 60,
      startMin % 60,
    ),
    blocks: state.blocks.map(CalendarExportBlock.fromBlock).toList(),
    anchor: CalendarExportAnchor(id: 'target', title: state.targetTimeTitle),
    generatedAt: clock(),
  );
}

/// Preview metadata derived from a [CalendarExportRequest].  This is
/// intentionally separate from the request itself so that the request remains
/// a simple input model for `.ics` generation and native delivery.
class CalendarExportPreview {
  const CalendarExportPreview({
    required this.startDateTime,
    required this.anchorDateTime,
    required this.eventCount,
    required this.spansMultipleDays,
  });

  final DateTime startDateTime;
  final DateTime anchorDateTime;
  final int eventCount;
  final bool spansMultipleDays;

  factory CalendarExportPreview.fromRequest(CalendarExportRequest request) {
    final events = projectCalendarExportEvents(request);
    final startDateTime = events.first.startDateTime;
    final anchorDateTime = events.last.startDateTime;
    final spansMultipleDays =
        startDateTime.day != anchorDateTime.day ||
        startDateTime.month != anchorDateTime.month ||
        startDateTime.year != anchorDateTime.year;
    return CalendarExportPreview(
      startDateTime: startDateTime,
      anchorDateTime: anchorDateTime,
      eventCount: events.length,
      spansMultipleDays: spansMultipleDays,
    );
  }
}
