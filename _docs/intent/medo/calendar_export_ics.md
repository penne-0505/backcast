---
title: Calendar Export via iCalendar
status: active
draft_status: n/a
created_at: "2026-04-23"
updated_at: "2026-05-18"
references:
  - README.md
  - _docs/archives/plan/Core/calendar-registration-enhancement.md
  - _docs/plan/Core/calendar-export-rebuild-deduplication.md
  - _docs/reference/medo/calendar_export_reference.md
  - _docs/reference/medo/timeline_domain_reference.md
related_issues: []
related_prs: []
---

## Context

`Medo` の逆算タイムラインは、行動ブロックと目標アンカーを最終的に実際の予定として扱える必要があります。
ただし `.ics` 生成 API そのものは UI から独立させ、端末カレンダーへの直接登録や権限処理は別層に分離します。

また、呼び出し側が「今日」へ書き出す前提にすると、テストしづらく、ユーザーが意図した日付とずれるリスクがあります。
そのため、書き出しロジックは開始 `DateTime` を明示的に受け取り、そこから各イベントを前向きに積み上げる必要があります。

## Decision

- カレンダー書き出しの中核は iCalendar (`.ics`) 文字列生成に限定する
- 端末カレンダーへの直接書き込みや共有 UI は `.ics` 生成層に含めない
- API は開始 `DateTime`、イベントブロック列、アンカーを明示的に受け取る
- 書き出し対象はすべて `VEVENT` とし、アンカーもイベントとして出力する
- `Duration.zero` の block と anchor は、`DTSTART` と `DTEND` が同一の 0 分イベントとして出力する
- `DTSTAMP` は request の `generatedAt` を優先し、未指定時は `startDateTime` を使うことで `DateTime.now()` へ依存しない
- `TimelineState` とユーザー選択日から `CalendarExportRequest` を組み立てる処理は、テスト可能な純粋関数 `buildCalendarExportRequest` として切り出す
- 登録前にユーザーが内容を確認できるよう、`CalendarExportPreview` で開始日時、アンカー日時、件数、日跨ぎ状態を導出する
- native カレンダー登録は `CalendarExportDelivery` で統一し、戻り値に登録件数と登録先カレンダー名を含める
- 失敗時は `PlatformException` の code を UI に直接漏らさず、`CalendarExportError` として domain error に変換する
- Android は `CalendarContract` へ直接書き込み、iOS は `EventKit` を使う
- native 登録では、`CalendarExportGroup(planId, targetDate)` が指定された場合、同じ plan / 同じ対象日の Medo marker 付き event を削除してから現在の timeline を再登録する
  - field-by-field merge は行わない
  - `planId` 単独ではなく `planId + targetDate` を削除単位にし、別日に登録した同じ timeline を巻き込まない
  - marker がない event は、タイトルや時刻が一致していても削除しない
  - marker は `MEDO_EXPORT_BEGIN` / `MEDO_EXPORT_END` を持つ行単位の block として保存し、plan id の部分一致や SQL `LIKE` wildcard による過剰削除を避ける
- iOS 17+ では、前回登録 event の検索・削除が必要なため `requestFullAccessToEvents` を使い、それ以前では `requestAccess(to: .event)` にフォールバックする
- Android / iOS の両方で、明示的な `calendarId` 未指定時は既定の書き込み可能カレンダーを自動選択する

## Alternatives

- ネイティブカレンダーへ直接追加する:
  `.ics` 生成と分離した adapter 層として実装することで、権限や失敗時分岐を扱いやすくした。これは現在の `CalendarExportDelivery` の形で採用している。
- 0 分要素を 1 分イベントに伸ばす:
  カレンダーアプリ上で見つけやすくなる可能性はあるが、`actionPoint` とアンカーが「時間を消費しない節目」であるドメイン上の意味を変えるため不採用
- 書き出し時に `DateTime.now()` から日付を補完する:
  利用者が意図した日付とずれる可能性があり、テストも非決定的になるため不採用
- Google Calendar API などのクラウド同期を使う:
  初回スコープでは権限とセットアップコストが大きすぎるため不採用
- 登録済み event を merge 更新する:
  block 削除、順序変更、duration 変更、anchor 変更を個別差分として扱うと実装と失敗時復旧が複雑になる。ユーザーの期待は「この timeline の最新版を反映する」ことであるため、同一 export group の完全再構築を採用する
- `planId` だけで前回登録を削除する:
  同じ timeline を別日に登録した予定まで削除するため不採用

## Rationale

- `.ics` は iOS / Android の標準カレンダーアプリに渡しやすく、権限なしの純粋ロジックとして実装できる
- UI やプラットフォームアダプタを後から追加しても、`.ics` 生成 API を境界として再利用できる
- 0 分イベントをそのまま出すことで、`actionPoint` とアンカーの「瞬間の節目」という意味を保てる
- `startDateTime` を必須にすると、逆算 UI の `targetTime` や現在日付に依存せず、任意の日付へ安全に書き出せる
- `buildCalendarExportRequest` を純粋関数にすることで、日跨ぎや 0 分ブロックの計算を unit test で担保できる
- `CalendarExportPreview` を分離することで、UI は `.ics` 生成の詳細を知らずにプレビュー情報を表示できる
- `CalendarExportDelivery` で domain result / error を導入することで、Android / iOS の違いを吸収し、UI では同じエラーハンドリングができる
- 重複制御では既存 event の検索と削除が必要になるため、iOS 17+ でも write-only access ではなく full access を使う
- Medo marker は native event の notes / description に保存するため、既存の marker なし重複 event は初回実装では自動削除しない

## Consequences / Impact

- カレンダーアプリによっては 0 分イベントの表示方法が異なる可能性がある
- 直接登録や共有 UI が必要になった場合は、`generateCalendarIcs` の戻り値を利用するアダプタを別層に追加する
- 複数日をまたぐ長いタイムラインも、`DateTime.add(Duration)` に従って UTC の `DTSTART` / `DTEND` として表現される
- UI 接続時は、画面の `targetTime` からではなく、ユーザーが選んだ書き出し開始日時を `CalendarExportRequest.startDateTime` に渡す必要がある
- 登録前プレビューにより、ユーザーは日跨ぎや実際の開始時刻を確認してから登録できる
- native 層のエラーハンドリングが統一されたことで、UI では `CalendarExportException` のみを扱えばよくなった
- 同じ timeline / 同じ対象日を再登録した場合、前回の Medo marker 付き event は削除される。同期カレンダーでは削除と追加が段階的に表示される可能性は残る

## Rollback / Follow-ups

- もし 0 分イベントの互換性問題が大きい場合は、UI または adapter 層で表示用の最小 duration を選べる設計を検討する
- 共有シート、ファイル保存、ネイティブカレンダー登録を追加する場合も、まず `.ics` 生成 API を呼び出す構成を維持する
- Android / iOS でネイティブ保存が使えない場合は、共有シートへ戻さず明示的なエラーとして扱う。必要なら別の export 導線を後続で追加する
- ユーザーが書き込み先カレンダーを選べる UI は、現状では未対応。必要に応じて `CalendarExportDelivery.deliver` の `calendarId` パラメータを UI から渡せるように拡張する
