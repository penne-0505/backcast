---
title: Timeline Sidebar Double Tap Insert
status: proposed
draft_status: n/a
created_at: "2026-05-02"
updated_at: "2026-05-02"
references:
  - README.md
  - TODO.md
  - _docs/guide/backcast/timeline_editor.md
  - _docs/reference/backcast/timeline_domain_reference.md
  - _docs/intent/backcast/reverse_timeline_interaction_model.md
  - lib/models.dart
  - lib/state.dart
  - lib/timeline_screen.dart
  - lib/block_item.dart
related_issues: []
related_prs: []
---

## Overview

`Medo` の編集ビューで、画面左の timeline rail をダブルタップすると、最も近い block 境界に新しい `action` block を挿入できるようにする。

本機能は「時刻を直接指定して予定を作る」機能ではない。既存の逆算モデルを保ったまま、block と block の境界へすばやく行動を差し込むための編集補助として扱う。

## Feasibility

実現可能性は高い。

データ構造側には既に `TimelineNotifier.addBlock(index, BlockType.action)` があり、`blocks` 上の任意 index に新しい action を挿入できる。`computeBlocks()` は `blocks` と `targetTime` から開始/終了時刻を再計算するため、新規 block 挿入後も target anchor を固定したまま逆算結果を更新できる。

一方、UI 側の timeline rail は独立した 1 本の Widget ではない。現状は各 `BlockItem` 内の `_Sidebar` が、見た目として左の線・時刻ラベル・point marker を分割描画している。したがって実装では、この `_Sidebar` を入力面として扱えるようにし、ダブルタップされた sidebar と local position から挿入 index を決める必要がある。

## Existing Implementation Notes

- `Block` は `id`, `type`, `title`, `duration`, `colorIndex` を持つ
- `blocks[0]` が最も過去、`blocks.last` が target の直前にある
- `computeBlocks(blocks, targetTime)` は `blocks` と同じ順序で `ComputedBlock` を返す
- 編集ビューの表示は `computed` を reverse しており、visual bottom に target anchor がある
- `SliverReorderableList` の display index と `blocks` index は逆向きに変換される
- `BlockItem` の `_Sidebar` は幅 48px で、現在は表示専用である
- duration block の高さは `duration * pixelsPerMinute` を基本に決まる
- `actionPoint` は 0 分 block だが、UI 上は point row として表示される

## Decision

- 初回は既存編集ビューだけを対象にする
- 左 timeline rail の hit area は見た目の 2px 線ではなく、`_Sidebar` の 48px 幅全体とする
- ダブルタップで挿入する block は `BlockType.action` とする
- 挿入される action の初期値は既存 `addBlock()` と同じく、title `新しい行動`、duration `15` 分を使う
- ダブルタップ位置から最も近い block 境界を選び、その境界に対応する `blocks` index へ挿入する
- target time は変更しない
- 新規 block の挿入によって、より過去側の開始時刻は必要に応じて過去へ押し出される
- ダブルタップで既存 action を分割したり、タップ位置の時刻に固定したりしない
- 挿入直後に詳細編集 sheet は自動表示しない。まずは既存の add button と同じく、block を追加する操作に留める

## Scope

- `_Sidebar` または sidebar wrapper に double tap handler を追加する
- `TimelineScreen` から `BlockItem` へ、display index ではなく `blocks` 上の source index または insert resolver を渡す
- duration block の sidebar 上半分 / 下半分から、過去側 / 未来側の境界を判定する
- `actionPoint` の sidebar でも、row 中央より上 / 下で過去側 / 未来側の境界を判定する
- target anchor の sidebar をダブルタップした場合、target 直前、つまり `blocks.length` に action を挿入できるようにする
- blocks が空の場合、target anchor の sidebar double tap で `index = 0` に action を挿入できるようにする
- 挿入後、追加された block がユーザーに分かるよう、軽い feedback を検討する
- active inline editor、詳細編集 sheet、reorder、duration drag と競合しないようにする

## Non-Goals

- タップ位置の正確な時刻へ block を作る機能は扱わない
- 既存 action の duration を分割して、その中に新規 block を差し込む機能は扱わない
- `actionPoint` 挿入は初回スコープに含めない
- compact overview view 上の double tap insert は扱わない
- timeline rail の long press menu は扱わない
- drag and drop による挿入位置選択は扱わない
- calendar export、text share、image share の仕様は変更しない

## Insertion Model

`blocks` が次の順序で並んでいるとする。

```text
blocks = [A, B, C]
```

`B` の過去側境界に挿入した場合:

```text
[A, 新しい行動, B, C]
```

`B` の未来側境界に挿入した場合:

```text
[A, B, 新しい行動, C]
```

### Boundary Rules

- source block の `blocks` index を `i` とする
- duration block の sidebar 上半分をダブルタップした場合、`insertIndex = i`
- duration block の sidebar 下半分をダブルタップした場合、`insertIndex = i + 1`
- `actionPoint` の row 中央より上をダブルタップした場合、`insertIndex = i`
- `actionPoint` の row 中央より下をダブルタップした場合、`insertIndex = i + 1`
- target anchor sidebar をダブルタップした場合、`insertIndex = blocks.length`
- empty timeline で target anchor sidebar をダブルタップした場合、`insertIndex = 0`

この rule は「タップした時刻」ではなく「最も近い隣接境界」を選ぶための rule である。

## Display Index Conversion

編集ビューは `computed` を reverse して表示しているため、実装では display index と `blocks` index を混同してはならない。

`SliverReorderableList` の `itemBuilder` で表示している block は概ね次の関係になる。

```dart
final n = computed.length;
final cb = computed[n - 1 - displayIndex];
final sourceIndex = n - 1 - displayIndex;
```

double tap insert では、`displayIndex` ではなく `sourceIndex` を基準に `insertIndex` を計算する。

## Interaction Model

1. ユーザーが左 timeline rail の 48px hit area をダブルタップする
2. active inline editor がある場合は、まず focus を外し、この double tap では挿入しない
3. 詳細編集 sheet が表示中の場合は、挿入前に閉じるか、sheet 表示中は rail double tap を無効化する
4. ダブルタップされた sidebar の local y から近い境界を決める
5. `TimelineNotifier.addBlock(insertIndex, BlockType.action)` を呼ぶ
6. 必要に応じて haptic feedback や短い highlight で挿入を示す

既存の block body tap、reorder handle、duration drag は右側または block 上端にあるため、左 sidebar の double tap と入力領域を分離できる。

## Requirements

- **Functional**: 左 timeline rail のダブルタップで新しい `action` block を挿入できる
- **Functional**: duration block の上半分 / 下半分で過去側 / 未来側の境界へ挿入できる
- **Functional**: `actionPoint` の sidebar でも前後の境界へ挿入できる
- **Functional**: target anchor の sidebar double tap で target 直前へ action を挿入できる
- **Functional**: empty timeline でも target anchor sidebar double tap から最初の action を作れる
- **Functional**: 挿入後も target time は固定され、逆算時刻が再計算される
- **Non-Functional**: モデル変更なしで既存の `Block` / `TimelineState` / `addBlock()` を再利用する
- **Non-Functional**: display index と `blocks` index の reverse 変換を明示的に扱う
- **Non-Functional**: left rail hit area は 48px 程度を確保し、2px 線だけを入力対象にしない
- **Non-Functional**: inline edit、reorder、duration drag、pinch zoom を壊さない

## Tasks

1. `BlockItem` に `sourceIndex` と sidebar double tap callback を渡せるようにする
2. `_Sidebar` またはその wrapper に `GestureDetector` を追加し、48px 幅全体で double tap を受ける
3. `TapDownDetails.localPosition.dy` と sidebar height から、過去側 / 未来側境界を判定する helper を作る
4. `TimelineScreen` の `itemBuilder` で `sourceIndex = n - 1 - displayIndex` を計算し、insert resolver に渡す
5. `TimelineNotifier.addBlock(insertIndex, BlockType.action)` を呼ぶ導線を追加する
6. target anchor sidebar へ double tap handler を追加し、`blocks.length` または empty 時の `0` へ挿入する
7. inline editor、sheet、plan panel、reorder 中、duration drag 中の競合時挙動を整理する
8. 挿入 feedback として短い highlight または haptic feedback を検討する
9. 実装後、timeline editor guide と domain reference に rail double tap insert の仕様を追記する

## Test Plan

- insertion helper の unit test で、上半分が `i`、下半分が `i + 1` になることを確認する
- reversed display order の widget test で、表示上の block と `blocks` index の対応が崩れていないことを確認する
- duration block sidebar 上半分の double tap で過去側へ action が挿入されることを確認する
- duration block sidebar 下半分の double tap で未来側へ action が挿入されることを確認する
- `actionPoint` sidebar の double tap で前後の境界へ挿入できることを確認する
- target anchor sidebar の double tap で target 直前へ挿入できることを確認する
- empty timeline で target anchor sidebar double tap から action が作成されることを確認する
- active inline editor がある場合、double tap がまず focus 解除に使われ、意図せず挿入しないことを確認する
- 既存の `flutter test test/widget_test.dart` を実行し、block tap、reorder、duration drag が壊れていないことを確認する
- 実機または desktop で、48px hit area が狭すぎず、誤操作が多すぎないことを手動確認する

## Deployment / Rollout

- 初回は編集ビューの left rail double tap insert として出す
- 誤操作が多い場合は、haptic / visual preview を強めるか、double tap のみを維持して single tap には機能を持たせない
- 境界判定が分かりづらい場合は、double tap 後に挿入位置を短く flash する
- 問題が出た場合は sidebar double tap handler だけを外し、既存の add button に戻せるようにする

## Review Checklist

- 左 rail の見た目 2px だけでなく、十分な hit area がある
- `displayIndex` と `blocks` index の逆向き変換を誤っていない
- 挿入位置がタップ位置に対して直感的である
- target time が変更されていない
- 新規 block は `BlockType.action` として追加されている
- `actionPoint` の前後にも挿入できる
- target anchor 直前と empty timeline の挿入が動く
- inline edit、reorder、duration drag、pinch zoom が壊れていない
- docs に「時刻固定や block 分割ではなく、境界への action 挿入」であることが明記されている
