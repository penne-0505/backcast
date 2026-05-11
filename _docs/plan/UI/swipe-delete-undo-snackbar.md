---
title: "Swipe Delete Undo Snackbar"
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/plan/UI/reorder-overview-scaling.md
related_issues: []
related_prs: []
---

## Overview

行動ブロックまたは行動ピンを右スワイプで削除した直後、ヘッダーの下に短い削除通知を表示し、`元に戻す` action で削除前の位置へ復元できるようにする。

この機能の狙いは、右スワイプ削除の軽さを維持しながら、誤削除の不安を下げることにある。削除確認ダイアログは挟まない。削除は即時反映し、直後の一時通知だけを復元導線にする。

## Problem

現状の `BlockItem` は `Dismissible` と pointer delta 判定の両方から `TimelineNotifier.deleteBlock` を直接呼び、削除後の復元手段を持たない。右スワイプは編集ビュー上の速い操作として有効だが、行動ブロックは時間、タイトル、色、余裕時間を含むため、誤削除時の損失感が大きい。

下部には浮遊ツールバー、timeline list button、詳細編集シート、template popover が集まっている。削除通知を下部へ置くと、既存の主操作面と競合しやすい。ヘッダー直下に置く方が、削除された block の位置から視線は少し離れるが、編集ツール群を塞がず、通知として読みやすい。

Flutter の公式 cookbook でも、削除直後の通知と optional action による復元は SnackBar の用途として示されている。ただし Flutter の標準 `SnackBar` は `ScaffoldMessenger` 管理で、基本配置は Scaffold 内の下部である。上部配置は `SnackBarBehavior.floating` と margin で実現可能かをまず確認し、不安定なら SnackBar と同じ意味を持つ local overlay banner として実装する。

## Scope

- 編集ビューの `action` / `actionPoint` を右スワイプで削除したとき、ヘッダー下に削除通知を表示する。
- 通知には削除対象の種別とタイトルを短く表示する。
- 通知には `元に戻す` action を置き、押すと削除前の index に同じ block data を復元する。
- 復元は swipe delete のみに接続する。詳細編集シートのゴミ箱削除は今回の初期 scope には含めない。
- 通知表示中に別 block を右スワイプ削除した場合は、最新削除を通知対象にし、復元 action は最新削除だけを復元する。
- 復元可能状態は local transient UI state とし、persistence schema や saved plan data model には追加しない。
- 実装後、guide / reference に「右スワイプ削除後の上部 SnackBar と復元」を追記する。

## Non-Goals

- multi-level undo / redo stack は作らない。
- 通知 timeout 後の redo、再削除 action、履歴一覧は作らない。
- 削除確認ダイアログは追加しない。
- block の id を新規採番して復元する設計にはしない。削除直後の undo では元の `Block.id` を保持する。
- Drift / SQLite の schema migration は行わない。
- template apply、timeline delete、account delete など、block swipe delete 以外の削除操作は扱わない。

## Requirements

- **Functional**: 右スワイプ削除後、ヘッダーより下、timeline content より上に削除通知が表示される。
- **Functional**: 通知は詳細編集シート、下部 floating toolbar、timeline list island modal、template popover を塞がない。
- **Functional**: `元に戻す` を押すと、削除された block が削除前の index に戻る。
- **Functional**: 復元後、選択状態やシート開閉状態は変えず、削除された block だけを戻す。
- **Functional**: 削除後に block 数や順序が変わっていた場合も、復元 index を現在の blocks length に clamp して戻す。
- **Functional**: 通知表示中にさらに削除した場合、前の復元通知は閉じ、最新削除だけを復元可能にする。
- **Functional**: 通知の timeout 後は復元 action を無効化し、以後は通常の削除済み状態として扱う。
- **Non-Functional**: undo state は `TimelineState` に永続化しない。画面 local state または UI event state に閉じる。
- **Non-Functional**: swipe delete の gesture threshold、read-only、sheet visible、inline edit、precise drag の既存ガードは変えない。
- **Non-Functional**: Android の戻る操作、画面回転、view mode 切り替えでクラッシュしない。必要なら通知を閉じる。
- **Non-Functional**: SnackBar / overlay はアクセシビリティ上読み上げ可能な text と明確な button label を持つ。

## Interaction Model

削除成立時の流れ:

1. `BlockItem` は直接 `deleteBlock` せず、削除対象 block id を親へ通知する。
2. `TimelineScreen` は現在の `TimelineState.blocks` から削除対象 block と index を snapshot する。
3. notifier で block を削除する。
4. ヘッダー下に通知を表示する。
5. `元に戻す` が押されたら、snapshot した block を現在の blocks に再挿入する。

通知 copy は以下を初期案にする。

- `action`: `「{title}」を削除しました`
- `actionPoint`: `「{title}」を削除しました`
- 空 title: `行動を削除しました` / `行動ピンを削除しました`
- action label: `元に戻す`

「redo」は undo 後にもう一度削除する機能としては扱わない。今回の要件では、削除通知と復元 action を提供することを `redo` ではなく `undo` として定義する。もし明示的な redo が必要になった場合は、multi-level history と別計画に分ける。

通知の位置は、まず標準の `ScaffoldMessenger.showSnackBar` を使い、`SnackBarBehavior.floating` と margin / width でヘッダー下に配置できるか確認する。標準 SnackBar が bottom anchor 前提で layout hack になる場合は、`TimelineScreen` の `Stack` 上に `_SwipeDeleteUndoBanner` を `Positioned(top: headerBottom + inset)` で重ねる。後者の場合も、見た目と API 上の責務は SnackBar 相当として扱い、guide では「上部 SnackBar」と説明する。

## Data / State Model

追加する transient model の候補:

```dart
class PendingBlockDelete {
  const PendingBlockDelete({
    required this.block,
    required this.originalIndex,
    required this.deletedAt,
  });

  final Block block;
  final int originalIndex;
  final DateTime deletedAt;
}
```

`TimelineNotifier` には、削除済み block を復元するための小さな API を追加する。

```dart
void restoreDeletedBlock(Block block, int index)
```

この API は `index.clamp(0, state.blocks.length)` へ insert する。復元対象と同じ id が既に存在する場合は二重挿入を避けて no-op にする。`selectedBlockId` は変更しない。

`deleteBlock` 自体を戻り値つき API に変更する案もあるが、既存呼び出し箇所が複数あり、詳細編集シート削除を今回 scope 外にするには副作用が広い。初期実装では `TimelineScreen` が snapshot を取り、notifier は restore API だけを増やす方が安全である。

## Implementation Notes

- `BlockItem` に `onSwipeDelete` callback を追加し、swipe delete 時は callback があればそれを呼び、なければ既存 `deleteBlock` に fallback する。
- `TimelineScreen` から `BlockItem` へ `_handleSwipeDeleteBlock` を渡す。
- `_handleSwipeDeleteBlock(String blockId)` は、削除前に block と index を取得し、既存の popover / sheet 状態を必要に応じて閉じてから削除する。
- 削除通知表示前に `ScaffoldMessenger.of(context).hideCurrentSnackBar()` を呼び、通知を単一化する。
- `SnackBarClosedReason.action` または overlay button callback で復元済みかどうかを記録し、timeout 後の遅延 callback が復元状態を壊さないようにする。
- view mode が compact に切り替わった場合、通知は閉じてもよい。復元 snapshot は通知 timeout まで保持してもよいが、初期実装では表示と状態の寿命を合わせる。
- notification / restore は persistence debounce と競合しうる。削除直後に auto-save が走っても、undo が同じ plan state を再更新すればよい。特別な persistence rollback は作らない。
- header 高さは既存 layout から定数または `MediaQuery.padding.top` を使って算出する。magic number だけで画面上端からの margin を決めない。
- banner の横幅は mobile では左右 20px inset、wide では最大幅を設定し、ヘッダー action と重ならないよう中央寄せにする。

## Tasks

1. `TimelineNotifier.restoreDeletedBlock(Block block, int index)` を追加し、重複 id と index clamp を扱う。
2. `BlockItem` に swipe delete callback を追加し、`Dismissible.onDismissed` と pointer delta 削除の両方を同じ callback に通す。
3. `TimelineScreen` に `PendingBlockDelete` 相当の local state と `_handleSwipeDeleteBlock` / `_restorePendingDeletedBlock` を追加する。
4. 標準 `SnackBar` の floating 上部配置を実機確認し、安定しない場合は `Stack` overlay の `_SwipeDeleteUndoBanner` へ切り替える。
5. 削除通知の文言、timeout、action label、accessibility label を実装する。
6. 連続削除時に最新削除だけが undo 対象になるよう、既存通知を閉じて pending state を差し替える。
7. view mode change、sheet open、timeline list open、template popover open 時の通知寿命を確認し、必要なら閉じる cleanup を追加する。
8. widget test で swipe delete 後の通知表示、undo 復元、連続削除、timeout 後の非復元を確認する。
9. `_docs/guide/medo/timeline_editor.md` と `_docs/reference/medo/timeline_domain_reference.md` を実装結果に合わせて更新する。

## Test Plan

- Unit / notifier:
  - `restoreDeletedBlock` が元 index に block を戻す。
  - index が現在 length を超える場合は末尾に戻す。
  - 同じ block id が既に存在する場合は二重挿入しない。
  - 復元後 `selectedBlockId` が変更されない。
- Widget:
  - action を右スワイプ削除すると削除通知と `元に戻す` が表示される。
  - actionPoint を右スワイプ削除しても同じ通知導線が出る。
  - `元に戻す` で削除前の位置へ戻る。
  - 連続削除時、1つ前ではなく最新削除が復元される。
  - inline edit / sheet visible / precise drag 中は既存どおり swipe delete が成立しない。
- Regression:
  - `flutter test test/widget_test.dart`
  - swipe / reorder / duration drag を含む既存 widget tests
  - `/home/penne/sdk/flutter/flutter/bin/dart analyze`
- Manual:
  - 小さい Android 幅でヘッダー下の通知が header action と重ならない。
  - 下部 floating toolbar、timeline list button、edit sheet を塞がない。
  - long title の block でも通知 text が破綻しない。
  - 連続で削除しても古い undo が誤って復元されない。

## Deployment / Rollout

初回は swipe delete のみへ接続し、詳細編集シートのゴミ箱削除には広げない。問題があれば `BlockItem.onSwipeDelete` callback を外して既存の直接 `deleteBlock` へ戻せる構成にする。

上部 SnackBar の標準実装が端末差で不安定な場合は、ScaffoldMessenger 依存をやめ、`TimelineScreen` 内の overlay banner に切り替える。どちらの場合も復元ロジックは `PendingBlockDelete` と notifier restore API に閉じ、表示方式の差し替えで state model を変えない。
