---
title: Medo Timeline Image Export Reference
status: active
draft_status: n/a
created_at: "2026-05-03"
updated_at: "2026-05-10"
references:
  - README.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/plan/Core/timeline-image-share.md
  - _docs/reference/medo/text_export_reference.md
related_issues: []
related_prs: []
---

## Overview

本リファレンスは、`Medo` の現在の逆算タイムラインを、共有専用の画像カードとして生成し PNG として外部共有する API をまとめたものです。
対象実装は以下のファイルです。

- `lib/timeline_image_export.dart` — 純粋ロジック（view model 構築）
- `lib/timeline_image_share_card.dart` — 共有専用 Widget
- `lib/image_export_delivery.dart` — PNG キャプチャと OS 共有シート呼び出し

## API

### `enum TimelineImageExportMode`

- **noDate**: 日付情報を含めない。metadata は `TOTAL <duration>` のみ。
- **withDate**: `baseDate` を基準日（アンカー日）として日付情報を含める。開始日時とアンカー日時が同日なら単日形式、`yyyy-MM-dd EEE  /  TOTAL <duration>` を出す。日付が分かれる場合は `yyyy-MM-dd EEE -> yyyy-MM-dd EEE  /  TOTAL <duration>` の metadata を出す。

### `class TimelineImageExportViewModel`

- **targetTitle**: ヘッダーに表示する目標タイトル。空白の場合は `目標時刻`。
- **metadataText**: 日付範囲と total duration をまとめた文字列。
- **events**: タイムライン上の各要素を表す `TimelineImageExportEvent` のリスト。target anchor が最後の要素として含まれる。

### `class TimelineImageExportEvent`

- **timeText**: 表示用時刻文字列（例: `12:25-12:45` または `12:45`）
- **title**: ブロックまたはアンカーのタイトル。空白の場合は `無題`、改行は半角スペースに置換済み。
- **type**: `action`, `actionPoint`, `targetAnchor` のいずれか
- **colorIndex**: ブロック色のインデックス。`targetAnchor` では `-1`
- **durationMinutes**: `action` の場合のみ所要時間（分）。`actionPoint` と `targetAnchor` では `null`。
- **bufferMinutes**: `action` の余裕時間（分）。未設定時は 0。

### `TimelineImageExportViewModel buildTimelineImageExportViewModel(...)`

- **Summary**: `TimelineState` から画像共有カード用の view model を構築する
- **Parameters**:
  - `state (TimelineState)`: 現在のタイムライン状態
  - `mode (TimelineImageExportMode)`: 日付表現モード（デフォルト `noDate`）
  - `baseDate (DateTime?)`: `withDate` で使用する基準日
- **Returns**: `TimelineImageExportViewModel`
- **Errors**: `withDate` で `baseDate` が未指定の場合は `ArgumentError`
- **Examples**:

```dart
final vm = buildTimelineImageExportViewModel(
  state,
  mode: TimelineImageExportMode.withDate,
  baseDate: DateTime(2026, 5, 2),
);
```

### `class TimelineImageShareCard extends StatelessWidget`

- **Summary**: 共有専用の画像カード Widget。幅 320px で固定レイアウトし、Medo パレットと縦タイムライン構造を保つ。
- **Parameters**:
  - `viewModel (TimelineImageExportViewModel)`: 描画するデータ
- **Usage**: [RepaintBoundary] で囲み、[GlobalKey] を紐付けて `ImageExportDelivery.capturePng` に渡すことを想定している。

### `class ImageExportDelivery`

- **Summary**: PNG キャプチャと OS 共有シートの delivery 層
- **Methods**:
  - `Future<Uint8List> capturePng(GlobalKey key, {double pixelRatio = 3.0})`: [RenderRepaintBoundary] を画像化して PNG bytes を返す。
  - `Future<void> sharePng(Uint8List bytes, {required BuildContext context, String fileName = 'medo_share.png'})`: 一時ファイルに保存して `share_plus` で共有する。iPad では `sharePositionOrigin` を自動取得する。

## Visual Direction

- 出力は「小さな計画カード」として見える
- 上部に `Medo // <target title>` の見出し
- 日付または date range と total duration を見える位置に配置
- `action` は時間幅を持つ行動として角丸カードで表示。左縁にブロック色、所要時間があればピルを表示
- `action.bufferMinutes > 0` の場合は、行動カード内に一段狭い余裕時間セグメントを追加し、`余裕 +<minutes>分` と表示する
- `actionPoint` は縦線上の小さな丸として表示
- `targetAnchor` は `TARGET` ラベル付きの大きな olive 丸で表示
- 操作 UI、スクロールバー、編集カーソルは含めない
- 背景、文字色、ブロック色は既存の Medo palette と大きく乖離させない

## Notes

- 本 API は `DateTime.now()` に直接依存しない
- metadata の total duration と action の time range は `duration + bufferMinutes` を使う。`durationMinutes` は実作業時間、`bufferMinutes` は余裕時間として view model 上で分けて保持する
- `pixelRatio` のデフォルトは 3.0 とし、高 DPI 端末でのぼやけを抑制する
- 画像生成（`capturePng`）と共有 delivery（`sharePng`）は分離されている
- 長いタイムライン（イベント数 50 超）ではプレビュー時に警告を表示する
- Pro / Free gate との接続は UI entrypoint 側で後から可能な境界を残している
