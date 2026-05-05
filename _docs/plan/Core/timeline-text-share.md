---
title: Timeline Text Share
status: proposed
draft_status: n/a
created_at: "2026-05-02"
updated_at: "2026-05-02"
references:
  - README.md
  - TODO.md
  - _docs/reference/backcast/timeline_domain_reference.md
  - _docs/intent/backcast/calendar_export_ics.md
  - https://pub.dev/packages/share_plus
  - https://api.flutter.dev/flutter/services/Clipboard/setData.html
related_issues: []
related_prs: []
---

## Overview

`Medo` の現在の逆算タイムラインを、人へそのまま送れるプレーンテキストへ変換し、OS の共有シートまたはコピーで外部共有できるようにする。

本機能は画像エクスポートとは分離する。まずテキスト表現を確定させることで、後続の画像共有でも同じ情報設計を再利用できるようにする。

## Scope

- 現在の `TimelineState` を、記号と等幅レイアウトを意識したプレーンテキストへ変換する純粋ロジックを追加する
- 日付なし / 日にちあり の 2 パターンをサポートする。日にちありでは `targetTime - totalDuration` と `baseDate` から日跨ぎを自動判定し、同日なら単日形式、日付が分かれる場合は日跨ぎ形式を自動で出す
- `action`, `actionPoint`, target anchor を異なる記号で表現する
- native share sheet によるテキスト共有を追加する
- clipboard へのコピーを fallback または副導線として追加する
- 共有前に生成テキストを確認できる軽量プレビューを追加する
- 生成結果は人間が読むためのテキストとし、機械可読な import/export 形式とは分ける

## Non-Goals

- 画像エクスポートは扱わない
- Markdown 専用、HTML、PDF、JSON、CSV、`.txt` ファイル保存は扱わない
- カレンダー登録や `.ics` 共有は扱わない
- 共有先アプリごとの個別最適化は行わない
- Free / Pro gate との接続はこの計画では扱わない
- テキスト共有結果を再 import する機能は扱わない

## Text Format

### Standard Shape

単日かつ日付ありの場合は以下を標準形とする。

```text
Medo // 会議開始
2026-05-02 Sat  /  TOTAL 35m

10:20-10:40 ┃ 移動
10:40       ● コンビニ
10:40-10:55 ┃ 資料確認
10:55       ◆ 会議開始
```

### Symbol Semantics

- `┃`: 所要時間を持つ `action`
- `●`: 0 分の `actionPoint`
- `◆`: target anchor
- `//`: header 内の app name と target title の区切り
- `/`: metadata line 内の date range と total duration の区切り
- `──`: 日跨ぎ時の date section divider

### Header Rules

- 1 行目は常に `Medo // <target title>`
- target title が空白の場合は `目標時刻` を使う
- 2 行目は metadata line とする
- metadata line と event lines の間には空行を 1 行入れる

### Metadata Line Rules

日付なし共有では total duration のみを出す。

```text
TOTAL 35m
```

単日の日付あり共有では対象日と total duration を出す。

```text
2026-05-02 Sat  /  TOTAL 35m
```

日跨ぎ共有では開始日とアンカー日を `->` でつなぐ。

```text
2026-05-02 Sat -> 2026-05-03 Sun  /  TOTAL 1h20m
```

### Event Line Rules

時間列は 12 文字幅として扱い、記号の開始位置を揃える。

```text
HH:mm-HH:mm ┃ action title
HH:mm       ● actionPoint title
HH:mm       ◆ target title
```

- `action` は `HH:mm-HH:mm` を出す
- `actionPoint` は `HH:mm` の一点だけを出す
- target anchor は `HH:mm` の一点だけを出す
- 0 分要素は 0 分のまま扱い、1 分へ伸ばさない
- block title が空白の場合は `無題` を使う
- title 内の改行は半角スペースへ置換する
- 生成ロジック側では title の折り返しをしない

### Date Boundary Rules

日跨ぎが発生する場合だけ、date section divider を挿入する。

```text
Medo // 到着
2026-05-02 Sat -> 2026-05-03 Sun  /  TOTAL 1h20m

── 2026-05-02 Sat
23:10-23:40 ┃ 移動
23:40       ● 乗換
23:40-00:10 ┃ 待機

── 2026-05-03 Sun
00:10-00:30 ┃ 徒歩
00:30       ◆ 到着
```

- section divider は event line 群の直前に置く
- 日付が変わるたびに空行を 1 行入れてから次の divider を置く
- 日付なし共有では divider を出さない

### Duration Formatting

- 60 分未満: `35m`
- 60 分以上: `1h20m`
- ちょうど 60 分: `1h`
- 0 分: `0m`

## Requirements

- **Functional**: 現在のタイムラインを上記 `Text Format` に完全準拠した文字列へ変換できる
- **Functional**: 日付なし / 日にちあり を選べる。日にちありでは日跨ぎを自動判定する
- **Functional**: 共有前にテキストのプレビューを表示できる
- **Functional**: native share sheet で共有できる
- **Functional**: clipboard へコピーできる
- **Functional**: `share_plus` 利用時は iPad 向けに `sharePositionOrigin` を渡す
- **Non-Functional**: テキスト生成は Flutter UI と share plugin に依存しない純粋関数にする
- **Non-Functional**: 生成ロジックは `DateTime.now()` に直接依存しない
- **Non-Functional**: 記号、余白、列幅は snapshot test で固定する
- **Non-Functional**: 共有先アプリで等幅フォントにならない場合でも、意味が読める構成を保つ

## Tasks

1. `lib/timeline_text_export.dart` を追加し、`TimelineState` と任意の対象日から text を生成する純粋ロジックを実装する
2. `Text Format` セクションに合わせて、header、metadata、event lines、date divider、duration formatting を実装する
3. 日付なし、単日、日跨ぎ、空 blocks、0 分 actionPoint、空 title、改行 title の unit test を追加する
4. `share_plus` を dependency に追加し、`text_export_delivery.dart` などの delivery 層で share sheet を呼び出す
5. Flutter 標準 `Clipboard.setData` による copy delivery を追加する
6. export UI に「テキストで共有」を追加し、共有前プレビュー、共有、コピーの操作を配置する
7. iPad / tablet で share sheet が落ちないよう、呼び出し元 widget の `RenderBox` から `sharePositionOrigin` を渡す
8. `_docs/reference/backcast/` に text export の reference を追加し、README の export 説明へ反映する

## Test Plan

- `/home/penne/sdk/flutter/flutter/bin/flutter test test/timeline_text_export_test.dart`
- `/home/penne/sdk/flutter/flutter/bin/flutter test test/widget_test.dart`
- `/home/penne/sdk/flutter/flutter/bin/flutter analyze`
- snapshot 的な exact string test で、記号、空白、改行、日跨ぎ divider が変わらないことを検証する
- Android / iOS で share sheet と clipboard copy を手動確認する
- iPad または大画面 iOS 相当で `sharePositionOrigin` 付きの共有を確認する

## Deployment / Rollout

- 最初はプレーンテキスト共有のみを有効化し、画像共有とは UI 上も実装上も分ける
- 共有先アプリによって等幅表示にならない場合があるため、崩れにくさは exact visual ではなく可読性で判断する
- `share_plus` の platform support や要求 SDK が変わった場合は、実装前に dependency version を再確認する
- 問題が出た場合は share sheet 導線だけを無効化し、text generation と clipboard copy は維持する

## Review Checklist

- `Text Format` の記号と余白が勝手に変更されていない
- `actionPoint` と target anchor が 0 分の一点として出力されている
- 日付なし共有で date divider が出ていない
- 日跨ぎ共有で date divider が正しく入っている
- total duration が `35m`, `1h20m`, `1h`, `0m` の規則に従っている
- 共有 delivery が text generation の純粋ロジックと分離されている
- clipboard fallback がある
- ドキュメントが実装後の仕様を追跡できる
