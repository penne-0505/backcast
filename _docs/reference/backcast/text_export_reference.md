---
title: Ato Timeline Text Export Reference
status: active
draft_status: n/a
created_at: "2026-05-02"
updated_at: "2026-05-02"
references:
  - README.md
  - _docs/reference/backcast/timeline_domain_reference.md
  - _docs/plan/Core/timeline-text-share.md
related_issues: []
related_prs: []
---

## Overview

本リファレンスは、`Ato` の現在の逆算タイムラインを、人に送れるプレーンテキスト予定表へ変換する API をまとめたものです。
対象実装は `lib/timeline_text_export.dart` です。

この層は UI、共有シート、clipboard 処理を持たない純粋ロジックです。
呼び出し側は `TimelineState` と共有モード、任意で基準日を明示して渡します。

## API

### `enum TimelineTextExportMode`

- **noDate**: 日付情報を含めない。metadata line は `TOTAL <duration>` のみ。
- **withDate**: `baseDate` を基準日（アンカー日）として日付情報を含める。開始日時とアンカー日時が同日なら単日形式、`yyyy-MM-dd EEE  /  TOTAL <duration>` を出す。日付が分かれる場合は `yyyy-MM-dd EEE -> yyyy-MM-dd EEE  /  TOTAL <duration>` の metadata と date section divider を自動で出す。divider の有無は `targetTime - totalDuration` と `baseDate` から自動判定される。

### `class TimelineTextExportRequest`

- **Summary**: テキスト生成に必要な入力全体を表す不変モデル
- **Parameters**:
  - `state (TimelineState)`: 現在のタイムライン状態
  - `mode (TimelineTextExportMode)`: 日付表現モード
  - `baseDate (DateTime?)`: `withDate` で使用する基準日（アンカー日）。`noDate` では不要
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - `TimelineTextExportRequest(state: state, mode: TimelineTextExportMode.noDate)`
  - `TimelineTextExportRequest(state: state, mode: TimelineTextExportMode.withDate, baseDate: DateTime(2026, 5, 2))`

### `String generateTimelineText(TimelineTextExportRequest request)`

- **Summary**: request から固定レイアウトのプレーンテキストを生成する
- **Parameters**:
  - `request (TimelineTextExportRequest)`: タイムライン状態とモード、基準日を含む入力
- **Returns**: 改行区切りのテキスト文字列
- **Errors**: `withDate` で `baseDate` が未指定の場合は `ArgumentError`
- **Examples**:

```dart
final text = generateTimelineText(
  TimelineTextExportRequest(
    state: state,
    mode: TimelineTextExportMode.withDate,
    baseDate: DateTime(2026, 5, 2),
  ),
);
```

## Text Format

### Header

1 行目は常に `Ato // <target title>`。target title が空白の場合は `目標時刻`。

### Metadata Line

- 日付なし: `TOTAL 35m`
- 単日: `2026-05-02 Sat  /  TOTAL 35m`
- 日跨ぎ: `2026-05-02 Sat -> 2026-05-03 Sun  /  TOTAL 1h20m`

### Event Lines

時間列は 12 文字幅として扱い、記号の開始位置を揃える。

- `action`: `HH:mm-HH:mm ┃ title`
- `actionPoint`: `HH:mm       ● title`
- `target anchor`: `HH:mm       ◆ title`

0 分要素は 0 分のまま扱い、1 分へ伸ばさない。block title が空白の場合は `無題`。title 内の改行は半角スペースへ置換する。生成ロジック側では title の折り返しをしない。

### Date Boundary (withDate で日跨ぎ時のみ)

日跨ぎが発生する場合だけ、date section divider `── yyyy-MM-dd EEE` を挿入する。section divider は event line 群の直前に置き、日付が変わるたびに空行を 1 行入れてから次の divider を置く。`noDate`、および `withDate` で開始日とアンカー日が同じ場合は divider を出さない。

### Duration Formatting

- 60 分未満: `35m`
- 60 分以上: `1h20m`
- ちょうど 60 分: `1h`
- 0 分: `0m`

## Notes

- 本 API は `DateTime.now()` に直接依存しない
- 記号、余白、列幅は `test/timeline_text_export_test.dart` で exact string として固定している
- 共有 delivery（share sheet / clipboard）の責務は `lib/text_export_delivery.dart` と `lib/plan_panel.dart` が担当する
- 生成結果は人間が読むためのテキストであり、machine-readable な import/export 形式とは分離する
