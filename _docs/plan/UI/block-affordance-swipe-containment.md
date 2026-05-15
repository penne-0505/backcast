---
title: Block Affordance Swipe Containment
status: active
draft_status: n/a
created_at: "2026-05-16"
updated_at: "2026-05-16"
references:
  - _docs/standards/ui_layering.md
  - _docs/intent/medo/reverse_timeline_interaction_model.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/plan/UI/reorder-overview-scaling.md
related_issues: []
related_prs: []
---

## Overview

行動ブロックの右スワイプ中に、所要時間ピル、移動ハンドル、長さ調整ハンドルがブロック本体から剥がれて見える問題を解消する。

現状の `BlockItem` は、右側 body 領域の `Stack` に対して、カード本体を `Dismissible` の `child` として置き、所要時間ピル、移動ハンドル、長さ調整ハンドルを `Dismissible` の外側 sibling として `Positioned` している。そのため、スワイプ時に `Dismissible` が移動させる対象と、ユーザーが「そのブロックに属する」と見る affordance の範囲が一致しない。

この plan では、これら 3 つの affordance を `Dismissible` の `child` 側へ移し、カード本体と同じ水平移動に追従させる。タイムライン rail / sidebar はブロック body 外の時間軸なので対象外とする。

## Scope

- `lib/block_item.dart` の action block body 構造を調整する。
- 所要時間ピルを `Dismissible` の child 内に含め、右スワイプ中にカードと一緒に移動させる。
- 移動ハンドルを `Dismissible` の child 内に含め、右スワイプ中にカードと一緒に移動させる。
- 長さ調整ハンドルを `Dismissible` の child 内に含め、現在の上端 overhang 表現を維持したままカードと一緒に移動させる。
- 既存の `pillAndHandleBottomInset` による buffer segment 回避を維持する。
- `readOnly`、overview mode、precise drag、reorder、swipe delete の既存 gate を維持する。
- 必要に応じて widget test を追加し、スワイプ中に affordance が `Dismissible` child と同じ移動対象に入っていることを確認する。

## Non-Goals

- `Sidebar` / rail / 時刻ラベルをスワイプ対象に含めない。
- action point の swipe 構造は、今回の違和感が同じ形で出ていない限り変更しない。
- reorder preview / insertion line の設計は変更しない。
- `_QuickReorderListener` の hold 時間や `SliverReorderableList` の reorder model は変更しない。
- 長さ調整ハンドルの見た目、幅、precise mode の仕様は変更しない。
- swipe delete の閾値、snackbar undo、削除 state management は変更しない。

## Requirements

- **Functional**: action block を右スワイプしたとき、カード本体、所要時間ピル、移動ハンドル、長さ調整ハンドルが一体として横移動する。
- **Functional**: 右スワイプ背景は従来どおり body 領域の背面に表示される。
- **Functional**: 所要時間ピルは buffer あり block でも action section 側の中央に表示され、buffer segment へ被り込まない。
- **Functional**: 移動ハンドルは従来どおり右 52px の hit area から reorder を開始できる。
- **Functional**: 長さ調整ハンドルは従来どおり block 上端に overhang して表示され、右 56px を除外した hit area で duration drag を受ける。
- **Non-Functional**: 変更は `BlockItem` の action block layout に閉じ、timeline 計算、永続化、template、calendar export へ影響させない。
- **Non-Functional**: UI layer としては Timeline Canvas 内の block affordance であり、新しい overlay / modal / popover layer は追加しない。
- **Non-Functional**: gesture-heavy 変更なので、少なくとも swipe delete、duration drag、reorder の targeted regression を通す。

## Current Layout

現状の action block は概ね次の構造になっている。

```text
BlockItem
  Row
    Sidebar
    Expanded body
      Stack
        Positioned.fill
          Dismissible
            child: GestureDetector
              Column
                action card Container
                optional BufferSegment
        Positioned duration pill
        Positioned reorder handle
        Positioned drag handle
```

この構造では、`Dismissible` が水平移動させるのは `GestureDetector` 以下だけであり、後続の `Positioned` affordance は同じ body `Stack` に残る。見た目上は同じカードに属しているため、スワイプ中に所属関係が割れて見える。

## Target Layout

目標構造は次の通り。

```text
BlockItem
  Row
    Sidebar
    Expanded body
      Dismissible
        child: Stack
          Positioned.fill
            GestureDetector
              Column
                action card Container
                optional BufferSegment
          Positioned duration pill
          Positioned reorder handle
          Positioned drag handle
```

`Dismissible` の外側に残すのは、body 自体の clipping / sizing に必要な最小 wrapper までとする。これにより、右スワイプ中の移動対象と、ユーザーが action block に属すると見る affordance の範囲を一致させる。

## Implementation Notes

- `_wrapSwipeDelete` は `Dismissible` を返す責務を維持し、渡す `child` をカード本体だけではなく body affordance stack に拡張する。
- 既存の `Expanded(child: Stack(...))` の中に `Dismissible` を置くのではなく、`Expanded(child: _wrapSwipeDelete(... child: Stack(...)))` に寄せる。
- `Stack(clipBehavior: Clip.none)` は維持する。長さ調整ハンドルが `top: -_DragHandle.overhang` で上へ出るため、ここを clip すると見た目と hit area が変わる。
- `GestureDetector` はカード本体の `Positioned.fill` 側へ残す。所要時間ピルや reorder handle の hit area がカード選択 tap と競合しないよう、現在の重なり順を保つ。
- `Positioned.fill` のカード本体、duration pill、reorder handle、drag handle の描画順は現状と同じにする。カード本体の上に pill / handle が来る。
- `Dismissible.background` は body affordance stack の背面として表示される。スワイプ時に背景が pill / handle の下から見える状態は維持される。
- `readOnly` の場合 `_wrapSwipeDelete` は `child` をそのまま返すため、内包後も compact view では swipe delete は無効になる。
- action point の `_wrapSwipeDelete` 呼び出しは現状維持する。point は pill / drag handle を持たず、今回の所属ズレの主対象ではない。

## Risks

- 長さ調整ハンドルの `top: -overhang` が `Dismissible` 内へ移ることで、hit test の親境界が変わる可能性がある。`Stack(clipBehavior: Clip.none)` と既存 widget test で確認する。
- reorder handle が `Dismissible` child 内へ入ることで、横スワイプと reorder hold の arena 競合の体感が変わる可能性がある。既存 `_QuickReorderListener` の hit area と delay は変更しない。
- 所要時間ピルと reorder handle はカードより前面に描画されるため、スワイプ中に背景から完全には独立しない。これは意図した一体移動であり、背景の reveal は body 全体の背面に残す。
- 既存 test が `find.byType(Dismissible)` の rect や hit target を暗黙に見ている場合、tree 構造変更により調整が必要になる。

## Tasks

1. `lib/block_item.dart` の action block body で、`_wrapSwipeDelete` の child をカード本体から body affordance stack 全体へ広げる。
2. 所要時間ピル、移動ハンドル、長さ調整ハンドルを `Dismissible` child 内へ移し、既存の `Positioned` 値を維持する。
3. `Stack(clipBehavior: Clip.none)` と `pillAndHandleBottomInset` の挙動を維持し、buffer あり block で pill / handle が action section に留まることを確認する。
4. 右スワイプ削除、短い右スワイプ非削除、duration drag precise mode、reorder handle の targeted widget test を実行する。
5. 必要なら widget test に、action block 内の affordance が `Dismissible` subtree に入っていることを確認する軽量 test を追加する。
6. 実装結果により操作説明が変わる場合のみ、timeline editor guide / timeline domain reference を同期する。今回の予定仕様どおりなら user-facing docs の文言変更は不要。

## Test Plan

- Static / structure:
  - `dart analyze lib/block_item.dart test/widget_test.dart`
  - 必要に応じて `flutter test test/widget_test.dart --plain-name "right swipe deletes an action block"`
  - 必要に応じて `flutter test test/widget_test.dart --plain-name "short right swipe does not delete an action block"`
  - 必要に応じて `flutter test test/widget_test.dart --plain-name "drag handle enters precise mode after hold and allows 1-minute adjustment"`
- Regression:
  - `flutter test test/widget_test.dart`
- Manual / visual:
  - action block を右スワイプし、所要時間ピル、移動ハンドル、長さ調整ハンドルがカードと一緒に水平移動することを確認する。
  - buffer あり block で、ピルと移動ハンドルが buffer segment ではなく action section に揃うことを確認する。
  - block 上端の長さ調整ハンドルがスワイプ後も上端に乗って見え、上下 drag に反応することを確認する。

## Deployment / Rollout

schema、永続化、platform code への影響はない。問題が出た場合は、`Dismissible` の child 範囲を現状のカード本体のみに戻せば rollback できる。

gesture 競合が出た場合は、まず hit area の所有境界を確認し、reorder / duration drag の delay や recognizer を同時に変更しない。必要な場合は別 task として扱う。

## Implementation Result

2026-05-16 に実装済み。action block の `Dismissible` child は、カード本体、所要時間ピル、移動ハンドル、長さ調整ハンドルを含む body stack へ広がった。

長さ調整ハンドルは `Dismissible` 配下に入ることで親の swipe gesture と競合しやすくなったため、縦ドラッグの更新は `GestureDetector` ではなく raw pointer move で処理する。これにより、表示上は block と一体で右スワイプに追従しつつ、既存の 1 分単位 precise drag を維持する。

検証では、affordance が `Dismissible` subtree に含まれること、右スワイプ削除、短いスワイプ非削除、長さ調整 precise drag、reorder hold、および `test/widget_test.dart` 全体の回帰を確認した。
