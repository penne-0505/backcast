---
title: Medo Reminder Notification Reference
status: active
draft_status: n/a
created_at: "2026-04-23"
updated_at: "2026-05-12"
references:
  - README.md
  - _docs/intent/medo/local_reminder_notifications.md
  - _docs/reference/medo/timeline_domain_reference.md
related_issues: []
related_prs: []
---

## Overview

本リファレンスは、`Medo` の目標時刻に対して「AまであとN分」というローカル通知を予約する API をまとめたものです。
対象実装は `lib/notifications/reminder_notifications.dart` です。

この層は UI を持たず、通知権限の要求、通知計画の作成、予約、キャンセルをサービスとして提供します。
通知方式は FCM ではなく端末内ローカル通知で、Android では正確アラーム権限を使わない通常精度のスケジュール通知を採用します。

## API

### `class ReminderNotificationRequest`

- **Summary**: リマインダー通知の予約入力を表す不変モデル
- **Parameters**:
  - `id (String)`: 通知 ID 生成に使う安定識別子
  - `targetTitle (String)`: 通知本文に入れる対象名
  - `targetDateTime (DateTime)`: 対象日時
  - `minutesBefore (List<int>)`: 対象日時の何分前に通知するか
- **Returns**: なし
- **Errors**: 負の `minutesBefore` は予約計画作成時に `ArgumentError`
- **Examples**:
  - `ReminderNotificationRequest(id: 'meeting', targetTitle: '会議開始', targetDateTime: startAt, minutesBefore: [30, 10, 0])`

### `class ReminderNotificationPlan`

- **Summary**: 実際に予約される 1 件の通知計画
- **Parameters**:
  - `notificationId (int)`: native 通知 API に渡す安定 ID
  - `fireDateTime (DateTime)`: 通知予定日時
  - `minutesBefore (int)`: 対象日時の何分前か
  - `title (String)`: 通知タイトル。現状は `Medo`
  - `body (String)`: 通知本文。例: `会議開始まであと10分`
  - `payload (String)`: 通知タップ時に参照できる JSON 文字列
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - `minutesBefore = 10` なら `targetDateTime - 10分` に通知する

### `class SkippedReminderNotification`

- **Summary**: 通知予定日時が現在以前で予約されなかった通知
- **Parameters**:
  - `notificationId (int)`: 予約していれば使われる予定だった通知 ID
  - `fireDateTime (DateTime)`: skip された通知予定日時
  - `minutesBefore (int)`: 対象日時の何分前か
  - `reason (ReminderNotificationSkipReason)`: skip 理由
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - 現在 08:30、対象 09:00、`minutesBefore = 30` は現在時刻と同じため skip

### `class ReminderNotificationScheduleResult`

- **Summary**: 予約された通知と skip された通知をまとめる結果モデル
- **Parameters**:
  - `scheduled (List<ReminderNotificationPlan>)`: 実際に予約対象になった通知
  - `skipped (List<SkippedReminderNotification>)`: 過去または現在時刻のため予約されなかった通知
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - UI 接続時は `skipped` を見て、古い通知が無視されたことをユーザーに示せる

### `class ReminderNotificationScheduler`

- **Summary**: 通知権限要求、通知計画作成、予約、キャンセルを扱うサービス
- **Parameters**:
  - `client (ReminderNotificationClient?)`: native 通知実装。未指定時は `FlutterLocalReminderNotificationClient`
  - `now (DateTime Function()?)`: 現在時刻 provider。テスト時に差し替え可能
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - `final scheduler = ReminderNotificationScheduler();`

### `Future<void> ReminderNotificationScheduler.initialize()`

- **Summary**: 通知プラグインと timezone を初期化する
- **Parameters**: なし
- **Returns**: なし
- **Errors**: native plugin の初期化失敗は呼び出し元へ伝播
- **Examples**:
  - UI 接続時はアプリ起動後、通知予約前に呼び出せる

### `Future<bool> ReminderNotificationScheduler.requestPermissions()`

- **Summary**: iOS / Android の通知権限を要求する
- **Parameters**: なし
- **Returns**: 明示的に拒否された platform がなければ `true`
- **Errors**: native plugin の権限要求失敗は呼び出し元へ伝播
- **Examples**:
  - ユーザー操作を起点に `await scheduler.requestPermissions()` を呼ぶ
- **Notes**:
  - アプリ起動時には自動要求しない

### `ReminderNotificationScheduleResult ReminderNotificationScheduler.buildReminderNotificationPlans(ReminderNotificationRequest request)`

- **Summary**: native plugin を呼ばず、通知計画だけを作る
- **Parameters**:
  - `request (ReminderNotificationRequest)`: 対象日時と何分前リスト
- **Returns**: 予約対象と skip 対象を分けた `ReminderNotificationScheduleResult`
- **Errors**: 負の `minutesBefore` がある場合は `ArgumentError`
- **Examples**:
  - テストや UI preview ではこのメソッドだけで通知内容を確認できる

### `Future<ReminderNotificationScheduleResult> ReminderNotificationScheduler.scheduleReminderNotifications(ReminderNotificationRequest request)`

- **Summary**: 現在より未来の通知だけを native plugin へ予約する
- **Parameters**:
  - `request (ReminderNotificationRequest)`: 対象日時と何分前リスト
- **Returns**: 実際に予約した通知と skip した通知の結果
- **Errors**: 負の `minutesBefore` がある場合は `ArgumentError`
- **Examples**:

```dart
final result = await scheduler.scheduleReminderNotifications(
  ReminderNotificationRequest(
    id: 'meeting',
    targetTitle: '会議開始',
    targetDateTime: DateTime(2026, 4, 23, 9),
    minutesBefore: const [30, 10, 0],
  ),
);
```

### `Future<List<int>> ReminderNotificationScheduler.cancelReminderNotifications(ReminderNotificationRequest request)`

- **Summary**: request の `id` と `minutesBefore` から導ける通知をキャンセルする
- **Parameters**:
  - `request (ReminderNotificationRequest)`: キャンセル対象を導く入力
- **Returns**: キャンセル呼び出しに使った通知 ID
- **Errors**: 負の `minutesBefore` がある場合は `ArgumentError`
- **Examples**:
  - 同じ `id` と `minutesBefore` を渡すと、過去に予約した同じ通知 ID をキャンセルできる

### `Future<void> ReminderNotificationScheduler.cancelAllReminderNotifications()`

- **Summary**: Medo が native notification plugin に登録した通知を一括キャンセルする
- **Parameters**: なし
- **Returns**: なし
- **Errors**: native plugin のキャンセル失敗は呼び出し元へ伝播
- **Examples**:
  - アカウント削除後のローカル cleanup で、個別 request が手元になくても予約済み通知をまとめて消す

## Notes

- `minutesBefore` は重複除去され、通知予定時刻が早い順に処理される
- `minutesBefore = 0` は `targetTitleまであと0分` として対象日時ちょうどに予約される
- 通知予定日時が現在以前の場合は予約せず、`skipped` に入る
- Android は `AndroidScheduleMode.inexactAllowWhileIdle` を使うため、OS 都合で通知が遅れる場合がある
- `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` は要求しない
- payload は `id`, `targetTitle`, `targetDateTime`, `minutesBefore` を含む JSON 文字列
- 一括キャンセルは `flutter_local_notifications` の `cancelAll()` を使う
