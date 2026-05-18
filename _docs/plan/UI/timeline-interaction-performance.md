---
title: Timeline Interaction Performance Stabilization
status: proposed
draft_status: n/a
created_at: "2026-05-19"
updated_at: "2026-05-19"
references:
  - TODO.md
  - _docs/survey/UI/timeline-interaction-performance-profile.md
  - _docs/plan/UI/reorder-overview-scaling.md
  - _docs/intent/medo/reorder_placement_preview.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
  - https://docs.flutter.dev/perf/ui-performance
  - https://docs.flutter.dev/tools/devtools/performance
  - https://docs.flutter.dev/perf/best-practices
related_issues: []
related_prs: []
---

## Overview

Timeline editor の操作遅延を、短期的な内部互換維持より長期安定性を優先して改善する。対象はまず reorder gesture で、dragged preview / insertion line の transient state を timeline 本体の rebuild 境界から分離する。

今回の方針では、ユーザーから見える操作 semantics、永続化データ、template / plan repository の互換性は維持する。一方で、`TimelineScreen` 内の private state や callback 形状は、性能境界を明確にするために整理してよい。後方互換性は「保存済みデータとユーザー操作の意味」に対して守り、rebuild を誘発する内部構造の温存は優先しない。

## Scope

- Reorder preview state を `TimelineScreen.setState` から分離する。
- Pointer move 中に rebuild される範囲を、drag preview / insertion overlay / 必要最小限の affordance に限定する。
- Reorder session の開始、更新、commit、cancel を表す小さな controller / state object を追加する。
- Visible item geometry を session 開始時に snapshot し、move ごとの `RenderBox.localToGlobal` 走査と sort を避ける。
- Pointer move を frame 単位に coalesce し、同一 candidate への no-op update を捨てる。
- Drop 時だけ `TimelineNotifier.moveBlockByIndex` を呼ぶ commit-only model を維持する。
- Pixel 7a profile mode の再計測手順を受け入れ条件に含める。
- Reorder 改善後に scroll / raster spike を再評価し、必要なら `BlockItem` visual cost の第二フェーズへ進む。

## Non-Goals

- 保存済み plan / template / snapshot の schema migration は行わない。
- Reorder 中に timeline を再び縮小する設計へ戻さない。
- Reorder 操作中に domain state を逐次書き換えて live reorder する方式にはしない。
- Scroll / raster 最適化を、reorder の rebuild 境界分離より先に広げない。
- 見た目の大幅な redesign はしない。visual 変更は、計測上必要な場合に局所化する。
- Flutter framework や rendering backend の切り替えを主施策にしない。

## Requirements

- **Functional**: 既存の移動ハンドル、hold 開始、drag preview、insertion line、drop commit、cancel の体験を維持する。
- **Functional**: Drop 後の順序は現行の `TimelineNotifier.moveBlockByIndex` と同じ意味で決まる。
- **Functional**: Sheet、template sheet、timeline list、search / export popover が開く場合は reorder session を安全に閉じる。
- **Functional**: Source block を通常リストから外して preview を主表示にする既存仕様を維持する。
- **Non-Functional**: Reorder pointer move は `TimelineScreen` / `SliverList` / visible `BlockItem` 全体 rebuild を発生させない。
- **Non-Functional**: Pointer move の処理は最大 1 frame 1 update に制限し、同じ candidate index / line への更新は通知しない。
- **Non-Functional**: Geometry cache は scroll delta、structural change、view mode change、font / density change、session cancel で破棄または補正される。
- **Non-Functional**: 通常 profile trace の受け入れ判定は、widget build profiling を無効にした状態で行う。widget build profiling は原因調査用に限定する。
- **Non-Functional**: Pixel 7a profile mode で reorder の `uiBeginFrame` p90 を 8ms 未満、16ms 超え frame を 30 秒 trace で 1 件以下にすることを目標値にする。目標未達の場合は、残った top event を plan に追記して次施策を選ぶ。

## Design Approach

### Interaction state boundary

`TimelineScreen` は reorder session の lifecycle owner に留める。Pointer の最新位置、preview の transform、candidate insert index、insertion line position は `ReorderInteractionController` 相当の local controller に保持し、overlay widget は `ValueListenableBuilder` または `AnimatedBuilder` でその controller だけを購読する。

これにより、reorder 中の高頻度更新が `Scaffold`、`CustomScrollView`、`SliverList`、`BlockItem` の build へ伝搬しない。`TimelineScreen` の `setState` は session 開始・終了など低頻度の構造変化へ限定する。

### Geometry cache

Session 開始時に visible block の `sourceIndex`, block id, global top / bottom, center を snapshot し、screen order で sort 済みの配列として保持する。Pointer move 中はこの cache から candidate insert index を推定する。

Scroll が発生する場合は、session 開始時の scroll offset と現在 offset の差分で global Y を補正する。補正だけで信頼できない structural change が起きた場合は session を cancel する。初期実装では「drag 中の block 増減・density change・font scale change・view mode change は cancel」が安定側の判断である。

### Frame pacing

Pointer move callback は最新の global position を controller に渡すだけにし、実際の candidate 再計算と overlay notify は scheduled frame にまとめる。1 frame 内に複数 move が来た場合は最後の位置だけを使う。

Preview position は毎 frame 更新してよいが、candidate insert index / insertion line は値が変わった場合だけ通知する。これにより、指に追従する軽量な feedback と、挿入候補の比較的重い計算を分ける。

### Domain state and persistence boundary

Gesture 中は `TimelineState` を更新しない。`TimelineNotifier.moveBlockByIndex`、autosave、analytics は drop commit 時だけ実行する。将来、移動中の仮想開始時刻や buffer 影響を見せたい場合も、domain state へ逐次反映せず、session 内の hypothetical order から overlay 用 view model を作る。

この境界は、template、snapshot、undo、比較表示、Live Action / widget 連携が増えた場合にも重要になる。編集中の transient feedback と永続化対象の plan state が混ざると、保存、復元、分析イベント、将来の同期処理が不安定になるためである。

## Future Feature Considerations

- Timeline alternative comparison が入ると、同種の timeline renderer を 2 列分描画する可能性がある。Reorder overlay と main list の rebuild 境界を分けておかないと、比較表示で rebuild cost が単純に増幅する。
- Home screen widget、Apple Watch、Android Live Action などは、現在の plan / 次の行動 / 残り時間を定期更新する。将来の時刻更新でも editor 全体を再 build しないよう、clock / current marker の更新境界は reorder と同じ考え方で局所化する余地を残す。
- Block 数が増える template、検索、遠距離 reorder 補助が追加されるほど、move ごとの geometry 全走査は効いてくる。Geometry cache は今回の reorder だけでなく、将来の drag-and-drop 系 interaction の基盤になる。
- Accessibility のために reorder 操作をボタン式・メニュー式でも提供する場合、commit-only model はそのまま再利用できる。Pointer overlay に依存するのは feedback 層だけにする。

## Trade-offs

### Local controller vs Riverpod state

Local controller は高頻度更新を UI subtree 内に閉じられるため性能上有利。一方で Riverpod DevTools 的な追跡性や既存 provider pattern との統一感は落ちる。今回の state は保存対象でも domain state でもないため、Riverpod へ載せるより local controller の方が責務に合う。

### Geometry cache vs always remeasure

Cache は move ごとの負荷を下げるが、scroll、density、font scale、block 構造変化で stale になる。長期安定性のため、初期実装では複雑な live recalc より「scroll delta 補正 + 構造変化時 cancel」を選ぶ。必要になったら cache refresh を frame 単位で追加する。

### Frame coalescing vs immediate pointer response

1 frame coalescing は最大 1 frame 分の遅れを許容する代わりに、過剰な build / geometry 計算を防ぐ。90Hz でも 1 frame は約 11ms であり、重い frame が連続するより体感は安定しやすい。

### Insertion line overlay vs live list reflow

Live list reflow は空間的には分かりやすいが、layout cost と状態同期が大きい。現行の preview / insertion line は「何を持っているか」「どこへ入るか」を示す目的に十分で、layout を動かさない分だけ安定する。

### Visual simplification timing

`BlockItem` の shadow、`ShaderMask`、`IntrinsicHeight` などを先に削ると scroll の外れ値は改善する可能性があるが、reorder の主因である build 伝搬は残る。まず rebuild 境界を切り、再計測後に visual cost を削る方が原因と効果を混ぜにくい。

## Tasks

1. Current implementation audit:
   - `_prepareReorderPreview`, `_updateReorderPreview`, `_estimateReorderInsertion`, `_endReorderPreview` の state ownership を棚卸しする。
   - `TimelineScreen.build` で reorder 中に rebuild されている subtree と、overlay だけに必要な値を分離する。
2. Controller extraction:
   - Reorder session state を表す immutable value と local controller を追加する。
   - Session start / move / commit / cancel の API を、pointer gesture から呼べる形にする。
3. Overlay isolation:
   - `_ReorderInsertionOverlay` と `_ReorderDragPreviewOverlay` を controller 購読へ移し、pointer move で main timeline list が rebuild されないようにする。
   - Source block の `Offstage` 切り替えなど、構造変化が必要な処理は session start / end のみに閉じる。
4. Geometry cache:
   - Session start 後の end-of-frame で visible geometry を snapshot する。
   - Screen order / source index mapping を cache 化し、move 中は cache から candidate を計算する。
   - Scroll delta 補正と structural change cancel を入れる。
5. Frame pacing:
   - Pointer move を coalesce し、1 frame に 1 回だけ preview / candidate を notify する。
   - Candidate index / insertion line が変わらない場合は no-op にする。
6. Regression and profiling:
   - Reorder commit correctness、cancel、original slot no-op、duration drag / swipe delete / inline edit の widget test を維持または追加する。
   - Pixel 7a で normal profile trace と widget build profile を取り直し、before / after を survey または plan result に追記する。
7. Secondary scroll pass:
   - Reorder 改善後も scroll の 16ms 超えが残る場合だけ、`BlockItem` visual cost と repaint boundary / const 化 / editor widget lifecycle を別 task として切る。

## Test Plan

- Unit:
  - Geometry cache からの candidate 推定が、`CustomScrollView(reverse: true)` の source order / screen order mapping を保つ。
  - Source block 除外、先頭/末尾挿入、元 slot no-op、scroll delta 補正を検証する。
- Widget:
  - Hold 成立後に preview と insertion line が表示される。
  - Pointer move で preview が追従し、candidate が変わる時だけ insertion line が変わる。
  - Pointer cancel では order が変わらず、drop commit では `moveBlockByIndex` と同じ順序になる。
  - Sheet / template sheet / timeline list / search popover の open で session が残留しない。
  - Duration drag、swipe delete、inline edit が reorder session を誤発火しない。
- Performance:
  - `fvm flutter run --profile -d 38231JEHN03177` で Pixel 7a 実機に profile build を起動する。
  - Reorder の hold + small move を 30 秒程度再現し、VM Service timeline を取得する。
  - 通常 profile trace で `uiBeginFrame`, `BUILD`, `LAYOUT`, `PAINT`, `rasterDraw` を集計する。
  - 必要な診断時のみ widget build profiling を有効化し、`TimelineScreen` / `SliverList` / `BlockItem` が move ごとに増えていないことを確認する。
- Regression:
  - `fvm flutter test test/widget_test.dart --plain-name "reorder"`
  - `fvm flutter test test/widget_test.dart`
  - `fvm dart analyze` または repo 標準の analyze command

## Deployment / Rollout

まず reorder interaction の内部構造として実装し、ユーザー向けの新機能 flag は追加しない。保存 schema や repository に触れないため migration は不要。

Rollback は controller wiring と overlay isolation の差し戻しで行う。Drop commit の API は `TimelineNotifier.moveBlockByIndex` に維持するため、問題が出た場合でも domain state と persistence には影響を残さない。

実装後は `_docs/survey/UI/timeline-interaction-performance-profile.md` に before / after を追記し、目標未達の場合は本 plan の secondary scroll pass か geometry cache refresh 方針を更新する。
