---
title: "Calendar Export Rebuild Deduplication"
status: active
draft_status: n/a
created_at: "2026-05-15"
updated_at: "2026-05-15"
references:
  - "../../intent/medo/calendar_export_ics.md"
  - "../../reference/medo/calendar_export_reference.md"
related_issues: []
related_prs: []
---

## Overview

Medo のカレンダー登録は、現在のタイムラインを block ごとの端末カレンダー event として直接追加する。
現状は毎回新規 insert するため、同じタイムラインを再エクスポートすると、過去の登録済み event と最新版 event が重複する。

この plan では、登録済み event と現在のタイムラインを field 単位で merge しようとせず、同一 export group を削除してから現在状態を再登録する。
ユーザーの期待は「このタイムラインの最新版をカレンダーへ反映する」ことであり、差分更新より完全再構築のほうが削除・並び替え・時間変更を一貫して扱える。

## Scope

- Calendar export request に、削除対象を識別するための export group metadata を追加する。
- export group は、少なくとも current plan id と対象日を含む。
- Android native delivery で、同一 export group marker を持つ既存 event を削除してから新規 event を insert する。
- iOS native delivery でも同じ設計に追従できる境界を用意する。
- 登録される event には、Medo が作成した event であることと export group を識別できる marker を保存する。
- UI の確認文言は、同じタイムライン・同じ対象日の前回登録を置き換える可能性を示す。
- calendar export reference と intent / guide 相当の説明を、実装結果に合わせて更新する。

## Non-Goals

- カレンダー event の field-by-field merge。
- ユーザーが手動編集したカレンダー event の内容を保持する高度な conflict resolution。
- Google Calendar API など、クラウドカレンダー API への直接同期。
- 別日へ登録済みの同一 timeline を `timelineId` だけでまとめて削除する挙動。
- 同期カレンダーでの即時反映保証。端末 Calendar Provider / sync adapter / カレンダーアプリ表示更新は引き続き非同期であり得る。

## Requirements

- **Functional**: 同じ current plan id と対象日の export を再実行した場合、前回 Medo が作った event を削除してから現在の block / anchor を登録する。
- **Functional**: 対象日が異なる export は削除対象に含めない。
- **Functional**: Medo marker がない event は、タイトルや時刻が一致していても削除しない。
- **Functional**: 削除と再登録は、可能な限り 1 回の native operation として扱い、成功時の登録件数を UI に返す。
- **Functional**: 削除対象件数を native result または diagnostics で確認できるようにする。
- **Non-Functional**: marker には timeline title や block title などの自由入力本文を識別子として使わない。
- **Non-Functional**: export group key は安定し、再起動後も同じ plan / 対象日に対して同じ値になる。
- **Non-Functional**: Calendar Provider / EventKit の同期遅延により、一時的に削除と追加が段階的に見える可能性を UI / docs で過度に隠さない。

## Design

### Export Group

Export group は `planId + targetDate` を基本単位にする。
`planId` 単独だと、同じタイムラインを今日と明日など複数日に登録した場合に別日の event まで削除してしまう。

`targetDate` は、ユーザーが export UI で選んだ基準日、または request の anchor date から導出した日付を使う。
実装時は、日跨ぎタイムラインの扱いが UI 表示と一致するよう、`buildCalendarExportRequest` の `baseDate` と `CalendarExportPreview.anchorDateTime` のどちらを canonical date とするかを明示する。

### Marker Storage

各 native event には、Medo が作成した event であることを示す marker と export group key を保存する。
Android では `CalendarContract.Events.DESCRIPTION` がアプリから書き込み可能であり、初期候補とする。
iOS では `EKEvent.notes` を初期候補とする。

marker は人間向け説明と機械可読行を分ける。
例:

```text
Created by Medo.
MEDO_EXPORT_VERSION=1
MEDO_EXPORT_PLAN_ID=<plan-id>
MEDO_EXPORT_DATE=<yyyy-mm-dd>
MEDO_EXPORT_EVENT_ID=<block-or-anchor-id>
```

自由入力の block title や timeline title は marker key に使わない。
必要なら notes / description の既存内容と混ざらないよう、Medo marker block の開始・終了 sentinel を設ける。

### Rebuild Flow

1. Flutter UI が current plan id と対象日を含む `CalendarExportRequest` を組み立てる。
2. Native delivery は export group marker に一致する既存 event を検索する。
3. 一致 event を削除する。
4. 現在の `projectCalendarExportEvents` から全 event を insert する。
5. `savedCount` に登録件数、必要なら `deletedCount` を含む result を返す。

Android は `ContentProviderOperation` の batch で delete + insert をまとめる。
iOS は EventKit の save / remove を `commit: false` で積み、最後に `commit()` する。

## Tasks

1. `CalendarExportRequest` / request builder に current plan id と export target date を渡す境界を追加する。
2. native payload に export group marker 情報を追加する。
3. Android `MainActivity.kt` で marker 付き event の delete-before-insert を実装する。
4. iOS `AppDelegate.swift` で同じ rebuild flow を実装できるようにし、既存 MethodChannel 名不一致の別件修正との順序を確認する。
5. UI のプレビュー / 実行文言を「前回登録を置き換える」前提に更新する。
6. Unit test / native-adjacent test を追加し、同一 group の再 export と別日の export 非削除を検証する。
7. `calendar_export_reference.md` と関連 intent / README の説明を実装後の仕様へ同期する。

## Implementation Notes

- `CalendarExportGroup(planId, targetDate)` を追加し、UI から current plan id と選択日を native delivery へ渡す。
- Android は `CalendarContract.Events.DESCRIPTION` の Medo marker を条件に、同じ calendar id / plan id / target date の event を batch delete してから insert する。
- iOS は `EKEvent.notes` の Medo marker を条件に、同じ calendar / plan id / target date の event を remove してから save する。
- iOS の MethodChannel 名は Dart 側と同じ `medo/calendar_export` に揃えた。
- iOS 17+ は重複削除に既存 event の読み取りが必要なため、write-only ではなく full access を要求する。

## Test Plan

- `buildCalendarExportRequest` が同じ plan / 同じ対象日に対して安定した export group を作る。
- 別対象日の export group が別 key になる。
- native payload に marker 情報が含まれる。
- Android の delete selection が Medo marker と export group の両方を条件にする。
- 同一 export group の既存 event が削除され、新しい event が登録される。
- marker がない event、または別日の marker を持つ event は削除されない。
- `flutter test` で calendar export / request builder / delivery 周辺の unit test を通す。
- Android 実機または emulator で、同じタイムラインを 2 回登録しても重複が増えないことを確認する。

## Deployment / Rollout

Schema 変更は不要。
端末カレンダー内にすでに重複登録済みの event は、marker がないため初回実装では自動削除しない。
実装後に作成された marker 付き event から、同一 plan / 同一対象日の rebuild deduplication が効く。

もし削除 selection が広すぎる兆候が出た場合は、marker 付き削除を停止し、新規 insert のみに戻せるよう delivery 境界の変更を小さく保つ。
