import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'calendar_export.dart';

enum CalendarExportError {
  permissionDenied,
  noWritableCalendar,
  invalidPayload,
  saveFailed,
  unsupportedPlatform,
}

class CalendarExportException implements Exception {
  const CalendarExportException(this.error, [this.message]);

  final CalendarExportError error;
  final String? message;

  @override
  String toString() => 'CalendarExportException: $error${message != null ? ' ($message)' : ''}';
}

class CalendarExportResult {
  const CalendarExportResult({
    required this.savedCount,
    this.calendarName,
  });

  final int savedCount;
  final String? calendarName;
}

typedef CalendarExportNativeOpener = Future<CalendarExportResult> Function(
  CalendarExportRequest request, {
  String? calendarId,
});

class CalendarExportDelivery {
  CalendarExportDelivery({
    CalendarExportNativeOpener? nativeOpener,
    bool Function()? isNativePlatform,
  })  : _nativeOpener = nativeOpener ?? _defaultNativeOpener,
        _isNativePlatform = isNativePlatform ?? _defaultIsNativePlatform;

  final CalendarExportNativeOpener _nativeOpener;
  final bool Function() _isNativePlatform;

  Future<CalendarExportResult> deliver({
    required CalendarExportRequest request,
    String? calendarId,
  }) async {
    if (!_isNativePlatform()) {
      throw const CalendarExportException(
        CalendarExportError.unsupportedPlatform,
        'Calendar export requires Android or iOS native integration.',
      );
    }

    try {
      return await _nativeOpener(request, calendarId: calendarId);
    } on PlatformException catch (e) {
      throw CalendarExportException(
        _mapNativeError(e),
        e.message,
      );
    }
  }
}

const MethodChannel _channel = MethodChannel('ato/calendar_export');

bool _defaultIsNativePlatform() {
  if (kIsWeb) {
    return false;
  }

  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

Future<CalendarExportResult> _defaultNativeOpener(
  CalendarExportRequest request, {
  String? calendarId,
}) async {
  final events = projectCalendarExportEvents(request)
      .map((event) => event.toNativePayload())
      .toList(growable: false);

  final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
    'saveCalendarExport',
    <String, Object?>{
      'events': events,
      'calendarId': calendarId,
    },
  );

  return CalendarExportResult(
    savedCount: (result?['savedCount'] as num?)?.toInt() ?? events.length,
    calendarName: result?['calendarName'] as String?,
  );
}

CalendarExportError _mapNativeError(PlatformException e) {
  return switch (e.code) {
    'permission_denied' => CalendarExportError.permissionDenied,
    'no_writable_calendar' => CalendarExportError.noWritableCalendar,
    'invalid_payload' => CalendarExportError.invalidPayload,
    'save_failed' => CalendarExportError.saveFailed,
    _ => CalendarExportError.saveFailed,
  };
}
