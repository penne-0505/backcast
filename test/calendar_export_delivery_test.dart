import 'package:medo/calendar_export.dart';
import 'package:medo/calendar_export_delivery.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarExportDelivery', () {
    test(
      'forwards the request to the native opener on mobile platforms',
      () async {
        var nativeCalls = 0;
        late CalendarExportRequest capturedRequest;
        const result = CalendarExportResult(
          savedCount: 2,
          deletedCount: 1,
          calendarName: 'Test',
        );

        final delivery = CalendarExportDelivery(
          nativeOpener: (request, {calendarId}) async {
            nativeCalls++;
            capturedRequest = request;
            return result;
          },
          isNativePlatform: () => true,
        );

        final request = CalendarExportRequest(
          startDateTime: DateTime.utc(2026, 4, 23, 8),
          blocks: const [
            CalendarExportBlock(
              id: 'move',
              title: '移動',
              duration: Duration(minutes: 30),
            ),
          ],
          anchor: const CalendarExportAnchor(id: 'target', title: '会議開始'),
        );

        final output = await delivery.deliver(request: request);

        expect(nativeCalls, 1);
        expect(capturedRequest.startDateTime, request.startDateTime);
        expect(capturedRequest.blocks, request.blocks);
        expect(capturedRequest.anchor.title, '会議開始');
        expect(output.savedCount, 2);
        expect(output.deletedCount, 1);
        expect(output.calendarName, 'Test');
      },
    );

    test('keeps export group metadata on the delivered request', () async {
      late CalendarExportRequest capturedRequest;
      final delivery = CalendarExportDelivery(
        nativeOpener: (request, {calendarId}) async {
          capturedRequest = request;
          return const CalendarExportResult(savedCount: 1, deletedCount: 2);
        },
        isNativePlatform: () => true,
      );

      final request = CalendarExportRequest(
        startDateTime: DateTime.utc(2026, 5, 10, 8),
        exportGroup: CalendarExportGroup(
          planId: 'plan-1',
          targetDate: DateTime(2026, 5, 10, 23, 30),
        ),
        blocks: const [],
        anchor: const CalendarExportAnchor(id: 'target', title: '会議開始'),
      );

      final output = await delivery.deliver(request: request);

      expect(capturedRequest.exportGroup?.toNativePayload(), {
        'version': 1,
        'planId': 'plan-1',
        'targetDate': '2026-05-10',
      });
      expect(output.deletedCount, 2);
    });

    test('rejects non-native platforms without sharing', () async {
      var nativeCalls = 0;

      final delivery = CalendarExportDelivery(
        nativeOpener: (request, {calendarId}) async {
          nativeCalls++;
          return const CalendarExportResult(savedCount: 0);
        },
        isNativePlatform: () => false,
      );

      expect(
        () => delivery.deliver(
          request: CalendarExportRequest(
            startDateTime: DateTime.utc(2026, 4, 23, 8),
            blocks: const [],
            anchor: const CalendarExportAnchor(id: 'target', title: '会議開始'),
          ),
        ),
        throwsA(
          isA<CalendarExportException>().having(
            (e) => e.error,
            'error',
            CalendarExportError.unsupportedPlatform,
          ),
        ),
      );

      expect(nativeCalls, 0);
    });

    test('maps native permission_denied to domain error', () async {
      final delivery = CalendarExportDelivery(
        nativeOpener: (request, {calendarId}) async {
          throw PlatformException(code: 'permission_denied', message: 'denied');
        },
        isNativePlatform: () => true,
      );

      expect(
        () => delivery.deliver(
          request: CalendarExportRequest(
            startDateTime: DateTime.utc(2026, 4, 23, 8),
            blocks: const [],
            anchor: const CalendarExportAnchor(id: 'target', title: '会議開始'),
          ),
        ),
        throwsA(
          isA<CalendarExportException>().having(
            (e) => e.error,
            'error',
            CalendarExportError.permissionDenied,
          ),
        ),
      );
    });

    test('maps native no_writable_calendar to domain error', () async {
      final delivery = CalendarExportDelivery(
        nativeOpener: (request, {calendarId}) async {
          throw PlatformException(
            code: 'no_writable_calendar',
            message: 'none',
          );
        },
        isNativePlatform: () => true,
      );

      expect(
        () => delivery.deliver(
          request: CalendarExportRequest(
            startDateTime: DateTime.utc(2026, 4, 23, 8),
            blocks: const [],
            anchor: const CalendarExportAnchor(id: 'target', title: '会議開始'),
          ),
        ),
        throwsA(
          isA<CalendarExportException>().having(
            (e) => e.error,
            'error',
            CalendarExportError.noWritableCalendar,
          ),
        ),
      );
    });

    test('maps native invalid_payload to domain error', () async {
      final delivery = CalendarExportDelivery(
        nativeOpener: (request, {calendarId}) async {
          throw PlatformException(code: 'invalid_payload', message: 'bad');
        },
        isNativePlatform: () => true,
      );

      expect(
        () => delivery.deliver(
          request: CalendarExportRequest(
            startDateTime: DateTime.utc(2026, 4, 23, 8),
            blocks: const [],
            anchor: const CalendarExportAnchor(id: 'target', title: '会議開始'),
          ),
        ),
        throwsA(
          isA<CalendarExportException>().having(
            (e) => e.error,
            'error',
            CalendarExportError.invalidPayload,
          ),
        ),
      );
    });

    test('maps unknown native errors to saveFailed', () async {
      final delivery = CalendarExportDelivery(
        nativeOpener: (request, {calendarId}) async {
          throw PlatformException(code: 'unknown', message: 'oops');
        },
        isNativePlatform: () => true,
      );

      expect(
        () => delivery.deliver(
          request: CalendarExportRequest(
            startDateTime: DateTime.utc(2026, 4, 23, 8),
            blocks: const [],
            anchor: const CalendarExportAnchor(id: 'target', title: '会議開始'),
          ),
        ),
        throwsA(
          isA<CalendarExportException>().having(
            (e) => e.error,
            'error',
            CalendarExportError.saveFailed,
          ),
        ),
      );
    });
  });
}
