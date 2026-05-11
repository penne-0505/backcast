---
title: UI Layering Standard Alignment
status: active
draft_status: n/a
created_at: "2026-05-12"
updated_at: "2026-05-12"
references:
  - _docs/standards/ui_layering.md
  - _docs/intent/medo/reverse_timeline_interaction_model.md
  - _docs/guide/medo/timeline_editor.md
related_issues: []
related_prs: []
---

## Overview

完成した UI 階層化標準に合わせて、Medo のタイムライン画面に散っている overlay / popover / sheet / toolbar の表現と dismissal ルールを段階的に整理する。

この計画の目的は、見た目の統一だけではなく、入力イベントの所有権を揃えることにある。
特に、Quick Overlay と Work Surface の境界、scrim / blur / absorber の使い分け、surface / shadow token の責務、Work Surface 表示中の header action の扱いを標準へ寄せる。

一括で全 UI を修正すると gesture、focus、dismissal、widget test の変更が混ざりやすいため、低リスクな token 整理から始め、visual layer、open / dismiss 挙動、test 更新の順に進める。

## Scope

- `lib/theme.dart` の shadow token を UI 階層化標準に合わせて整理する。
- `TemplateSheet` の popover 用直書き shadow を標準 token へ移す。
- `export panel` を Quick Overlay として扱い、scrim なし、透明 absorber あり、surface shadow / border ありの表現へ寄せる。
- `edit sheet` の blur を標準外表現として再検討し、明確な理由がなければ scrim のみに寄せる。
- Work Surface 表示中に Header Panels / Floating Commands を押した場合、同じ tap で別 action を開かず、まず Work Surface を閉じるだけにする。
- Quick Overlay 表示中の背面 tap は close のみに使い、背面 action を同時に発火させない。
- 実装後、`_docs/guide/medo/timeline_editor.md` と必要な reference / intent を実装結果に合わせて更新する。

## Non-Goals

- タイムラインのドメインモデル、永続化 schema、billing / Pro gate の仕様は変更しない。
- template の保存、適用、rename、delete の機能仕様は変更しない。
- export のカレンダー登録、テキスト共有、画像共有の実行ロジックは変更しない。
- ヘッダー、floating toolbar、timeline list、template UI の大規模な再配置は行わない。
- 新しい UI framework や animation system は導入しない。
- visual regression のためだけの screenshot test 基盤新設は今回の必須 scope に含めない。

## Requirements

- **Functional**: Quick Overlay は scrim を持たず、透明 absorber によって外側 tap を close のみに変換する。
- **Functional**: Work Surface は scrim を持ち、背面操作を止める。
- **Functional**: Work Surface 表示中に Header Panels / Floating Commands の action を押しても、その tap では Work Surface を閉じるだけにする。
- **Functional**: Quick Overlay 同士は共存せず、開く前に他の Quick Overlay を閉じる。
- **Functional**: Work Surface 同士は共存しない。
- **Functional**: Blocking Decision は現在の操作面の上に表示し、背面 action を実行しない。
- **Non-Functional**: Quick Overlay は scrim なしでも surface shadow / border / radius / fill によって背景から読み分けられる。
- **Non-Functional**: Blur は標準表現にしない。必要な場合は可読性上の理由を実装コメントまたは intent / guide 側に残す。
- **Non-Functional**: Floating Commands の primary / secondary / context action hierarchy を崩さない。
- **Non-Functional**: 変更後も narrow viewport で toolbar、popover、sheet が重ならない。

## Phases

### Phase 1: Token Alignment

低リスクな token 整理を先に行う。

- `AppShadows.quickOverlay` を追加し、現行 `TemplateSheet` popover の二段 shadow を token 化する。
- 必要なら `AppShadows.workSurface` を `AppShadows.sheet` の alias として追加し、Work Surface 用 token の責務を明確にする。
- 新規 UI では `AppShadows.panel` を使わない方針に合わせ、既存利用があれば用途を確認する。
- `TemplateSheet` の popover surface を `AppShadows.quickOverlay` 参照へ置き換える。

### Phase 2: Visual Layer Alignment

scrim / blur / surface の表現を標準へ寄せる。

- `export panel` の scrim を外し、Quick Overlay として透明 absorber + surface shadow / border にする。
- `edit sheet` の backdrop blur を外し、Work Surface の既定である scrim のみに寄せる。
- timeline list island modal は Work Surface として scrim ありを維持する。
- template popover は Quick Overlay として scrim なしを維持する。
- visual 変更後、small / narrow viewport で overlap と可読性を確認する。

### Phase 3: Dismissal / Open Action Alignment

入力イベント所有権を標準へ揃える。

- Work Surface 表示中に header search / export / settings / floating commands を押した場合、同じ tap で次 action を実行せず、まず Work Surface を閉じるだけにする。
- Quick Overlay 表示中に Timeline Canvas / Floating Commands を押した場合、同じ tap では Quick Overlay を閉じるだけにする。
- Quick Overlay を開くときは、Inline editor と他 Quick Overlay を閉じる。
- Work Surface を開くときは、gesture transient、Inline editor、Quick Overlay、既存 Work Surface を閉じる。
- Blocking Decision の下に Quick Overlay が残る場合は、Quick Overlay 上の操作そのものを確認するケースに限定する。

### Phase 4: Regression Coverage

変更した dismissal / overlay 挙動を widget test で固定する。

- export panel が scrim なし Quick Overlay として表示され、外側 tap で閉じることを確認する。
- Quick Overlay 表示中に toolbar / timeline を tap しても背面 action が同時発火しないことを確認する。
- edit sheet 表示中に header search / export を tap しても、同じ tap では search / export が開かず sheet だけ閉じることを確認する。
- timeline list island modal 表示中に header / toolbar action を tap しても、同じ tap では背面 action が発火しないことを確認する。
- template popover の apply / delete confirmation が Blocking Decision として上に出ることを確認する。

## Implementation Notes

- `TimelineScreen` の open / close 関数を、UI 種別ごとに整理する。例: close quick overlays、close work surfaces、consume tap for current surface など。
- ただし、抽象化はやりすぎない。現状の UI 数では、過度な state machine 化より、標準に沿った明示的な helper に留める。
- `Stack` の child 順は `_docs/standards/ui_layering.md` の Layer Model と一致させる。
- Header Panels と Lightweight Popovers はどちらも Quick Overlay として扱うが、描画 layer は Header Panels が Layer 3、Lightweight Popovers が Layer 4 のままとする。
- 既存テストが「閉じて同じ tap で開く」挙動を前提にしている場合は、標準に合わせて期待値を更新する。
- visual 変更は screenshot がない場合でも、widget geometry と hit test の regression を優先して固定する。

## Test Plan

- Static:
  - `/home/penne/sdk/flutter/flutter/bin/dart analyze lib/theme.dart lib/timeline_screen.dart lib/template_sheet.dart lib/edit_sheet.dart`
- Widget:
  - `/home/penne/sdk/flutter/flutter/bin/flutter test test/widget_test.dart`
  - 必要に応じて `test/template_sheet_test.dart` を追加実行する。
- Manual / visual:
  - narrow Android 相当幅で、export panel、template popover、edit sheet、timeline list island modal を順に開き、scrim / shadow / overlap / outside tap の挙動を確認する。
  - Work Surface 表示中の header / toolbar tap が「閉じるだけ」になっていることを確認する。
  - Quick Overlay 表示中の背面 tap が close のみに使われることを確認する。

## Deployment / Rollout

- Phase 1 から順に実装し、各 phase ごとに差分と test を確認する。
- Phase 2 以降で操作感に違和感が出た場合は、visual layer と dismissal layer を分けて rollback できるようにする。
- 問題が出た場合は、token 追加は残しつつ、export panel / edit sheet の表現変更だけを戻せるよう、各変更を小さく保つ。
- 実装完了後、`_docs/standards/ui_layering.md` に標準と異なる例外が残っていないか確認し、必要なら intent 化してこの plan を archive する。
