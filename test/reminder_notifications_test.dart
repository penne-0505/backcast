import 'dart:convert';

import 'package:ato/notifications/reminder_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReminderNotificationScheduler', () {
    test('builds multiple reminder plans in chronological fire order', () {
      final scheduler = ReminderNotificationScheduler(
        client: _FakeReminderNotificationClient(),
        now: () => DateTime.utc(2026, 4, 23, 7),
      );
      final request = ReminderNotificationRequest(
        id: 'meeting',
        targetTitle: '会議開始',
        targetDateTime: DateTime.utc(2026, 4, 23, 9),
        minutesBefore: const [10, 30],
      );

      final result = scheduler.buildReminderNotificationPlans(request);

      expect(result.skipped, isEmpty);
      expect(result.scheduled.map((plan) => plan.minutesBefore), [30, 10]);
      expect(result.scheduled.map((plan) => plan.fireDateTime), [
        DateTime.utc(2026, 4, 23, 8, 30),
        DateTime.utc(2026, 4, 23, 8, 50),
      ]);
      expect(result.scheduled.first.title, 'Ato');
      expect(result.scheduled.first.body, '会議開始まであと30分');
    });

    test('deduplicates offsets and supports zero-minute reminders', () {
      final scheduler = ReminderNotificationScheduler(
        client: _FakeReminderNotificationClient(),
        now: () => DateTime.utc(2026, 4, 23, 7),
      );
      final request = ReminderNotificationRequest(
        id: 'departure',
        targetTitle: '出発',
        targetDateTime: DateTime.utc(2026, 4, 23, 8),
        minutesBefore: const [0, 10, 10, 0],
      );

      final result = scheduler.buildReminderNotificationPlans(request);

      expect(result.scheduled.map((plan) => plan.minutesBefore), [10, 0]);
      expect(result.scheduled.last.fireDateTime, DateTime.utc(2026, 4, 23, 8));
      expect(result.scheduled.last.body, '出発まであと0分');
    });

    test('skips reminders whose fire time is now or in the past', () {
      final scheduler = ReminderNotificationScheduler(
        client: _FakeReminderNotificationClient(),
        now: () => DateTime.utc(2026, 4, 23, 8, 30),
      );
      final request = ReminderNotificationRequest(
        id: 'meeting',
        targetTitle: '会議開始',
        targetDateTime: DateTime.utc(2026, 4, 23, 9),
        minutesBefore: const [60, 30, 10],
      );

      final result = scheduler.buildReminderNotificationPlans(request);

      expect(result.scheduled.map((plan) => plan.minutesBefore), [10]);
      expect(result.skipped.map((skip) => skip.minutesBefore), [60, 30]);
      expect(
        result.skipped.map((skip) => skip.reason),
        everyElement(ReminderNotificationSkipReason.pastOrNow),
      );
    });

    test('generates stable notification ids and JSON payloads', () {
      final scheduler = ReminderNotificationScheduler(
        client: _FakeReminderNotificationClient(),
        now: () => DateTime.utc(2026, 4, 23, 7),
      );
      final request = ReminderNotificationRequest(
        id: 'meeting',
        targetTitle: '会議開始',
        targetDateTime: DateTime.utc(2026, 4, 23, 9),
        minutesBefore: const [10],
      );

      final first = scheduler.buildReminderNotificationPlans(request);
      final second = scheduler.buildReminderNotificationPlans(request);
      final plan = first.scheduled.single;

      expect(plan.notificationId, second.scheduled.single.notificationId);
      expect(plan.notificationId, isNot(0));
      expect(jsonDecode(plan.payload), {
        'id': 'meeting',
        'targetTitle': '会議開始',
        'targetDateTime': '2026-04-23T09:00:00.000Z',
        'minutesBefore': 10,
      });
    });

    test('throws for negative reminder offsets', () {
      final scheduler = ReminderNotificationScheduler(
        client: _FakeReminderNotificationClient(),
        now: () => DateTime.utc(2026, 4, 23, 7),
      );

      expect(
        () => scheduler.buildReminderNotificationPlans(
          ReminderNotificationRequest(
            id: 'bad',
            targetTitle: 'Invalid',
            targetDateTime: DateTime.utc(2026, 4, 23, 9),
            minutesBefore: const [-1],
          ),
        ),
        throwsArgumentError,
      );
    });

    test(
      'schedules only future plans through the notification client',
      () async {
        final client = _FakeReminderNotificationClient();
        final scheduler = ReminderNotificationScheduler(
          client: client,
          now: () => DateTime.utc(2026, 4, 23, 8, 30),
        );
        final request = ReminderNotificationRequest(
          id: 'meeting',
          targetTitle: '会議開始',
          targetDateTime: DateTime.utc(2026, 4, 23, 9),
          minutesBefore: const [60, 10],
        );

        final result = await scheduler.scheduleReminderNotifications(request);

        expect(client.initializeCount, 1);
        expect(client.scheduled.map((plan) => plan.minutesBefore), [10]);
        expect(result.scheduled.map((plan) => plan.minutesBefore), [10]);
        expect(result.skipped.map((skip) => skip.minutesBefore), [60]);
      },
    );

    test('cancels every unique reminder id for the request', () async {
      final client = _FakeReminderNotificationClient();
      final scheduler = ReminderNotificationScheduler(
        client: client,
        now: () => DateTime.utc(2026, 4, 23, 7),
      );
      final request = ReminderNotificationRequest(
        id: 'meeting',
        targetTitle: '会議開始',
        targetDateTime: DateTime.utc(2026, 4, 23, 9),
        minutesBefore: const [10, 30, 10],
      );

      final cancelledIds = await scheduler.cancelReminderNotifications(request);

      expect(cancelledIds.length, 2);
      expect(client.cancelled, cancelledIds);
    });

    test('requests permissions through the notification client', () async {
      final client = _FakeReminderNotificationClient(permissionResult: false);
      final scheduler = ReminderNotificationScheduler(client: client);

      final result = await scheduler.requestPermissions();

      expect(result, isFalse);
      expect(client.permissionRequests, 1);
    });
  });
}

class _FakeReminderNotificationClient implements ReminderNotificationClient {
  _FakeReminderNotificationClient({this.permissionResult = true});

  final bool permissionResult;
  final List<ReminderNotificationPlan> scheduled = [];
  final List<int> cancelled = [];
  var initializeCount = 0;
  var permissionRequests = 0;

  @override
  Future<void> initialize() async {
    initializeCount++;
  }

  @override
  Future<bool> requestPermissions() async {
    permissionRequests++;
    return permissionResult;
  }

  @override
  Future<void> schedule(ReminderNotificationPlan plan) async {
    scheduled.add(plan);
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
  }
}
