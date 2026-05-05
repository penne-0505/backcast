---
title: Timeline Title Search Jump
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
  - _docs/plan/UI/timeline-compact-overview.md
  - lib/models.dart
  - lib/state.dart
  - lib/timeline_screen.dart
  - lib/block_item.dart
related_issues: []
related_prs: []
---

## Overview

`Medo` のタイムライン上で block title を検索し、一致した block の位置へジャンプできるようにする。

本機能は「一覧性」を高める compact overview view とは別に、ユーザーが既に名前を覚えている block へ直接戻るための移動機能として扱う。初回スコープでは検索対象を `Block.title` に限定し、検索結果へのジャンプと一時ハイライトに集中する。

## Problem

長いタイムラインでは、目的の block が現在のスクロール位置から離れていると、手動スクロールだけで探す負担が大きい。

特に既存編集ビューは `duration * pixelsPerMinute` で block 高さが変わるため、長時間 block を含む計画では、タイトルを覚えていても対象 block へ戻るまでに時間がかかる。

## Decision

- 検索対象は初回では `Block.title` のみとする
- 一致条件は query の部分一致とする
- 検索結果の順序はタイムライン順、つまり過去から目標時刻へ向かう順序とする
- 検索 UI は header から開ける軽量な search bar とする
- 検索ジャンプは block の選択とは分離し、詳細編集 sheet を自動表示しない
- ジャンプ後は対象 block を一時ハイライトする
- ジャンプの最終位置は、対象 block の始点が少し上に余白を持った状態で見える位置とする

## Scope

- header に検索 entrypoint を追加する
- 検索 bar を表示し、query 入力、clear、close を提供する
- 入力中に一致件数と現在の結果位置を表示する
- 一致結果を前後に巡回できる
- Enter / submit または結果移動で該当 block へジャンプできる
- ジャンプ後、対象 block を選択とは別の状態で一時ハイライトする
- active inline editor、詳細編集 sheet、plan panel と競合しないようにする
- 既存編集ビューでまず動作させる
- compact overview view が実装済みの場合、同じ matching model を再利用し、view ごとに jump 実装だけを分けられる境界にする

## Non-Goals

- `targetTimeTitle` の検索は初回スコープに含めない
- block title 以外の説明文、メモ、時刻、duration は検索対象にしない
- 複数 plan 横断検索は扱わない
- fuzzy search、ローマ字検索、かな変換、表記ゆれ吸収は扱わない
- 検索履歴、最近検索した語句、保存済み検索は扱わない
- 検索結果一覧の大型 panel は初回スコープに含めない
- 検索ジャンプで詳細編集 sheet を自動表示しない

## Matching Model

- query は前後空白を除去して扱う
- 空 query の場合、一致結果は 0 件とする
- 比較時は大文字小文字の差を無視してよい
- 日本語タイトルは通常の substring match として扱う
- block title が空文字の場合は、検索対象としては空文字のまま扱う
- 一致結果は `computedBlocksProvider` または `state.blocks` のタイムライン順を基準に並べる
- query 変更時、現在の result index が範囲外になった場合は先頭一致へ戻す
- 前後移動は wrap around してよい

## Interaction Model

1. ユーザーが header の search icon を押す
2. header 直下、または header 内に compact search bar が開く
3. 入力中に `1/3` のような result count を表示する
4. no match の場合は控えめな no result 表示にする
5. submit、次へ、前へ操作で該当 block へジャンプする
6. ジャンプ後、対象 block を一時ハイライトする
7. close すると query と一時ハイライトを解除する

検索 bar を開くとき、active inline editor があればまず focus を外す。詳細編集 sheet または plan panel が表示中の場合は、検索ジャンプ前に閉じて、ジャンプ先が操作 UI で隠れないようにする。

## Jump Landing Contract

検索ジャンプの完了状態は、単に対象 block が viewport 内へ入ることではなく、対象 block の始点を読めることとする。

- `action` の場合、`ComputedBlock.startTime` に対応する block 上端、または start marker が viewport 上部側に見えること
- `actionPoint` の場合、0 分の点を含む row / card の上端が viewport 上部側に見えること
- 最終位置では、対象 block の始点より上におおむね `24〜40px` の余白を持たせる
- header や上部 fade overlay と重ならないよう、実装では `kSearchJumpTopMargin` 相当の定数を置いてよい
- content の先頭/末尾に近く、余白を確保できない場合だけ scroll extent で clamp する
- clamp された場合でも、対象 block の始点または point marker は見えていること

既存編集ビューは `CustomScrollView(reverse: true)` と `SliverReorderableList` を使い、表示順も `computed` を反転している。そのため、遠方の未 build item へは次の二段階で移動する。

1. block id から概算 scroll offset を計算し、対象が build される位置まで移動する
2. 次 frame で対象 widget が存在すれば、`Scrollable.ensureVisible` または同等の補正を行い、上記の top margin を満たす位置へ微調整する

## State Model

検索 UI state は永続化対象にしない。

候補:

- `searchQuery`
- `searchMatches`
- `activeSearchMatchIndex`
- `searchHighlightedBlockId`
- `searchHighlightExpiresAt` または highlight timer

`selectedBlockId` は詳細編集 sheet 表示と結びついているため、検索ジャンプの一時ハイライトには使わない。`BlockItem` には `isSearchHighlighted` のような別 prop を渡し、選択状態とは異なる控えめな視覚効果にする。

## Requirements

- **Functional**: ユーザーは block title で現在の timeline 内を検索できる
- **Functional**: query に一致する block 件数と現在位置を確認できる
- **Functional**: 前後の一致結果へ移動できる
- **Functional**: 検索結果へジャンプできる
- **Functional**: ジャンプ後、対象 block の始点が少し上に余白を持って見える
- **Functional**: ジャンプ後、対象 block が一時的に強調される
- **Functional**: no match の場合でも UI が破綻しない
- **Non-Functional**: 検索 UI state は plan persistence に保存しない
- **Non-Functional**: 検索ジャンプは `selectedBlockId` を変更して詳細編集 sheet を開かない
- **Non-Functional**: 既存の inline edit、duration drag、reorder、pinch zoom を壊さない
- **Non-Functional**: reverse scroll と display order 変換を考慮してジャンプ位置を計算する

## Tasks

1. header の search entrypoint と compact search bar を追加する
2. `Block.title` の部分一致 matching model を実装し、件数と active result index を管理する
3. 次/前/submit 操作から active result を更新し、対象 block id を決める
4. 既存編集ビュー向けに block id から概算 scroll offset を計算する jump helper を追加する
5. 次 frame の補正で、対象 block の始点が `24〜40px` 程度の上余白を持って見えるようにする
6. `selectedBlockId` とは別に `searchHighlightedBlockId` 相当の一時ハイライトを実装する
7. 検索開始・ジャンプ前に inline editor、詳細編集 sheet、plan panel との競合を処理する
8. compact overview view が存在する場合、matching model を共有し、固定行高に合わせた jump 実装を追加または後続 TODO 化する
9. 実装後、timeline editor guide と domain reference に検索ジャンプの操作と制約を追記する

## Test Plan

- `Block.title` の部分一致、空 query、no match、大文字小文字差分を unit / widget test で確認する
- 一致結果がタイムライン順に並ぶことを確認する
- 次/前操作が wrap around することを確認する
- 検索ジャンプで `selectedBlockId` が変わらず、詳細編集 sheet が自動表示されないことを確認する
- ジャンプ後に `searchHighlightedBlockId` 相当の一時ハイライトが表示され、一定時間後または close で解除されることを確認する
- 長時間 block を含む state で、対象 block の始点が上余白つきで見えることを widget test または integration-level test で確認する
- `actionPoint` の検索ジャンプで point row / marker が見えることを確認する
- 既存編集ビューの `flutter test test/widget_test.dart` を実行し、編集、reorder、inline edit が壊れていないことを確認する
- 実機または desktop で、長い timeline の遠方 block へ検索ジャンプできることを手動確認する

## Deployment / Rollout

- 初回は現在 plan 内の block title 検索だけを有効化する
- 検索結果一覧 panel、横断検索、曖昧検索は利用実態を見てから追加する
- ジャンプ位置が端末サイズや keyboard 表示で不安定な場合は、top margin 定数と補正方法を調整する
- 問題が出た場合は search entrypoint を隠せば既存編集ビューの主要操作へ影響を残さない

## Review Checklist

- 検索対象が `Block.title` に限定されている
- no match / empty query の表示が破綻していない
- 検索ジャンプで詳細編集 sheet が自動表示されない
- 対象 block の始点が上余白つきで見えている
- `actionPoint` の 0 分要素も検索ジャンプ先として扱える
- reverse scroll / reversed display order によるジャンプ方向の誤りがない
- 一時ハイライトが選択状態と混同されない
- 既存の inline edit、duration drag、reorder、pinch zoom が壊れていない
- docs に「検索は title のみ」「ジャンプ後は始点に余白を持たせる」と明記されている
