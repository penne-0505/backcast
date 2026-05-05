import 'package:flutter/foundation.dart';

import 'models.dart';

const String _defaultProductId = '-//Medo//Calendar Export//EN';
const String _defaultCalendarName = 'Medo';
const String _uidDomain = 'dev.otibo.medo';

@immutable
class CalendarExportRequest {
  const CalendarExportRequest({
    required this.startDateTime,
    required this.blocks,
    required this.anchor,
    this.generatedAt,
    this.productId = _defaultProductId,
    this.calendarName = _defaultCalendarName,
  });

  /// The absolute start of the first exported block.
  final DateTime startDateTime;
  final List<CalendarExportBlock> blocks;
  final CalendarExportAnchor anchor;

  /// Optional creation timestamp for deterministic exports.
  ///
  /// When omitted, [startDateTime] is also used as DTSTAMP so this function
  /// never depends on DateTime.now().
  final DateTime? generatedAt;
  final String productId;
  final String calendarName;
}

@immutable
class CalendarExportBlock {
  const CalendarExportBlock({
    required this.id,
    required this.title,
    required this.duration,
  });

  factory CalendarExportBlock.fromBlock(Block block) {
    return CalendarExportBlock(
      id: block.id,
      title: block.title,
      duration: Duration(minutes: block.duration),
    );
  }

  final String id;
  final String title;
  final Duration duration;
}

@immutable
class CalendarExportAnchor {
  const CalendarExportAnchor({required this.id, required this.title});

  final String id;
  final String title;
}

enum CalendarExportEventKind { block, anchor }

@immutable
class CalendarExportEvent {
  const CalendarExportEvent({
    required this.kind,
    required this.id,
    required this.title,
    required this.startDateTime,
    required this.endDateTime,
    required this.sequence,
  });

  final CalendarExportEventKind kind;
  final String id;
  final String title;
  final DateTime startDateTime;
  final DateTime endDateTime;

  /// Stable ordering for block events; anchors use null.
  final int? sequence;

  Map<String, Object?> toNativePayload() {
    return <String, Object?>{
      'kind': kind.name,
      'id': id,
      'title': title,
      'startAtMillis': startDateTime.toUtc().millisecondsSinceEpoch,
      'endAtMillis': endDateTime.toUtc().millisecondsSinceEpoch,
      'sequence': sequence,
    };
  }
}

String _normalizeEventTitle(String title, CalendarExportEventKind kind) {
  if (title.trim().isEmpty) {
    return kind == CalendarExportEventKind.block ? '無題' : '目標時刻';
  }
  return title;
}

List<CalendarExportEvent> projectCalendarExportEvents(
  CalendarExportRequest request,
) {
  _validateRequest(request);

  final events = <CalendarExportEvent>[];
  var cursor = request.startDateTime;

  for (var i = 0; i < request.blocks.length; i++) {
    final block = request.blocks[i];
    final start = cursor;
    final end = start.add(block.duration);
    events.add(
      CalendarExportEvent(
        kind: CalendarExportEventKind.block,
        id: block.id,
        title: _normalizeEventTitle(block.title, CalendarExportEventKind.block),
        startDateTime: start,
        endDateTime: end,
        sequence: i,
      ),
    );
    cursor = end;
  }

  events.add(
    CalendarExportEvent(
      kind: CalendarExportEventKind.anchor,
      id: request.anchor.id,
      title: _normalizeEventTitle(
        request.anchor.title,
        CalendarExportEventKind.anchor,
      ),
      startDateTime: cursor,
      endDateTime: cursor,
      sequence: null,
    ),
  );

  return events;
}

String generateCalendarIcs(CalendarExportRequest request) {
  _validateRequest(request);

  final stamp = _formatUtcIcsDateTime(
    (request.generatedAt ?? request.startDateTime).toUtc(),
  );
  final events = projectCalendarExportEvents(request);
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:${request.productId}',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:${_escapeIcsText(request.calendarName)}',
  ];

  for (final event in events) {
    final uid = event.kind == CalendarExportEventKind.block
        ? 'block-${event.sequence}-${_sanitizeUidPart(event.id)}@$_uidDomain'
        : 'anchor-${_sanitizeUidPart(event.id)}@$_uidDomain';
    lines.addAll(
      _eventLines(
        uid: uid,
        stamp: stamp,
        summary: event.title,
        start: event.startDateTime,
        end: event.endDateTime,
      ),
    );
  }

  lines.add('END:VCALENDAR');
  return '${lines.join('\r\n')}\r\n';
}

List<String> _eventLines({
  required String uid,
  required String stamp,
  required String summary,
  required DateTime start,
  required DateTime end,
}) {
  return [
    'BEGIN:VEVENT',
    'UID:$uid',
    'DTSTAMP:$stamp',
    'SUMMARY:${_escapeIcsText(summary)}',
    'DTSTART:${_formatUtcIcsDateTime(start.toUtc())}',
    'DTEND:${_formatUtcIcsDateTime(end.toUtc())}',
    'END:VEVENT',
  ];
}

void _validateRequest(CalendarExportRequest request) {
  for (final block in request.blocks) {
    if (block.duration.isNegative) {
      throw ArgumentError.value(
        block.duration,
        'duration',
        'Calendar export blocks cannot have negative duration.',
      );
    }
  }
}

String _formatUtcIcsDateTime(DateTime value) {
  final utc = value.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}'
      '${utc.month.toString().padLeft(2, '0')}'
      '${utc.day.toString().padLeft(2, '0')}'
      'T'
      '${utc.hour.toString().padLeft(2, '0')}'
      '${utc.minute.toString().padLeft(2, '0')}'
      '${utc.second.toString().padLeft(2, '0')}'
      'Z';
}

String _escapeIcsText(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll('\r\n', r'\n')
      .replaceAll('\r', r'\n')
      .replaceAll('\n', r'\n')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,');
}

String _sanitizeUidPart(String value) {
  final buffer = StringBuffer();
  for (final unit in value.codeUnits) {
    final isDigit = unit >= 0x30 && unit <= 0x39;
    final isUpper = unit >= 0x41 && unit <= 0x5a;
    final isLower = unit >= 0x61 && unit <= 0x7a;
    final isSafeSymbol = unit == 0x2d || unit == 0x2e || unit == 0x5f;
    if (isDigit || isUpper || isLower || isSafeSymbol) {
      buffer.writeCharCode(unit);
    } else {
      buffer.write('_${unit.toRadixString(16)}');
    }
  }
  final result = buffer.toString();
  return result.isEmpty ? 'item' : result;
}
