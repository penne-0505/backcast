---
title: Template Toolbar Popover
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - _docs/intent/medo/timeline_templates.md
  - _docs/intent/medo/pro_free_gate.md
  - _docs/intent/medo/reverse_timeline_interaction_model.md
  - _docs/guide/medo/timeline_editor.md
related_issues: []
related_prs: []
---

## Overview

テンプレート機能の入口を画面ヘッダーから編集画面下部の浮遊ツールバーへ移す。
Pro ユーザーはツールバー上のテンプレートボタンから、ボタン付近にポップアップするテンプレート UI を開ける。
Free ユーザーにはテンプレートボタン自体を表示しない。

この変更は、テンプレートを「全画面共通のヘッダー操作」ではなく、「編集中の現在 timeline に対する再利用操作」として位置付け直す。

## Scope

- `lib/timeline_screen.dart` の `_PlanHeader` からテンプレート action を取り除く。
- 編集画面の浮遊ツールバー周辺にテンプレート action を追加する。
- `effectiveIsProProvider` が `true` の場合だけテンプレートボタンを表示する。
- テンプレート UI をボトムシートではなく、ツールバーの該当ボタンを起点にした island / popover として表示する。
- popover 表示中は、既存の edit sheet、timeline list、zoom popover、export panel、inline editor と競合しないように閉じる順序を整理する。
- `TemplateSheet` の保存・適用・rename・delete の action 境界 Pro gate は維持する。
- widget test で Pro / Free の表示分岐と popover 表示を確認する。
- `_docs/guide/medo/timeline_editor.md` など、ユーザー向け操作説明がヘッダー入口を前提にしている場合は更新する。

## Non-Goals

- テンプレートのデータモデル、Drift schema、repository API は変更しない。
- テンプレート作成・適用・rename・delete の仕様は変更しない。
- Free ユーザー向けにテンプレートボタンから Paywall へ誘導する導線は追加しない。
- 課金状態の source of truth は変更せず、引き続き `effectiveIsProProvider` を参照する。
- ヘッダー全体の再設計、検索、zoom、export、設定導線の再配置は扱わない。

## Requirements

- **Functional**: Pro ユーザーの編集画面では、テンプレートボタンが下部ツールバーから利用できる。
- **Functional**: Free ユーザーの編集画面では、テンプレートボタンが表示されない。
- **Functional**: ヘッダーにはテンプレートボタンが表示されない。
- **Functional**: テンプレートボタンを押すと、ツールバー付近にテンプレート UI が popover / island として表示される。
- **Functional**: popover 表示中も背面の toolbar / timeline action は利用でき、別 action を実行すると同時にテンプレート UI が閉じる。
- **Functional**: テンプレートの保存・適用・rename・delete は既存の action 境界 gate を通る。
- **Non-Functional**: narrow viewport でも下部ツールバーの主要 action とテンプレート action が押しづらくならない。
- **Non-Functional**: ボトム toolbar の各 action は、既存 intent に従い一体型の長いバーではなく独立した浮遊オブジェクトとして見える。
- **Non-Functional**: popover 表示中に edit sheet / timeline list / export panel / zoom popover と重なって操作不能にならない。

## UI Model

テンプレートボタンは、既存の「タイムライン一覧」ボタンと「前の行動を追加」ツールバーの間、または補助 action 群として独立した丸形ボタンに置く。
推奨は、主要操作である「前の行動を追加」の横幅を過度に奪わない位置に、`PhosphorIcons.cards()` を使った 48-56px の独立ボタンとして配置すること。

popover は既存 `TemplateSheet` の中身を再利用しつつ、画面下端から全幅で立ち上がる sheet ではなく、左右マージンを持つ island としてツールバー直上に表示する。
推論だが、この形にするとテンプレートが「画面全体のモード変更」ではなく「現在の編集作業に差し込む補助操作」として認識されやすい。
surface は `AppColors.canvas`、`AppRadius.xl`、`AppColors.softGray.withValues(alpha: 0.55)` の `0.6` border、下方向の二段 shadow（`AppColors.ink` alpha `0.14`, blur `28`, spread `-4`, offset `(0, 14)` と alpha `0.08`, blur `10`, spread `-2`, offset `(0, 4)`）を基準とする。
同種の非モーダル overlay / popover を追加する場合も、この surface 値をまず使う。

Free ではボタンを非表示にするため、テンプレート機能の訴求は Paywall や設定画面側に寄せる。
この仕様は、既存 intent の「Free でテンプレート導線から Paywall へ遷移する」と異なるため、実装完了後に `timeline_templates` / `pro_free_gate` の intent を更新する。

## Implementation Notes

1. `_PlanHeader` から `onTemplateTap` property と `headerAction(...cards...)` を削除する。
2. `TimelineScreen.build` で `final isPro = ref.watch(effectiveIsProProvider);` を読み、floating toolbar 表示条件へ渡す。
3. `_FloatingToolbar` に `showTemplateAction` と `onTemplateTap` を追加し、Pro の場合だけテンプレートボタンを描画する。
4. `_showTemplateSheet` は Free 時 Paywall 遷移を担わず、popover 表示前の競合 UI close と focus 解除に責務を絞る。
5. `TemplateSheet` の外枠を sheet 専用の full-width / top-rounded container から、popover として再利用できる wrapper に分ける。既存 class を残す場合は `TemplateSheetSurface` のような内部 component へ中身を切り出す。
6. `_templateSheetVisible` の配置を `Positioned(left/right/bottom)` の island 表示に変更し、scrim は置かない。
7. 背面 action の実行時に popover を閉じ、ユーザーに「閉じるためだけの追加タップ」を要求しない。
8. ガイドと intent の文言を、実装結果に合わせて「ヘッダー入口」から「ツールバー入口」へ更新する。

## Test Plan

- Widget test:
  - `effectiveIsProProvider = false` ではテンプレートボタンが見つからない。
  - `effectiveIsProProvider = true` ではテンプレートボタンが下部ツールバーに表示される。
  - Pro でテンプレートボタンを tap すると `TemplateSheet` または新しい popover surface が表示される。
  - ヘッダー内に `PhosphorIcons.cards()` のテンプレート action が残っていない。
- Widget / interaction test:
  - popover 表示中に toolbar action を押すと、popover が閉じ、その action が同じ操作で実行される。
  - timeline list / zoom popover / export panel を開いた状態からテンプレートを開くと、競合 UI が閉じる。
- Manual QA:
  - narrow Android viewport で、タイムライン一覧、テンプレート、ポイント追加、行動追加の hit area と overlap を確認する。
  - Pro から Free 相当に provider override した場合、保存済みテンプレートデータを削除せず入口だけ消えることを確認する。

## Deployment / Rollout

- 既存テンプレートデータと schema には触れないため migration は不要。
- UI に問題が出た場合は、テンプレートボタンの表示条件を一時的に `false` に倒すことで基本編集機能へ戻せる。
- 実装完了後、`_docs/intent/medo/timeline_templates.md` と `_docs/intent/medo/pro_free_gate.md` の Free 時導線差分を更新し、この plan は intent 化後に archive する。
