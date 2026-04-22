---
title: Local Reminder Notifications
status: active
draft_status: n/a
created_at: "2026-04-23"
updated_at: "2026-04-23"
references:
  - README.md
  - _docs/reference/backcast/reminder_notification_reference.md
  - _docs/reference/backcast/timeline_domain_reference.md
related_issues: []
related_prs: []
---

## Context

`Ato` のタイムラインは、目標時刻やイベントに近づいたことをユーザーへ知らせる必要があります。
今回の対象は UI 接続ではなく、対象日時・対象名・何分前リストから通知を予約できるサービス層の追加です。

また、「AまであとN分」という通知はユーザー端末上の予定に対するリマインダーであり、現段階ではサーバーから配信する必要はありません。

## Decision

- 通知方式は FCM ではなく、`flutter_local_notifications` によるローカル通知にする
- API は対象日時、対象名、複数の「何分前」リストを明示的に受け取る
- Android は通常精度の `AndroidScheduleMode.inexactAllowWhileIdle` を使う
- Android の `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` は追加しない
- 通知権限の要求は `requestPermissions()` に閉じ込め、アプリ起動時に自動で権限ダイアログを出さない
- 通知予定日時が現在以前のものは予約せず、結果の `skipped` に入れる

## Alternatives

- FCM リモート通知:
  Firebase、サーバー、トークン管理が必要になり、端末内で完結するリマインダーには過剰なため不採用
- 正確アラーム:
  時刻精度は高いが Android 12 以降の権限・審査・拒否時フォールバックが増えるため、今回の初期実装では不採用
- UI 層に直接 plugin 呼び出しを書く:
  UI 非接続の要件に反し、テストもしづらくなるため不採用

## Rationale

- ローカル通知なら、永続化やカレンダー書き出しとは独立したサービスとして追加できる
- 通知計画作成を native plugin 呼び出しから分離すると、時刻計算、重複除去、skip 判定、ID 生成を unit test で検証できる
- 通常精度を選ぶことで、ユーザーへの権限負荷と platform 固有分岐を抑えられる
- 権限要求を明示メソッドに分けることで、将来 UI 接続時にユーザー操作を起点に permission prompt を出せる

## Consequences / Impact

- Android では OS の省電力制御により、通知が指定時刻より遅れる場合がある
- Android 13 以降では通知権限が拒否されると通知は表示されない
- 端末再起動後の再予約は plugin の boot receiver に依存する
- UI 接続時は、予約前に `requestPermissions()` をユーザー操作から呼び出す導線が必要

## Rollback / Follow-ups

- 正確な時刻通知が必須になった場合は、正確アラーム権限と拒否時フォールバックを別途設計する
- サーバー起点通知が必要になった場合は、ローカル通知サービスとは別に FCM 層を追加する
- 通知タップ後の deep link や画面遷移は、UI 接続時に payload を使って追加する
