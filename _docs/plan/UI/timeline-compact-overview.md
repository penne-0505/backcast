---
title: Timeline Compact Overview
status: proposed
draft_status: n/a
created_at: "2026-05-02"
updated_at: "2026-05-02"
references:
  - README.md
  - TODO.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/intent/medo/reverse_timeline_interaction_model.md
related_issues: []
related_prs: []
---

## Overview

`Medo` の既存タイムライン編集画面とは別に、固定高さの行でタイムライン全体を読むための compact overview view を追加する。

本機能の目的は、時間比例表示を維持したまま 14〜16 時間を 1 画面へ押し込むことではない。3 時間の予定が画面の大半を占める現状の問題を避け、長時間の計画でも各 block の順序、時刻、長さ、節目を一覧として把握できるようにする。

## Problem

既存編集画面は `duration * pixelsPerMinute` を基本に block 高さを決めるため、長時間 block があると画面がその block だけで埋まりやすい。

例として 3 時間 block は、現行の最小 `pixelsPerMinute = 3.0` でも 540px になる。これは編集時には意味があるが、全体把握には重すぎる。

## Decision

- 俯瞰用 UI は時間比例の縮小版ではなく、固定高さ row の compact list とする
- 1 block は原則 `52〜64px` 程度の fixed height row として表示する
- 長さは row height ではなく duration badge / time range / 補助表示で伝える
- `action`, `actionPoint`, target anchor は記号・色・ラベルで区別する
- 直接編集は捨て、一覧性と順序調整に寄せる
- 入れ替えは可能にする

## Scope

- 既存編集画面とは別の compact overview view を追加する
- header または toolbar から編集ビューと俯瞰ビューを切り替えられる
- 俯瞰ビューでは `Block` と target anchor を固定高さ row で表示する
- row には開始/終了時刻、title、duration、種別表示を含める
- `actionPoint` は一点の row として表示する
- target anchor は最後の row として表示する
- block の reorder を可能にする
- row tap で選択し、編集ビューへ戻ったときに該当 block を扱える導線を用意する
- 現在時刻がタイムライン範囲内の場合、一覧上でも軽く示す

## Non-Goals

- duration drag、precise drag、inline title edit は俯瞰ビューに含めない
- 詳細編集 sheet を俯瞰ビュー内に常時表示しない
- 時間比例の map view は初回スコープに含めない
- 14〜16 時間ぶんを厳密な時間軸として完全表示することは目標にしない
- 画像共有用のカード UI とは別機能として扱う
- 日付跨ぎの高度な calendar view は扱わない

## Display Model

### Row Shape

各 row は固定高さで、次の情報を左から右へ並べる。

```text
┃ 09:40-12:40  作業        3h
● 12:40        休憩        point
◆ 13:00        会議開始    target
```

- 左端: 種別記号または細い色 stripe
- 時刻列: `HH:mm-HH:mm` または `HH:mm`
- 中央: block title
- 右端: duration badge または `point` / `target`

### Symbol Semantics

- `┃`: 所要時間を持つ `action`
- `●`: 0 分の `actionPoint`
- `◆`: target anchor

この記号は text share の情報設計と揃える。

### Density

- row height は `52〜64px` を目安にする
- title は 1 行表示を基本にし、長い場合は ellipsis でよい
- duration が長くても row height は増やさない
- 5 分以下の短い block でも最低 tap target を確保する

## Interaction Model

- 俯瞰ビューでは block の直接編集をしない
- reorder はできる
- 初回実装では、既存の reorder UI を流用するか、選択中 row に上下移動ボタンを出す
- もし固定高さ row と `ReorderableList` の相性がよければ drag reorder を採用する
- 小さい端末や gesture conflict が出る場合は、選択 + 上下ボタン方式へ寄せる
- row tap は選択とする
- row double tap または edit action で編集ビューへ戻り、該当 block を選択する

## Requirements

- **Functional**: ユーザーは編集ビューと compact overview view を切り替えられる
- **Functional**: 長時間 block があっても row height は固定され、画面を占有しない
- **Functional**: 各 block の start/end、title、duration が読める
- **Functional**: `actionPoint` と target anchor が一点の要素として読める
- **Functional**: block の reorder ができる
- **Functional**: 俯瞰ビューから編集ビューへ戻って該当 block を扱える
- **Functional**: 14〜16 時間程度の計画でも、構成要素の一覧性が編集ビューより明確に高い
- **Non-Functional**: `pixelsPerMinute` は俯瞰ビューの row height に使わない
- **Non-Functional**: 既存の `TimelineState` / `computeBlocks` / `moveBlockByIndex` を再利用する
- **Non-Functional**: 俯瞰ビューの UI state は永続化対象にしない
- **Non-Functional**: 既存編集ビューの gesture / inline edit / precise drag を壊さない

## Tasks

1. `TimelineViewMode` 相当の UI state を追加し、編集ビューと俯瞰ビューを切り替えられるようにする
2. `CompactOverviewView` を追加し、`computedBlocksProvider` の結果を固定高さ row で表示する
3. `CompactOverviewRow` を追加し、`action`, `actionPoint`, target anchor の表示を分ける
4. reorder 方式を実装する。まず `ReorderableListView` / `SliverReorderableList` の固定 row 版を検討し、gesture が重い場合は選択 + 上下ボタンへ切り替える
5. row tap / edit action から編集ビューへ戻り、該当 block または target anchor を選択する導線を実装する
6. 現在時刻が範囲内にある場合、該当位置の近くに軽い marker を表示する
7. `_docs/guide/medo/timeline_editor.md` と `_docs/reference/medo/timeline_domain_reference.md` に俯瞰ビューの使い方と制約を追記する

## Test Plan

- `computeBlocks` 由来の start/end が compact row に正しく出ることを widget test で確認する
- 3 時間 block を含む state で、row height が duration に比例して増えないことを確認する
- `action`, `actionPoint`, target anchor の表示差分を確認する
- reorder 後に `TimelineState.blocks` の順序が期待どおり変わることを確認する
- compact overview から編集ビューへ戻ったときに、該当 block の選択状態が反映されることを確認する
- 既存編集ビューの `flutter test test/widget_test.dart` を実行し、既存操作が壊れていないことを確認する
- 実機または desktop で、14〜16 時間程度のサンプル計画が編集ビューより明らかに一覧しやすいことを手動確認する

## Deployment / Rollout

- 初回は fixed-height compact list として出す
- 時間比例 map view は、この fixed list で不足が見えてから再検討する
- gesture conflict が出た場合は drag reorder より選択 + 上下ボタンを優先する
- row density は実機確認で微調整してよいが、duration に比例して高さを戻してはならない
- 問題が出た場合は view mode 切り替え導線だけを隠し、既存編集ビューへ影響を残さない

## Review Checklist

- 長時間 block が画面を占有しない
- row height が duration に比例していない
- `actionPoint` と target anchor が 0 分の一点として扱われている
- reorder ができる
- 直接編集機能を俯瞰ビューへ持ち込んでいない
- 既存編集ビューの gesture と見た目が壊れていない
- docs に「時間比例 map ではなく compact list」であることが明記されている
