import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const _minutesPerDay = 24 * 60;

int _normalizeMinutes(int minutes) {
  final normalized = minutes % _minutesPerDay;
  return normalized < 0 ? normalized + _minutesPerDay : normalized;
}

/// 現在のプラットフォームに合う時刻 picker を開き、分単位の時刻を返す。
Future<int?> showPlatformTimePicker(
  BuildContext context, {
  required int initialMinutes,
}) {
  final normalizedMinutes = _normalizeMinutes(initialMinutes);
  final platform = defaultTargetPlatform;

  if (!kIsWeb &&
      (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS)) {
    return _showCupertinoTimePicker(context, normalizedMinutes);
  }

  return _showMaterialTimePicker(context, normalizedMinutes);
}

Future<int?> _showMaterialTimePicker(
  BuildContext context,
  int initialMinutes,
) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: initialMinutes ~/ 60,
      minute: initialMinutes % 60,
    ),
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );

  if (picked == null) return null;
  return picked.hour * 60 + picked.minute;
}

Future<int?> _showCupertinoTimePicker(
  BuildContext context,
  int initialMinutes,
) {
  var selectedMinutes = initialMinutes;

  return showCupertinoModalPopup<int>(
    context: context,
    builder: (context) {
      return SafeArea(
        top: false,
        child: Container(
          height: 320,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('キャンセル'),
                    ),
                    CupertinoButton(
                      onPressed: () =>
                          Navigator.of(context).pop(selectedMinutes),
                      child: const Text('完了'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(
                    2000,
                    1,
                    1,
                    initialMinutes ~/ 60,
                    initialMinutes % 60,
                  ),
                  onDateTimeChanged: (value) {
                    selectedMinutes = value.hour * 60 + value.minute;
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
