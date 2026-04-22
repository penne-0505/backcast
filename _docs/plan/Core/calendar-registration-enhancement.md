---
title: Calendar Registration Enhancement
status: proposed
draft_status: n/a
created_at: "2026-05-02"
updated_at: "2026-05-02"
references:
  - README.md
  - TODO.md
  - _docs/intent/backcast/calendar_export_ics.md
  - _docs/reference/backcast/calendar_export_reference.md
  - _docs/reference/backcast/timeline_domain_reference.md
  - https://developer.apple.com/documentation/EventKit/accessing-calendar-using-eventkit-and-eventkitui
  - https://developer.android.com/identity/providers/calendar-provider
  - https://www.rfc-editor.org/rfc/rfc5545
related_issues: []
related_prs: []
---

## Overview

`Ato` のカレンダー登録を、単にボタン押下で native API へ渡す状態から、登録前に内容を確認でき、失敗理由を切り分けやすく、OS 権限の変化に追従できる状態へ強化する。

既存の `CalendarExportRequest` / `projectCalendarExportEvents` / `generateCalendarIcs` は維持し、実装の主眼は「登録 request の組み立て」「登録前プレビュー」「native delivery の結果・権限・登録先扱い」を明確にすることに置く。

## Scope

- `plan_panel.dart` に閉じている登録日時計算を、テスト可能な純粋ロジックへ切り出す
- 登録前に、開始日時、終了日時、登録イベント数、アンカー、日跨ぎ有無を確認できる UI を追加する
- `CalendarExportDelivery` の戻り値を、成功/失敗だけでなく登録件数・登録先・native error code を扱える形へ拡張する
- Android の `CalendarContract` 連携で、書き込み可能なカレンダー候補を扱えるようにする
- iOS の `EventKit` 連携を iOS 17 以降のカレンダー access level に合わせる
- 権限拒否、書き込み可能カレンダーなし、payload 不正、native 保存失敗をユーザー向け文言と debug log で区別する
- 既存の `.ics` 生成仕様、0 分イベント、明示 `startDateTime` の方針を壊さない

## Non-Goals

- 画像エクスポート、Markdown / text export、clipboard export、plan JSON import/export は扱わない
- Google Calendar API などのクラウド同期は扱わない
- 自動重複検出や既存イベント更新は初回スコープに含めない。これは iOS で full access を要求する方向へ寄りやすく、登録専用機能としては権限が重い
- `.ics` ファイル共有 UI やファイル保存は扱わない
- カレンダーイベントの reminder / attendee / location / recurrence は扱わない
- Free / Pro gate との接続は扱わない。画像エクスポート gate は別計画で扱う

## Requirements

- **Functional**: ユーザーは登録前に、どの日付へ何件のイベントが登録されるかを確認できる
- **Functional**: タイムラインが日付を跨ぐ場合、開始日とアンカー日が UI 上で判別できる
- **Functional**: Android では書き込み可能カレンダーの候補を native 側で取得し、選択または既定選択できる
- **Functional**: iOS では iOS 17 以降に `requestWriteOnlyAccessToEvents` を優先し、古い OS では既存の `requestAccess(to: .event)` 系へ安全にフォールバックする
- **Functional**: `NSCalendarsWriteOnlyAccessUsageDescription` を追加し、古い OS 向けの `NSCalendarsUsageDescription` は維持する
- **Functional**: 成功時は登録件数と登録先を表示する。登録先名が取得できない場合は、OS のデフォルトカレンダーとして扱う
- **Functional**: 失敗時は `permission_denied`, `no_writable_calendar`, `invalid_payload`, `save_failed`, `unsupported_platform` を区別する
- **Non-Functional**: 登録 request の日時計算は `DateTime.now()` に直接依存しない形でテストできる
- **Non-Functional**: 0 分 block と anchor は 0 分イベントのまま扱い、互換性目的で 1 分へ伸ばさない
- **Non-Functional**: UI 文言は最小限にし、登録前確認とエラー理解に必要な情報だけを表示する
- **Non-Functional**: 既存の `calendar_export_test.dart` / `calendar_export_delivery_test.dart` を維持し、追加ロジックには targeted test を追加する

## Tasks

1. `UI-Bug-17` の内容を再確認し、未解決なら先に解消する。特に date null guard、日跨ぎ計算、入力上書き race をこの計画の前提として扱う
2. `plan_panel.dart` の `_export()` から、`TimelineState` と選択日を `CalendarExportRequest` へ変換する純粋関数を抽出する
3. 抽出した request builder に、同日登録、前日開始、複数日跨ぎ、0 分 block、空 block の unit test を追加する
4. 登録前プレビュー UI を追加し、開始日時、アンカー日時、登録件数、日跨ぎ状態を表示する
5. `CalendarExportDelivery` に domain result / domain error を導入し、`PlatformException` の code を UI 文言へ直接漏らさない
6. Android native channel に writable calendar の取得、選択 calendar id の受け取り、登録結果の件数返却を追加する
7. iOS native channel の権限要求を iOS 17+ とそれ以前で分岐し、write-only access を優先する
8. iOS / Android の permission description と native error code を、この計画で定義した domain error へ対応付ける
9. `_docs/reference/backcast/calendar_export_reference.md` と `_docs/intent/backcast/calendar_export_ics.md` を、実装後の responsibility boundary に合わせて更新する
10. README の現状制約に、カレンダー登録の対応範囲と未対応範囲を反映する

## Test Plan

- `/home/penne/sdk/flutter/flutter/bin/flutter test test/calendar_export_test.dart test/calendar_export_delivery_test.dart`
- request builder 用の新規 targeted test を追加し、日付跨ぎと 0 分イベントを検証する
- Android native payload は、calendar id 未指定、calendar id 指定、書き込み可能カレンダーなし、payload 不正の分岐を確認する
- iOS native payload は、iOS 17+ の write-only request path と古い OS fallback path をコードレビューで確認する
- 実機またはエミュレータで、権限許可、権限拒否、登録成功、登録先なしの手動検証を行う
- `flutter analyze` は実装完了後に実行する。既存要因で全体が落ちる場合は、該当エラーと本変更由来かを切り分けて報告する

## Deployment / Rollout

- まず Android / iOS の native integration を debug build で検証する
- iOS 17+ の権限文言変更は実機で prompt 表示を確認する
- Android は Calendar Provider へ直接書き込むため、登録に失敗した場合はイベントが部分登録されないことを確認する
- リリース前に、登録 UI の文言が過度な説明になっていないかレビューする
- 問題が出た場合は、UI の登録導線だけを無効化し、`CalendarExportRequest` と `.ics` 生成の純粋ロジックは維持する

## Review Checklist

- 既存の `CalendarExportRequest(startDateTime, blocks, anchor)` 境界が保たれている
- `DateTime.now()` は UI の初期値や generatedAt 注入に限られ、計算ロジックのテストを妨げていない
- 0 分イベントが 1 分イベントへ暗黙変換されていない
- iOS 17+ の EventKit 権限変更を考慮している
- Android / iOS の native error が Flutter UI で同じ domain error として扱われている
- ドキュメントが実装後の責務境界を正しく反映している
