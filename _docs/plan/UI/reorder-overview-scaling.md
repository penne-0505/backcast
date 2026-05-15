---
title: "Reorder Placement Preview"
status: proposed
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-15"
references:
  - _docs/plan/UI/two-step-timeline-density.md
  - _docs/intent/medo/timeline_compact_overview.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
related_issues: []
related_prs: []
---

## Overview

移動ハンドルを長押しして block を並び替える間、編集ビューのタイムライン自体は縮小せず、押下位置の近くに小さい preview を出し、実際の挿入位置を timeline 上の線で示す。

基本方針は、`SliverReorderableList` の item extent や placeholder 判定に UI の縮小を同期させようとしないことにある。持っている block の確認は overlay preview に分離し、挿入先の確認は list 上の insertion indicator に分離する。これにより、block 本体の視覚バランスと reorder 判定を無理に同じ scale に合わせる必要をなくす。

2026-05-15 時点の方針転換として、従来の「移動中だけ縮小し、その縮小を判定にも反映する」案は撤回する。縮小は一見直感的だが、長時間 block の height、drag gap、proxy、insert 判定をすべて一貫させるには Flutter reorder internals へ依存しすぎる。今回の目的は「持っている block と挿入先を見失わないこと」であり、timeline 全体を縮めること自体ではない。

## Problem

現状の移動ハンドルは `SliverReorderableList.startItemDragReorder` を短い delay で開始するため、操作開始は速い。一方で、長時間の予定や block 数が多い予定では、dragged proxy と placeholder の大きさが目立ち、移動先の前後関係を見渡しにくい。

現在の実装では `TimelineScreen` が reorder overview active 中だけ `BlockItem` に渡す `pixelsPerMinute` を `kOverviewPixelsPerMinute` へ差し替える。これは周囲の block の再描画には効くが、`SliverReorderableList` の drag gap / proxy / hit testing と完全に同期するとは限らない。ここをさらに詰めるより、移動中の feedback を別レイヤーに出す方が、実装上も体感上も安定しやすい。

常設の俯瞰表示は全体把握には有効だが、俯瞰表示そのものに恒常的な直接編集や reorder を増やすと、読む状態と触る状態の境界が曖昧になる。今回の課題は「俯瞰表示を編集モード化すること」ではなく、「移動中だけ持っている block と挿入先を見失わないこと」にある。

## Scope

- 詳細編集ビューで移動ハンドルを長押ししたとき、押下位置近くに小さい dragged block preview を表示する。
- 移動中の挿入先を timeline 上の線で示す。
- 必要に応じて insertion line の横に小さい `ここに移動` pill を表示できる余地を残す。ただし初期実装では線を主表示とする。
- 移動中も既存の `SliverReorderableList` / `moveBlockByIndex` の reorder model を維持する。
- pointer up / cancel / reorder end で preview と insertion indicator を解除する。
- dragged proxy は必要に応じて透明化または軽量化し、重い block 本体が移動中の主表示にならないようにする。
- 実装後、guide / reference に「移動中の preview と挿入線」として追記する。

## Non-Goals

- 俯瞰表示での直接編集、duration drag、inline edit、常時 reorder の追加は扱わない。
- fixed-height row の compact list へ戻すことはしない。
- `TimelineState` に永続化される新しい UI state は追加しない。
- block のデータモデル、persistence、template apply の挙動は変更しない。
- reorder 中の自動スクロール仕様を大きく作り替えない。必要な微調整に留める。
- block の duration 自体を一時的に変更しない。移動中の preview と indicator は見た目だけで、timeline 計算結果は不変に保つ。
- timeline 全体を一時的に縮小しない。

## Requirements

- **Functional**: ユーザーが移動ハンドルを長押しすると、押下位置の近くに小さい dragged block preview が表示される。
- **Functional**: 移動中の挿入候補位置が timeline 上の線として表示される。
- **Functional**: 移動中も block を上下へ移動でき、並び替え結果は既存と同じ `moveBlockByIndex` に反映される。
- **Functional**: 長時間 block を移動しても、dragged proxy の大きさが挿入先の読み取りを過度に妨げない。
- **Functional**: 指を離す、cancel される、または reorder が終了すると、preview と insertion indicator は消える。
- **Functional**: 移動ハンドル以外の tap、duration drag、swipe delete、inline edit では preview と insertion indicator を出さない。
- **Non-Functional**: preview / insertion indicator は local transient UI state とし、保存・template・plan repository へ影響させない。
- **Non-Functional**: timeline 本体の block visual は変形しない。操作中も通常編集状態の時刻・余白・色の読み取りを保つ。
- **Non-Functional**: preview は block 全体の精密な複製ではなく、タイトル、種別、所要時間、色が分かる軽量表現でよい。
- **Non-Functional**: insertion line は説明的な text より優先する。`ここに移動` pill は線だけでは不足する場合の補助として扱う。

## Interaction Model

移動ハンドルの pointer down ではまだ preview を出さない。移動ハンドル上で短い hold が成立した時点で、押下位置の近くに dragged block preview を出し、reorder の挿入候補が変わるたびに timeline 上の insertion line を更新する。

preview は画面上の pointer 近傍に追従する小さな surface とする。内容は block type、title、duration / effective duration、色の小さな swatch または左アクセントで十分とする。これにより、ユーザーは「何を持っているか」を確認できるが、元 block と同じ大きさの proxy を追いかける必要はない。

insertion line は `SliverReorderableList` の並び替え候補 index から描画する。実装上、Flutter が現在の drop index を直接公開しない場合は、drag pointer の global position と各 visible item の `RenderBox` 境界から候補位置を推定する。これは推論を含む設計判断だが、`SliverReorderableList` の内部 placeholder に依存するより、表示 feedback の責務をこちらで握れる。

初期実装では insertion line のみを主 feedback とする。`ここに移動` pill は、線だけでは挿入意図が弱いと実機確認で判断した場合に、線の横へ小さく追加する。常時 text を出すと UI が説明的になりすぎるため、初期 scope には含めない。

`TimelineState.viewMode` は切り替えない。`TimelineScreen` の local state に active dragged block id、latest pointer position、candidate insert index を持ち、保存対象 state には入れない。既存の `_QuickReorderListener` の 200ms hold と delayed recognizer は流用できるが、`effectivePixelsPerMinute` を `kOverviewPixelsPerMinute` に差し替える処理は撤去または無効化する。

drop 後のデータ更新は既存の `_onReorder` と `TimelineNotifier.moveBlockByIndex` に任せる。preview / insertion line は操作 feedback であり、source of truth ではない。

体感確認の焦点は、視野の広さではなく「移動中に元 block の大きさが邪魔にならず、挿入先を確信できるか」に置く。

## Implementation Notes

- `TimelineScreen` に reorder preview 用の local state を追加する。最低限、active block id、latest pointer global position、candidate insert index を保持する。
- `_QuickReorderListener` は pointer move を親へ通知できるようにし、preview の追従位置を更新する。
- `_QuickReorderListener` では pointer down 直後に preview を出さず、短い hold timer が成立した場合に `onReorderIntentStart` を呼ぶ。pointer up では timer cancel と cleanup を行う。Flutter の reorder recognizer が内部的に pointer cancel を出す場合があるため、開始前の pointer cancel では pending timer を即時破棄しない。
- `BlockItem` に insertion indicator 描画のための `reorderInsertIndex` または `isReorderInsertBefore/After` 相当の引数を追加する。ただし item 本体の height は変更しない。
- candidate insert index は、まず `SliverReorderableList.onReorderStart` / `_onReorder` / pointer position から推定する。正確な live index が取りにくい場合は visible item 境界の `RenderBox` 計測へ寄せる。
- dragged proxy は初期実装で透明度を落とすか、`proxyDecorator` で軽量な placeholder に差し替える。小さい preview が主表示になるため、proxy が大きく主張しすぎないことを優先する。
- preview は `Positioned` + `IgnorePointer` で timeline stack の最前面に描画する。Quick Overlay / Work Surface ではなく Layer 1 の passive visual overlay として扱う。
- `SliverReorderableList` が利用可能な `onReorderStart` / `onReorderEnd` を持つ場合は、終了判定をそちらへ寄せる。利用できない場合は pointer up / cancel と `_onReorder` 後の cleanup で補う。
- reorder preview active 中は sheet、template sheet、timeline list island、search popover と競合しないよう、既存の close / dismiss 導線を再利用する。

## Tasks

1. 現状の `_reorderOverviewBlockId` / `effectivePixelsPerMinute` / `_QuickReorderListener` の責務を棚卸しし、縮小依存を preview state へ置き換える。
2. `_QuickReorderListener` から pointer position を親へ通知し、hold 成立後だけ preview を表示する。
3. `TimelineScreen` の Stack 上に dragged block preview を描画する。
4. candidate insert index を算出し、`BlockItem` または list wrapper 上に insertion line を描画する。
5. `proxyDecorator` を調整し、大きい dragged proxy が preview / insertion line を邪魔しないようにする。
6. reorder end / pointer cancel / view mode change / sheet open 時に preview state と pending drag start が残らない cleanup を追加する。
7. widget test で、移動ハンドル操作時に preview が入り、終了後に消えることを確認する。
8. widget test または manual test で、長時間 block の移動中も挿入線が読めることを確認する。
9. 既存の duration drag、右スワイプ削除、inline edit、表示切り替えの回帰を確認する。
10. `_docs/guide/medo/timeline_editor.md` と `_docs/reference/medo/timeline_domain_reference.md` を実装結果に合わせて更新する。

## Test Plan

- Widget test:
  - 移動ハンドルの pointer down 直後には preview が表示されない。
  - 短い hold 成立後に dragged block preview が表示される。
  - pointer move で preview 位置が更新される。
  - pointer up / cancel で preview と insertion line が解除される。
  - reorder 後の `TimelineState.blocks` の順序が既存期待値どおり変わる。
  - 120 分 action block をドラッグしても、挿入線が表示され、dragged proxy が主表示を妨げない。
  - duration drag の長押し precise mode では reorder preview が発火しない。
- Regression:
  - `flutter test test/widget_test.dart`
  - `flutter test test/template_sheet_test.dart`
  - 必要に応じて `dart analyze`
- Manual:
  - block 数が多い timeline で、移動中に挿入先の前後関係が読める。
  - 小さい端末幅でも、preview が指や toolbar と過度に重ならない。
  - 線だけで挿入意図が弱い場合、`ここに移動` pill の追加要否を判断する。

## Deployment / Rollout

初回は edit view 内の transient interaction として出す。問題が出た場合は preview / insertion indicator state と `proxyDecorator` の変更を外すだけで、既存 reorder model に戻せる構成にする。

preview サイズと insertion line の太さは実機確認で調整する。視認性が足りなければ pill 補助を追加し、邪魔であれば preview をさらに軽量化する。
