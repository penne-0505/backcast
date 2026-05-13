---
title: "Account Deletion Local Cleanup"
status: proposed
draft_status: n/a
created_at: "2026-05-12"
updated_at: "2026-05-12"
references:
  - "../../intent/medo/drift_persistence_repository.md"
  - "../../intent/medo/local_reminder_notifications.md"
  - "../../intent/medo/revenuecat_supabase_entitlement_sync.md"
related_issues: []
related_prs: []
---

## Overview

Medo のアカウント削除は Supabase Edge Function で Auth user を削除し、Supabase 側の課金関連 row は FK cascade で消す。一方、端末内の Drift DB、予約済みローカル通知、Pro entitlement cache、共有用一時ファイルは Supabase 側の cascade では消えない。

この plan では、サーバー側削除が成功した後に端末内の個人データをまとめて削除する境界を追加する。

## Scope

- Drift DB のユーザー作成データを削除する。
  - `plans`
  - `plan_blocks`
  - `plan_snapshots`
  - `timeline_templates`
  - `timeline_template_blocks`
  - `app_preferences` の現在タイムライン参照
- Drift DB の Pro entitlement cache を削除する。
  - `cached_pro_entitlements`
- Medo が予約したローカル通知を一括キャンセルする。
- 共有画像の一時ファイルを削除できる範囲で試行する。
- 削除後に Riverpod provider から古い予定・テンプレート・Pro cache が再表示されないようにする。

## Non-Goals

- Supabase Edge Function のサーバー側削除契約の再設計。
- RevenueCat customer 自体の削除。
- プライバシーポリシーや削除ページの文言更新。
- Store subscription の解約代行。

## Requirements

- **Functional**: `delete-account` が成功した後、ローカル cleanup を実行してからログアウト済み状態にする。
- **Functional**: ローカル cleanup が失敗した場合は削除フローを成功扱いにせず、ユーザーが再試行または再起動後 cleanup できる状態を残す。
- **Functional**: 通知は個別 ID だけでなく、Medo が予約した通知をまとめてキャンセルできる API を持つ。
- **Non-Functional**: RevenueCat SDK 対応 platform では logout/reset 相当を呼び、旧 Supabase user UUID の entitlement cache が端末に残らないようにする。
- **Non-Functional**: サーバー側削除成功後にローカル cleanup が失敗しても、再起動後に旧ローカル DB が自動表示されない設計を優先する。

## Tasks

1. Drift cleanup repository/service を追加し、対象テーブルを transaction で削除する。
2. Pro entitlement cache repository に全削除 API を追加する。
3. `ReminderNotificationScheduler` / client に全通知キャンセル API を追加する。
4. Account deletion cleanup service を auth flow から呼び出す。
5. Provider invalidation と current plan state reset を追加する。
6. Unit test と関連 docs を更新する。

## Test Plan

- Drift cleanup 後に予定、block、snapshot、template、template block、current plan preference、Pro entitlement cache が空になる。
- Account deletion cleanup が通知キャンセル API を呼ぶ。
- `ReminderNotificationScheduler.cancelAllReminderNotifications()` が client の一括キャンセルを呼ぶ。
- `flutter test` の関連 test を実行する。

## Deployment / Rollout

Schema 変更は不要。アプリ更新後、次にアカウント削除したユーザーから端末内 cleanup が適用される。
