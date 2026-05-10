---
title: Medo Calendar Export Reference
status: active
draft_status: n/a
created_at: "2026-04-23"
updated_at: "2026-05-10"
references:
  - README.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/intent/medo/calendar_export_ics.md
related_issues: []
related_prs: []
---

## Overview

本リファレンスは、`Medo` のタイムラインを iOS / Android のカレンダーアプリへ取り込みやすい iCalendar (`.ics`) 文字列へ変換する API と、端末カレンダーへの native 登録 delivery をまとめたものです。
対象実装は `lib/calendar_export.dart`、`lib/calendar_export_request_builder.dart`、`lib/calendar_export_delivery.dart` です。

`lib/calendar_export.dart` は UI、共有シート、ファイル保存、端末カレンダー権限処理を持たない純粋ロジックです。
呼び出し側は「今日」や現在時刻ではなく、最初のイベント開始 `DateTime`、書き出し対象ブロック、最後に置くアンカーを明示して渡します。

`lib/calendar_export_request_builder.dart` は `TimelineState` とユーザー選択日から `CalendarExportRequest` を組み立て、登録前プレビュー情報を提供します。

`lib/calendar_export_delivery.dart` は Android / iOS の native カレンダーへイベントを書き込む層です。戻り値には登録件数と登録先カレンダー名を含み、失敗時は domain error を投げます。

## API

### `class CalendarExportRequest`

- **Summary**: `.ics` 生成に必要な入力全体を表す不変モデル
- **Parameters**:
  - `startDateTime (DateTime)`: 先頭ブロックの絶対開始日時
  - `blocks (List<CalendarExportBlock>)`: 開始日時から前向きに並べるイベント列
  - `anchor (CalendarExportAnchor)`: すべてのブロック後に 0 分イベントとして出力するアンカー
  - `generatedAt (DateTime?)`: `DTSTAMP` に使う生成日時。未指定時は `startDateTime`
  - `productId (String)`: `PRODID`。既定値は `-//Medo//Calendar Export//EN`
  - `calendarName (String)`: `X-WR-CALNAME`。既定値は `Medo`
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - `CalendarExportRequest(startDateTime: DateTime.utc(2026, 4, 23, 8), blocks: blocks, anchor: anchor)`

### `class CalendarExportBlock`

- **Summary**: カレンダー上の 1 つの `VEVENT` に変換されるブロック
- **Parameters**:
  - `id (String)`: `UID` 生成に使う識別子
  - `title (String)`: `SUMMARY` に出力するタイトル。空または空白のみの場合は `無題` に正規化される
  - `duration (Duration)`: イベントの長さ。`Duration.zero` は 0 分イベントとして扱う
- **Returns**: なし
- **Errors**: 負の `duration` を含む request は `generateCalendarIcs` で `ArgumentError` になる
- **Examples**:
  - `CalendarExportBlock(id: 'move', title: '移動', duration: Duration(minutes: 30))`

### `CalendarExportBlock.fromBlock(Block block)`

- **Summary**: 既存タイムラインの `Block` から export 用 block を作る helper constructor
- **Parameters**:
  - `block (Block)`: `lib/models.dart` のタイムラインブロック
- **Returns**: `duration` を `Duration(minutes: block.effectiveDuration)` に変換した `CalendarExportBlock`
- **Errors**: なし
- **Examples**:
  - `state.blocks.map(CalendarExportBlock.fromBlock).toList()`
- **Notes**:
  - `action.bufferMinutes` は calendar event の長さに含める。実作業 20 分 + 余裕 10 分の block は 30 分イベントになる

### `class CalendarExportAnchor`

- **Summary**: タイムライン終端のアンカーをカレンダー上の 0 分 `VEVENT` として表すモデル
- **Parameters**:
  - `id (String)`: `UID` 生成に使う識別子
  - `title (String)`: `SUMMARY` に出力するタイトル。空または空白のみの場合は `目標時刻` に正規化される
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - `CalendarExportAnchor(id: 'target-time', title: '会議開始')`

### `String generateCalendarIcs(CalendarExportRequest request)`

- **Summary**: request から iCalendar (`.ics`) 文字列を生成する
- **Parameters**:
  - `request (CalendarExportRequest)`: 開始日時、イベント列、アンカーを含む入力
- **Returns**: CRLF 区切りの `.ics` 文字列
- **Errors**:
  - `blocks` に負の `duration` がある場合は `ArgumentError`
- **Examples**:

```dart
final ics = generateCalendarIcs(
  CalendarExportRequest(
    startDateTime: DateTime.utc(2026, 4, 23, 8),
    blocks: state.blocks.map(CalendarExportBlock.fromBlock).toList(),
    anchor: const CalendarExportAnchor(
      id: 'target-time',
      title: '会議開始',
    ),
  ),
);
```

### `CalendarExportRequest buildCalendarExportRequest({required TimelineState state, required DateTime baseDate, required DateTime Function() clock})`

- **Summary**: `TimelineState` とユーザーが選んだ基準日から `CalendarExportRequest` を組み立てる純粋関数
- **Parameters**:
  - `state (TimelineState)`: 現在のタイムライン状態
  - `baseDate (DateTime)`: ユーザーが選択した日付（時刻成分は無視される）
  - `clock (DateTime Function())`: `generatedAt` に注入する現在時刻。テストでは固定値を渡す
- **Returns**: `CalendarExportRequest`
- **Errors**: なし
- **Notes**:
  - `baseDate` の日付から `targetTime` と全ブロックの有効所要時間合計を逆算し、開始日時を決定する
  - 開始時刻が負になる場合（日付をまたぐ場合）、前日にロールバックする
  - `DateTime.now()` には依存せず、`clock` コールバックを使う

### `class CalendarExportPreview`

- **Summary**: 登録前にユーザーへ表示するプレビュー情報
- **Parameters**:
  - `startDateTime (DateTime)`: 先頭イベントの開始日時
  - `anchorDateTime (DateTime)`: アンカーの開始日時（= 終了日時）
  - `eventCount (int)`: 登録されるイベント総数（blocks + anchor）
  - `spansMultipleDays (bool)`: 開始日とアンカー日が異なる場合 `true`
- **Factory**: `CalendarExportPreview.fromRequest(CalendarExportRequest request)`
- **Notes**:
  - `projectCalendarExportEvents` を使って日時と件数を導出する
  - 日跨ぎ判定は `day/month/year` の比較で行う

### `class CalendarExportDelivery`

- **Summary**: Android / iOS native カレンダーへイベントを書き込む delivery 層
- **Parameters**:
  - `nativeOpener (CalendarExportNativeOpener?)`: テスト用の native 呼び出しモック
  - `isNativePlatform (bool Function()?)`: テスト用のプラットフォーム判定モック
- **Methods**:
  - `Future<CalendarExportResult> deliver({required CalendarExportRequest request, String? calendarId})`
    - `calendarId`: Android / iOS で明示的に書き込み先カレンダーを指定する場合（未指定時は既定カレンダー）
- **Errors**: 失敗時は `CalendarExportException` を投げる
  - `CalendarExportError.permissionDenied`: OS 権限拒否
  - `CalendarExportError.noWritableCalendar`: 書き込み可能カレンダーが存在しない
  - `CalendarExportError.invalidPayload`: イベントペイロード不正
  - `CalendarExportError.saveFailed`: native 保存失敗
  - `CalendarExportError.unsupportedPlatform`: Android / iOS 以外

### `class CalendarExportResult`

- **Summary**: native 登録成功時の戻り値
- **Parameters**:
  - `savedCount (int)`: 実際に登録されたイベント件数
  - `calendarName (String?)`: 登録先カレンダー名（取得できない、または保証できない場合は `null`）

## Native Integration

### Android

- `MainActivity.kt` の `MethodChannel("medo/calendar_export")` で `saveCalendarExport` を処理する
- `CalendarContract.Events` へ `ContentProviderOperation` の batch insert を行う
- 書き込み先カレンダーは `calendarId` 引数、または `resolveWritableCalendarId()` で決定する
- 権限がない場合は `ActivityCompat.requestPermissions` で READ/WRITE_CALENDAR を要求する
- 成功時は `{savedCount, calendarName}` を返す
- 失敗時は以下の code を返す:
  - `permission_denied`
  - `no_writable_calendar`
  - `invalid_payload`
  - `save_failed`

### iOS

- `AppDelegate.swift` の `FlutterMethodChannel` で `saveCalendarExport` を処理する
- iOS 17+ では `EKEventStore.requestWriteOnlyAccessToEvents` を優先し、それ以前では `requestAccess(to: .event)` にフォールバックする
- 書き込み先カレンダーは `calendarId` 引数、または `defaultCalendarForNewEvents` / 最初の writable calendar で決定する
- 成功時は `{savedCount, calendarName}` を返す
  - iOS 17+ の write-only access では `calendarName` は `null` を返す（実際の書き込み先を保証できないため）
  - iOS 17 未満の full access では、書き込み先カレンダーのタイトルを返す
- 失敗時は以下の code を返す:
  - `permission_denied`
  - `no_writable_calendar`
  - `invalid_payload`
  - `save_failed`
- `Info.plist` には `NSCalendarsUsageDescription` と `NSCalendarsWriteOnlyAccessUsageDescription` の両方が必要

## Notes

- `blocks` は過去から未来へ、つまり開始 `DateTime` から順に実行する順序で渡す
- 各 block は前の block の終了時刻を次の開始時刻として連鎖する
- `action.bufferMinutes` はイベントを別件に分けず、該当 `action` の duration に含める
- `duration == Duration.zero` の block と anchor は `DTSTART` と `DTEND` が同一の 0 分 `VEVENT` になる
- `DateTime` はすべて `toUtc()` で UTC に変換し、`YYYYMMDDTHHMMSSZ` 形式で出力する
- `SUMMARY` と `X-WR-CALNAME` では改行、カンマ、セミコロン、バックスラッシュを iCalendar text として escape する
- `DTSTAMP` は `generatedAt` があればそれを使い、未指定時は `startDateTime` を使うため、`DateTime.now()` には依存しない
- `.ics` 生成、request 組み立て、プレビュー導出は Flutter 純粋ロジック層の責務
- 端末カレンダーへの直接登録、権限処理、OS 固有のカレンダー選択は native 層の責務
- UI 層は `buildCalendarExportRequest` で request を組み立て、`CalendarExportPreview` でプレビューを表示し、確認後に `CalendarExportDelivery.deliver` を呼び出す
