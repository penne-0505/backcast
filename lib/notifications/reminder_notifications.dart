import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const String _notificationTitle = 'Medo';
const String _androidChannelId = 'medo_reminders';
const String _androidChannelName = 'Medo reminders';
const String _androidChannelDescription = 'Target countdown reminders';
const String _androidNotificationIcon = 'notification_icon';
const int _fnvOffset = 0x811c9dc5;
const int _fnvPrime = 0x01000193;

@immutable
class ReminderNotificationRequest {
  const ReminderNotificationRequest({
    required this.id,
    required this.targetTitle,
    required this.targetDateTime,
    required this.minutesBefore,
  });

  final String id;
  final String targetTitle;
  final DateTime targetDateTime;
  final List<int> minutesBefore;
}

@immutable
class ReminderNotificationPlan {
  const ReminderNotificationPlan({
    required this.notificationId,
    required this.fireDateTime,
    required this.minutesBefore,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int notificationId;
  final DateTime fireDateTime;
  final int minutesBefore;
  final String title;
  final String body;
  final String payload;
}

@immutable
class SkippedReminderNotification {
  const SkippedReminderNotification({
    required this.notificationId,
    required this.fireDateTime,
    required this.minutesBefore,
    required this.reason,
  });

  final int notificationId;
  final DateTime fireDateTime;
  final int minutesBefore;
  final ReminderNotificationSkipReason reason;
}

enum ReminderNotificationSkipReason { pastOrNow }

@immutable
class ReminderNotificationScheduleResult {
  const ReminderNotificationScheduleResult({
    required this.scheduled,
    required this.skipped,
  });

  final List<ReminderNotificationPlan> scheduled;
  final List<SkippedReminderNotification> skipped;
}

abstract class ReminderNotificationClient {
  Future<void> initialize();

  Future<bool> requestPermissions();

  Future<void> schedule(ReminderNotificationPlan plan);

  Future<void> cancel(int notificationId);
}

class ReminderNotificationScheduler {
  ReminderNotificationScheduler({
    ReminderNotificationClient? client,
    DateTime Function()? now,
  }) : _client = client ?? FlutterLocalReminderNotificationClient(),
       _now = now ?? DateTime.now;

  final ReminderNotificationClient _client;
  final DateTime Function() _now;

  Future<void> initialize() => _client.initialize();

  Future<bool> requestPermissions() => _client.requestPermissions();

  ReminderNotificationScheduleResult buildReminderNotificationPlans(
    ReminderNotificationRequest request,
  ) {
    _validateRequest(request);

    final currentTime = _now();
    final scheduled = <ReminderNotificationPlan>[];
    final skipped = <SkippedReminderNotification>[];
    for (final minutesBefore in _uniqueMinutesBefore(request.minutesBefore)) {
      final fireDateTime = request.targetDateTime.subtract(
        Duration(minutes: minutesBefore),
      );
      final notificationId = _notificationId(request.id, minutesBefore);
      if (!fireDateTime.isAfter(currentTime)) {
        skipped.add(
          SkippedReminderNotification(
            notificationId: notificationId,
            fireDateTime: fireDateTime,
            minutesBefore: minutesBefore,
            reason: ReminderNotificationSkipReason.pastOrNow,
          ),
        );
        continue;
      }

      scheduled.add(
        ReminderNotificationPlan(
          notificationId: notificationId,
          fireDateTime: fireDateTime,
          minutesBefore: minutesBefore,
          title: _notificationTitle,
          body: '${request.targetTitle}まであと$minutesBefore分',
          payload: _payloadFor(request, minutesBefore),
        ),
      );
    }

    return ReminderNotificationScheduleResult(
      scheduled: List.unmodifiable(scheduled),
      skipped: List.unmodifiable(skipped),
    );
  }

  Future<ReminderNotificationScheduleResult> scheduleReminderNotifications(
    ReminderNotificationRequest request,
  ) async {
    await initialize();
    final result = buildReminderNotificationPlans(request);
    for (final plan in result.scheduled) {
      await _client.schedule(plan);
    }
    return result;
  }

  Future<List<int>> cancelReminderNotifications(
    ReminderNotificationRequest request,
  ) async {
    _validateRequest(request);
    final notificationIds = _uniqueMinutesBefore(
      request.minutesBefore,
    ).map((minutes) => _notificationId(request.id, minutes)).toList();
    for (final notificationId in notificationIds) {
      await _client.cancel(notificationId);
    }
    return List.unmodifiable(notificationIds);
  }
}

class FlutterLocalReminderNotificationClient
    implements ReminderNotificationClient {
  FlutterLocalReminderNotificationClient({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    await _setLocalTimezone();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings(_androidNotificationIcon),
      iOS: IOSInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: initializationSettings);
    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    await initialize();
    final androidResult = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final iosResult = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true);

    return (androidResult ?? true) && (iosResult ?? true);
  }

  @override
  Future<void> schedule(ReminderNotificationPlan plan) async {
    await initialize();
    await _plugin.zonedSchedule(
      id: plan.notificationId,
      title: plan.title,
      body: plan.body,
      scheduledDate: tz.TZDateTime.from(plan.fireDateTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          threadIdentifier: _androidChannelId,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: plan.payload,
    );
  }

  @override
  Future<void> cancel(int notificationId) async {
    await initialize();
    await _plugin.cancel(id: notificationId);
  }

  Future<void> _setLocalTimezone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } on Object {
      tz.setLocalLocation(tz.UTC);
    }
  }
}

void _validateRequest(ReminderNotificationRequest request) {
  for (final minutesBefore in request.minutesBefore) {
    if (minutesBefore < 0) {
      throw ArgumentError.value(
        minutesBefore,
        'minutesBefore',
        'Reminder notification offsets cannot be negative.',
      );
    }
  }
}

List<int> _uniqueMinutesBefore(List<int> minutesBefore) {
  final values = minutesBefore.toSet().toList()..sort((a, b) => b.compareTo(a));
  return values;
}

int _notificationId(String requestId, int minutesBefore) {
  var hash = _fnvOffset;
  for (final unit in '$requestId:$minutesBefore'.codeUnits) {
    hash ^= unit;
    hash = (hash * _fnvPrime) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

String _payloadFor(ReminderNotificationRequest request, int minutesBefore) {
  return jsonEncode({
    'id': request.id,
    'targetTitle': request.targetTitle,
    'targetDateTime': request.targetDateTime.toIso8601String(),
    'minutesBefore': minutesBefore,
  });
}
