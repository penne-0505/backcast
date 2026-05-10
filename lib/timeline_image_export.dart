import 'package:flutter/foundation.dart';

import 'models.dart';
import 'state.dart';

enum TimelineImageExportMode { noDate, withDate }

@immutable
class TimelineImageExportEvent {
  const TimelineImageExportEvent({
    required this.timeText,
    required this.title,
    required this.type,
    required this.colorIndex,
    this.durationMinutes,
    this.bufferMinutes = 0,
  });

  final String timeText;
  final String title;
  final TimelineImageExportEventType type;
  final int colorIndex;
  final int? durationMinutes;
  final int bufferMinutes;
}

enum TimelineImageExportEventType { action, actionPoint, targetAnchor }

@immutable
class TimelineImageExportViewModel {
  const TimelineImageExportViewModel({
    required this.targetTitle,
    required this.metadataText,
    required this.events,
  });

  final String targetTitle;
  final String metadataText;
  final List<TimelineImageExportEvent> events;
}

/// 現在の [TimelineState] から画像共有カード用の view model を構築する。
///
/// 本関数は Flutter UI や DateTime.now() に依存しない純粋関数。
TimelineImageExportViewModel buildTimelineImageExportViewModel(
  TimelineState state, {
  TimelineImageExportMode mode = TimelineImageExportMode.noDate,
  DateTime? baseDate,
}) {
  if (mode != TimelineImageExportMode.noDate && baseDate == null) {
    throw ArgumentError.value(
      baseDate,
      'baseDate',
      'baseDate is required for TimelineImageExportMode.withDate.',
    );
  }

  final targetTitle = state.targetTimeTitle.trim().isEmpty
      ? '目標時刻'
      : state.targetTimeTitle.trim().replaceAll('\n', ' ');

  final computed = computeBlocks(state.blocks, state.targetTime);
  final totalDuration = totalTimelineDuration(state.blocks);
  final durationStr = _formatDuration(totalDuration);

  String metadataText;
  switch (mode) {
    case TimelineImageExportMode.noDate:
      metadataText = 'TOTAL $durationStr';
    case TimelineImageExportMode.withDate:
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
        metadataText = '${_formatDate(anchorDateTime)}  /  TOTAL $durationStr';
      } else {
        final startStr = _formatDate(startDateTime);
        final anchorStr = _formatDate(anchorDateTime);
        metadataText = '$startStr -> $anchorStr  /  TOTAL $durationStr';
      }
  }

  final events = <TimelineImageExportEvent>[];

  for (final cb in computed) {
    final title = _sanitizeTitle(cb.block.title);
    if (cb.block.type == BlockType.action) {
      events.add(
        TimelineImageExportEvent(
          timeText: '${formatTime(cb.startTime)}-${formatTime(cb.endTime)}',
          title: title,
          type: TimelineImageExportEventType.action,
          colorIndex: cb.block.colorIndex,
          durationMinutes: cb.block.duration,
          bufferMinutes: cb.block.normalizedBufferMinutes,
        ),
      );
    } else {
      events.add(
        TimelineImageExportEvent(
          timeText: formatTime(cb.startTime),
          title: title,
          type: TimelineImageExportEventType.actionPoint,
          colorIndex: cb.block.colorIndex,
        ),
      );
    }
  }

  events.add(
    TimelineImageExportEvent(
      timeText: formatTime(state.targetTime),
      title: targetTitle,
      type: TimelineImageExportEventType.targetAnchor,
      colorIndex: -1,
    ),
  );

  return TimelineImageExportViewModel(
    targetTitle: targetTitle,
    metadataText: metadataText,
    events: events,
  );
}

String _sanitizeTitle(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '無題';
  return trimmed.replaceAll('\n', ' ');
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
