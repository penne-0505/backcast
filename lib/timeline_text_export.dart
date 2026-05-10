import 'package:flutter/foundation.dart';

import 'models.dart';
import 'state.dart';

enum TimelineTextExportMode { noDate, withDate }

@immutable
class TimelineTextExportRequest {
  const TimelineTextExportRequest({
    required this.state,
    required this.mode,
    this.baseDate,
  });

  final TimelineState state;
  final TimelineTextExportMode mode;
  final DateTime? baseDate;
}

/// 現在の [TimelineState] を、記号と等幅レイアウトを意識したプレーンテキストへ変換する。
///
/// 本関数は Flutter UI や DateTime.now() に依存しない純粋関数。
String generateTimelineText(TimelineTextExportRequest request) {
  final state = request.state;
  final mode = request.mode;
  final baseDate = request.baseDate;

  if (mode != TimelineTextExportMode.noDate && baseDate == null) {
    throw ArgumentError.value(
      baseDate,
      'baseDate',
      'baseDate is required for TimelineTextExportMode.withDate.',
    );
  }

  final targetTitle = state.targetTimeTitle.trim().isEmpty
      ? '目標時刻'
      : state.targetTimeTitle.trim().replaceAll('\n', ' ');

  final computed = computeBlocks(state.blocks, state.targetTime);
  final totalDuration = totalTimelineDuration(state.blocks);

  final lines = <String>[];

  // Header
  lines.add('Medo // $targetTitle');

  // Metadata
  final durationStr = _formatDuration(totalDuration);
  switch (mode) {
    case TimelineTextExportMode.noDate:
      lines.add('TOTAL $durationStr');
    case TimelineTextExportMode.withDate:
      final baseMidnight = DateTime(
        baseDate!.year,
        baseDate.month,
        baseDate.day,
      );
      final anchorDateTime = baseMidnight.add(
        Duration(minutes: state.targetTime),
      );
      final startMin = state.targetTime - totalDuration;
      final startDateTime = baseMidnight.add(Duration(minutes: startMin));
      if (_isSameDate(startDateTime, anchorDateTime)) {
        lines.add('${_formatDate(anchorDateTime)}  /  TOTAL $durationStr');
      } else {
        final startStr = _formatDate(startDateTime);
        final anchorStr = _formatDate(anchorDateTime);
        lines.add('$startStr -> $anchorStr  /  TOTAL $durationStr');
      }
  }

  // Empty line between metadata and events
  lines.add('');

  if (mode == TimelineTextExportMode.withDate) {
    _buildDateAwareLines(
      lines,
      state: state,
      computed: computed,
      targetTitle: targetTitle,
      baseDate: baseDate!,
    );
  } else {
    _buildPlainLines(
      lines,
      state: state,
      computed: computed,
      targetTitle: targetTitle,
    );
  }

  return lines.join('\n');
}

void _buildPlainLines(
  List<String> lines, {
  required TimelineState state,
  required List<ComputedBlock> computed,
  required String targetTitle,
}) {
  for (final cb in computed) {
    final title = _sanitizeTitle(cb.block.title);

    if (cb.block.type == BlockType.action) {
      lines.add(
        _formatEventLine(
          '${formatTime(cb.startTime)}-${formatTime(cb.endTime)}',
          '┃',
          _formatActionTitle(cb.block, title),
        ),
      );
    } else {
      lines.add(_formatEventLine(formatTime(cb.startTime), '●', title));
    }
  }

  lines.add(_formatEventLine(formatTime(state.targetTime), '◆', targetTitle));
}

void _buildDateAwareLines(
  List<String> lines, {
  required TimelineState state,
  required List<ComputedBlock> computed,
  required String targetTitle,
  required DateTime baseDate,
}) {
  final baseMidnight = DateTime(baseDate.year, baseDate.month, baseDate.day);

  final events = <_TextExportEvent>[];

  for (final cb in computed) {
    final startDate = baseMidnight.add(Duration(minutes: cb.startTime));
    final title = _sanitizeTitle(cb.block.title);

    if (cb.block.type == BlockType.action) {
      events.add(
        _TextExportEvent(
          date: startDate,
          line: _formatEventLine(
            '${formatTime(cb.startTime)}-${formatTime(cb.endTime)}',
            '┃',
            _formatActionTitle(cb.block, title),
          ),
        ),
      );
    } else {
      events.add(
        _TextExportEvent(
          date: startDate,
          line: _formatEventLine(formatTime(cb.startTime), '●', title),
        ),
      );
    }
  }

  final anchorDate = baseMidnight.add(Duration(minutes: state.targetTime));
  events.add(
    _TextExportEvent(
      date: anchorDate,
      line: _formatEventLine(formatTime(state.targetTime), '◆', targetTitle),
    ),
  );

  final grouped = <DateTime, List<String>>{};
  for (final event in events) {
    final key = DateTime(event.date.year, event.date.month, event.date.day);
    grouped.putIfAbsent(key, () => []).add(event.line);
  }

  final sortedKeys = grouped.keys.toList()..sort();

  if (sortedKeys.length == 1) {
    lines.addAll(grouped[sortedKeys.single]!);
    return;
  }

  for (var i = 0; i < sortedKeys.length; i++) {
    if (i > 0) lines.add('');
    final key = sortedKeys[i];
    lines.add('── ${_formatDate(key)}');
    lines.addAll(grouped[key]!);
  }
}

String _sanitizeTitle(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '無題';
  return trimmed.replaceAll('\n', ' ');
}

String _formatActionTitle(Block block, String title) {
  final buffer = block.normalizedBufferMinutes;
  if (buffer == 0) return title;
  return '$title ${block.duration}分 + 余裕$buffer分';
}

/// 時間列は 12 文字幅として扱い、記号の開始位置を揃える。
///
/// - action:  `HH:mm-HH:mm ┃ title`
/// - point:   `HH:mm       ● title`
/// - anchor:  `HH:mm       ◆ title`
String _formatEventLine(String timePart, String symbol, String title) {
  final paddedTime = timePart.padRight(12, ' ');
  return '$paddedTime$symbol $title';
}

String _formatDuration(int minutes) {
  if (minutes == 0) return '0m';
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}h';
  return '${h}h${m}m';
}

String _formatDate(DateTime dt) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final w = weekdays[dt.weekday - 1];
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $w';
}

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _TextExportEvent {
  _TextExportEvent({required this.date, required this.line});
  final DateTime date;
  final String line;
}
