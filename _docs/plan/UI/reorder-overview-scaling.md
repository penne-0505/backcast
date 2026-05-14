---
title: "Reorder Overview Scaling"
status: proposed
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-14"
references:
  - _docs/plan/UI/two-step-timeline-density.md
  - _docs/intent/medo/timeline_compact_overview.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
related_issues: []
related_prs: []
---

## Overview

移動ハンドルを長押しして block を並び替える間だけ、編集ビューのタイムラインを一時的に縮小し、より広い範囲を見ながら移動できるようにする。

基本方針は、既存の詳細編集ビュー上で `SliverReorderableList` の並び替え操作を開始したときだけ発火する transient interaction として扱うことにある。ただし、移動中に使用する俯瞰表現は既存の二段階 density の俯瞰を流用してもよいし、操作性の都合があれば reorder 専用の縮小状態を別途用意してもよい。

2026-05-14 時点の追加課題として、縮小が表示上だけに留まり、`SliverReorderableList` の drag gap / proxy / 挿入判定が詳細編集 density の item extent を保持している可能性がある。2 時間程度の長い block を移動すると、見た目は小さいのに判定上は大きな block として残り、縮小表示の目的である「遠い移動先を扱いやすくする」効果が弱くなる。

## Problem

現状の移動ハンドルは `SliverReorderableList.startItemDragReorder` を短い delay で開始するため、操作開始は速い。一方で、詳細編集 density のまま block を掴むため、長時間の予定や block 数が多い予定では移動先の前後関係を見渡しにくい。

現在の実装では `TimelineScreen` が reorder overview active 中だけ `BlockItem` に渡す `pixelsPerMinute` を `kOverviewPixelsPerMinute` へ差し替える。これは周囲の block の再描画には効くが、`_QuickReorderListener` は pointer down 直後に `SliverReorderableList.startItemDragReorder` を呼ぶため、reorder system が縮小後レイアウトを掴む前にドラッグを開始している可能性がある。この場合、見た目の縮小と判定領域が分離する。

常設の俯瞰表示は全体把握には有効だが、俯瞰表示そのものに恒常的な直接編集や reorder を増やすと、読む状態と触る状態の境界が曖昧になる。今回の課題は「俯瞰表示を編集モード化すること」ではなく、「移動中だけ必要な視野を広げること」にある。

## Scope

- 詳細編集ビューで移動ハンドルを長押ししたとき、一時的に timeline list 領域を俯瞰しやすい表示へ移行する。
- 移動中の俯瞰表現は、既存の二段階 density の俯瞰を流用する案と、reorder 専用 scale を持つ案の両方を実装候補に含める。
- 縮小はアニメーションで行い、reorder 開始と並走させる。
- 縮小中も既存の `SliverReorderableList` / `moveBlockByIndex` の reorder model を維持する。
- 縮小中の drag gap / dragged proxy / 挿入判定は、表示上の縮小後 height と一致させる。
- pointer up / cancel / reorder end で縮小状態を解除する。
- 必要に応じて dragged proxy の見た目を調整し、掴んでいる block が視認できるようにする。
- 実装後、guide / reference に「移動中の一時俯瞰」として追記する。

## Non-Goals

- 俯瞰表示での直接編集、duration drag、inline edit、常時 reorder の追加は扱わない。ただし、移動ハンドルから開始した reorder 中に限り、俯瞰相当の表示で reorder を継続することは scope に含める。
- fixed-height row の compact list へ戻すことはしない。
- `TimelineState` に永続化される新しい UI state は追加しない。
- block のデータモデル、persistence、template apply の挙動は変更しない。
- reorder 中の自動スクロール仕様を大きく作り替えない。必要な微調整に留める。
- block の duration 自体を一時的に変更しない。縮小はレイアウトと判定に限り、timeline 計算結果は不変に保つ。

## Requirements

- **Functional**: ユーザーが移動ハンドルを長押しすると、詳細編集ビューのタイムラインが滑らかに縮小する。
- **Functional**: 縮小中も block を上下へ移動でき、並び替え結果は既存と同じ `moveBlockByIndex` に反映される。
- **Functional**: 長時間 block を移動しても、判定上の占有高さが詳細編集 density のまま残らず、縮小後の表示高さに対応する。
- **Functional**: drag gap と dragged proxy の高さは、縮小後の `timelineBlockVisualHeight` と矛盾しない。
- **Functional**: 指を離す、cancel される、または reorder が終了すると、タイムラインは詳細編集 density へ戻る。
- **Functional**: 移動ハンドル以外の tap、duration drag、swipe delete、inline edit では縮小しない。
- **Non-Functional**: 縮小状態は local transient UI state とし、保存・template・plan repository へ影響させない。
- **Non-Functional**: 縮小アニメーションは reorder 開始を待たせず、操作の軽さを維持する。
- **Non-Functional**: 既存の二段階 density / 俯瞰表示を流用する場合も、通常の俯瞰表示が恒常的な編集モードへ見えないようにする。
- **Non-Functional**: 画面縮小により text や handle が過度に潰れる場合は、初回実装後の実機確認で scale 値を調整する。

## Interaction Model

移動ハンドルの pointer down ではまだ俯瞰へ入らない。移動ハンドル上で短い hold が成立した時点で俯瞰への遷移アニメーションを開始する。

候補 A は、既存の二段階 density の俯瞰値を移動中だけ適用する方法である。既存の見え方を再利用できるため、通常の俯瞰と移動中の俯瞰の認知差が小さい。反面、通常俯瞰では reorder handle や直接編集を出さない設計なので、「移動ハンドルから開始した間だけ例外的に reorder が継続する」境界を実装上明確にする必要がある。

候補 B は、reorder 専用の `AnimatedScale` を timeline content に適用する方法である。通常俯瞰の設計と分離しやすく、rollback もしやすい。反面、通常俯瞰と見え方が少しずれる可能性がある。

初期判断は候補 A を優先する。理由は、ユーザーがすでに「俯瞰」という概念を持っているため、移動中に同じ視野へ寄せる方が操作の意味が伝わりやすいからである。候補 A で gesture conflict や state 境界が複雑になりすぎる場合は、候補 B へ切り替える。

実装では候補 A を採用する。`TimelineState.viewMode` は切り替えず、`TimelineScreen` の local state で reorder overview active を保持し、`BlockItem` に渡す effective density だけを `kOverviewPixelsPerMinute` 相当にする。これにより通常俯瞰の read-only 分岐や永続化対象の `pixelsPerMinute` へ影響させず、移動中だけ既存俯瞰の見え方を流用できる。

ただし、判定同期の修正では「effective density を渡す」だけでは不十分な可能性がある。`SliverReorderableList` が drag 開始時に item extent を保持するなら、drag が成立する前に overview state を反映し、少なくとも 1 frame 後に reorder gesture を成立させる必要がある。Flutter の gesture arena は pointer down 後の async 完了時に `startItemDragReorder` を新規登録する使い方に向かないため、`startItemDragReorder` の登録自体は pointer down 中に行い、`DelayedMultiDragGestureRecognizer` の delay を overview 反映より長く取る。

この案で解決しない場合は、reorder 中だけ `SliverReorderableList` の child key を overview state に応じて切り替え、縮小後 layout として list item を再生成してから drag を開始する。それでも内部 placeholder が古い extent を保持する場合は、`SliverReorderableList` に依存したままの修正を諦め、reorder 専用の compact interaction、または選択 + 上下移動方式へ切り替える。

候補 B を採用する場合の想定値:

- scale: `1.0` → `0.72` から `0.80` の範囲で調整
- duration: `140ms` から `180ms`
- curve: `Curves.easeOutCubic`
- alignment: reverse timeline の読ませ方を保つため `Alignment.bottomCenter` を第一候補にする

体感確認の結果、pointer down で縮小すると、移動ハンドルに軽く触れただけでも俯瞰が発火してしまい、操作が過敏に見える。そのため、縮小開始は pointer down ではなく、短い hold timer の成立後に寄せる。

## Implementation Notes

- `TimelineScreen` に `_isReorderOverviewActive` と必要最小限の active block id を local state として追加する。
- 候補 A では、`_isReorderOverviewActive` 中だけ timeline renderer の density を overview 相当にする。`TimelineState.viewMode` 自体を切り替えるか、view mode は edit のまま effective density だけ overview にするかは、sheet / toolbar / handle 表示の副作用を見て選ぶ。
- 候補 A では `TimelineState.viewMode` を直接 compact にしない。通常俯瞰の read-only 分岐や toolbar 表示にも影響するため、`effectivePixelsPerMinute` の局所計算で移動中だけ density を変える。
- `_QuickReorderListener` では pointer down 直後に縮小せず、短い hold timer が成立した場合に `onReorderIntentStart` を呼ぶ。pointer up では timer cancel と cleanup を行う。Flutter の reorder recognizer が内部的に pointer cancel を出す場合があるため、開始前の pointer cancel では pending timer を即時破棄しない。
- 判定同期の第一候補は、pointer down 中に `startItemDragReorder` を登録しつつ、reorder overview の hold timer を 200ms、drag recognizer delay をそれより長い値にすること。現行実装では `BlockItem` の高さアニメーション 160ms も待てるよう、drag recognizer delay を 380ms にする。`setState` 直後や縮小途中に drag が成立しないようにする。
- `_QuickReorderListener` は overview callback を `Future<void>` として扱うが、Flutter の gesture arena 制約上、callback 完了後に `startItemDragReorder` を新規登録しない。親側は `endOfFrame` まで overview state の成立を待機し、recognizer delay 側がその frame を待つ。
- `timelineBlockVisualHeight(block, kOverviewPixelsPerMinute)` を期待 height の基準にし、2 時間 action block、buffer あり action、actionPoint の各ケースで gap / proxy / hit behavior を確認する。
- `SliverReorderableList` が利用可能な `onReorderStart` / `onReorderEnd` を持つ場合は、終了判定をそちらへ寄せる。利用できない場合は pointer up / cancel と `_onReorder` 後の cleanup で補う。
- 候補 B の場合は、`CustomScrollView` 全体、または `SliverReorderableList` を含む timeline content に `AnimatedScale` / `TweenAnimationBuilder` を適用する。
- `proxyDecorator` は初回は現状維持とし、縮小中に dragged item が小さすぎる場合のみ補正する。
- reorder overview active 中は sheet、template sheet、timeline list island、search popover と競合しないよう、既存の close / dismiss 導線を再利用する。

## Tasks

1. 現状の `SliverReorderableList` で、reorder 開始時の item extent が縮小前 / 縮小後のどちらを参照しているかを widget test または手動再現で確認する。
2. `_QuickReorderListener` の drag start を、pointer down 中の reorder 登録、hold 成立、overview state 反映、layout frame 完了後の delayed recognizer 成立、の順に分離する。
3. 2 時間 action block を使い、drag gap / dragged proxy / 挿入判定が縮小後 height に追従するか確認する。
4. 追従しない場合は、reorder overview active 中の list item key / child 再生成、または `proxyDecorator` / placeholder 周辺の補正で解決できるかを調べる。
5. `SliverReorderableList` の内部挙動で解決できない場合は、reorder 専用 compact interaction または選択 + 上下移動方式を fallback として設計する。
6. reorder end / pointer cancel / view mode change / sheet open 時に縮小状態と pending drag start が残らない cleanup を追加する。
7. widget test で、移動ハンドル操作時に overview state が入り、終了後に戻ることを確認する。
8. widget test または integration/manual test で、長時間 block の移動判定が縮小後 height と一致することを確認する。
9. 既存の duration drag、右スワイプ削除、inline edit、表示切り替えの回帰を確認する。
10. `_docs/guide/medo/timeline_editor.md` と `_docs/reference/medo/timeline_domain_reference.md` を実装結果に合わせて更新する。

## Test Plan

- Widget test:
  - 移動ハンドルの pointer down 直後には縮小 state が有効にならない。
  - 短い hold 成立後に縮小 state が有効になる。
  - pointer up / cancel で縮小 state が解除される。
  - reorder 後の `TimelineState.blocks` の順序が既存期待値どおり変わる。
  - 120 分 action block をドラッグしても、drop target の境界遷移が縮小後 height に対応する。
  - dragged proxy / gap が詳細編集 density の 120 分 height を保持しない。
  - duration drag の長押し precise mode では reorder overview が発火しない。
- Regression:
  - `flutter test test/widget_test.dart`
  - `flutter test test/template_sheet_test.dart`
  - 必要に応じて `dart analyze`
- Manual:
  - block 数が多い timeline で、移動中に前後の block が見渡せる。
  - 小さい端末幅でも、縮小中の handle / title / duration pill が極端に潰れない。
  - 長押し開始時の縮小が reorder 開始を待たせているように見えない。

## Deployment / Rollout

初回は edit view 内の transient interaction として出す。問題が出た場合は `_QuickReorderListener` の callback と timeline content の scale wrapper を外すだけで、既存 reorder model に戻せる構成にする。

縮小率は実機確認で調整する。視認性が足りなければ scale を大きくし、見渡しが足りなければ最大でも `0.72` 程度までに留める。これ以上縮める必要がある場合は、単純 scale ではなく reorder 専用の表示密度設計を別途検討する。
