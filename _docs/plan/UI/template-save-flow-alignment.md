---
title: Template Save Flow Alignment
status: proposed
draft_status: n/a
created_at: "2026-05-15"
updated_at: "2026-05-15"
references:
  - _docs/intent/medo/timeline_templates.md
  - _docs/intent/medo/timeline_list_management.md
  - _docs/plan/UI/template-toolbar-popover.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/persistence_repository_reference.md
related_issues: []
related_prs: []
---

## Overview

テンプレート保存の操作を、timeline list island modal の新規タイムライン作成フローへ揃える。
現在の template popover は「現在のタイムラインを保存」ボタンを押すと即座に `TimelineTemplateRepository.createTemplate(state: currentState)` を呼ぶ。
一方、timeline 作成は modal 上部で名前を入力してから作成し、作成前に現在 plan の pending autosave を flush する。

この変更では、テンプレート保存も「保存フォームを開く → 名前を入力する → 保存する → 一覧に反映する」という流れにし、保存前に現在 timeline の状態を明示的に確定する。

## Current Flow Gap

- `TimelineScreen._createTimelineFromList` は `_saveCurrentPlanNow()` を呼び、現在 plan を保存してから新しい plan を作成する。
- `TimelineListIslandModal` は上部に `_TimelineCreateForm` を表示し、作成時に名前を入力できる。空欄は `無題のタイムライン` に正規化される。
- `TemplateSheet._saveCurrent` は `ref.read(timelineProvider)` をその場で読み、名前入力なしで `TimelineTemplateRepository.createTemplate` を呼ぶ。
- `TimelineTemplateRepository._defaultTemplateTitle` は `targetTimeTitle` だけを見ており、現在 timeline name を既定名として使えない。
- template popover は `TimelineScreen` から表示されるが、保存処理自体は `TemplateSheet` 内に閉じているため、現在 plan の debounce 保存境界を共有していない。

推論として、ユーザーが「タイムラインの保存時フローと同じように」と言っている主対象は、repository の同一化ではなく、保存前に名前を決める操作モデルと保存対象確定の安心感だと判断する。

## Scope

- template popover 内に、timeline 作成フォームと同等の保存フォームを追加する。
- 既存の即時保存ボタンは、保存フォームを開く入口へ変更する。
- 保存フォームはテンプレート名入力、保存、キャンセルを持つ。
- 保存フォームを開いた時点で、現在 plan title または `targetTimeTitle` から既定名を補完する。
- 空欄または whitespace のみで保存した場合は `無題のテンプレート` に正規化する。
- テンプレート作成前に current plan の pending autosave を flush できる callback を `TemplateSheet` に渡す。
- 保存成功後はフォームを閉じ、テンプレート一覧を再読み込みする。
- Pro gate、Free では入口非表示、action 境界 gate は維持する。
- 実装後、guide / reference を更新する。

## Non-Goals

- Drift schema は変更しない。
- `timeline_templates` と `plans` の repository を統合しない。
- テンプレート適用、rename、delete の仕様は変更しない。
- テンプレートを current plan として切り替える機能は追加しない。
- テンプレート分類、検索、並び替え、共有、インポートは扱わない。
- Free ユーザー向けにテンプレート入口や Paywall 誘導を追加しない。

## Requirements

- **Functional**: Pro ユーザーは template popover で保存フォームを開き、名前を入力して現在 timeline をテンプレート保存できる。
- **Functional**: 保存フォームの primary action 実行前に current plan の pending autosave が flush される。
- **Functional**: 既定名は現在 timeline name を優先し、取得できない場合は `targetTimeTitle`、それも空なら `無題のテンプレート` を使う。
- **Functional**: 空欄保存は `無題のテンプレート` として保存される。
- **Functional**: 保存中は二重送信を防ぎ、保存後にテンプレート一覧へ新規テンプレートが表示される。
- **Functional**: 保存フォームのキャンセルで入力中状態を破棄し、既存一覧表示へ戻る。
- **Non-Functional**: template popover は現在の island 表現、one-turn dismissal、toolbar との競合回避を維持する。
- **Non-Functional**: narrow viewport で保存フォーム、一覧、閉じるボタンが縦方向に破綻しない。
- **Non-Functional**: `TimelineScreen` が autosave と current plan id の所有者である構造を保ち、`TemplateSheet` が直接 private save debounce を握らない。

## UI Flow

1. template toolbar button を押して template popover を開く。
2. 上部の保存入口を押すと、timeline list の新規作成フォームに近い compact form を popover 上部へ表示する。
3. 入力欄には既定テンプレート名を入れて focus する。
4. `保存` を押す、または keyboard submit で保存する。
5. 保存中は spinner / disabled state にし、連打を防ぐ。
6. 保存成功後はフォームを閉じ、一覧を reload する。
7. `キャンセル` でフォームを閉じ、入力値を破棄する。

文言は `テンプレート名`、primary action は `保存`、入口は既存の `現在のタイムラインを保存` を維持してよい。

## Persistence Boundary

`TemplateSheet` は current plan の autosave debounce を知らないため、保存前処理を callback として受け取る。
候補 API:

```dart
class TemplateSheet extends ConsumerStatefulWidget {
  const TemplateSheet({
    required this.onDismiss,
    this.onBeforeSaveCurrent,
    ...
  });

  final Future<void> Function()? onBeforeSaveCurrent;
}
```

`TimelineScreen` は `TemplateSheet(onBeforeSaveCurrent: _saveCurrentPlanNow, ...)` を渡す。
`TemplateSheet._saveCurrent` は Pro gate 後、`onBeforeSaveCurrent?.call()` を await してから、flush 後の `timelineProvider` state と明示された title で `createTemplate` を呼ぶ。

現在 timeline name を既定名に使うには、`TimelineScreen` 側で current plan summary/title を渡すか、`PlanRepository.loadPlan(currentPlanId)` を使う helper を置く。
UI 依存を小さくするため、推奨は `TemplateSheet` に `initialTemplateTitle` または `currentTimelineTitle` を渡すこと。
ただし、保存直前に current plan title が rename されうる場合は、callback 内または保存処理直前に current plan title を再取得する。

## Documentation

- `_docs/guide/medo/timeline_editor.md`: テンプレート保存手順を「保存フォームで名前を入力して保存」に更新する。
- `_docs/reference/medo/persistence_repository_reference.md`: `TimelineTemplateRepository.createTemplate` の title 指定、既定名、保存前 flush の UI 境界を追記する。
- `_docs/intent/medo/timeline_templates.md`: 実装後、テンプレート保存が即時ボタンではなく命名フォームを通る判断を追記する。

## Tests

- Widget:
  - Pro で template popover を開き、保存入口を押すとテンプレート名フォームが表示される。
  - フォームに名前を入力して保存すると、`TimelineTemplateRepository.listTemplates()` にその名前のテンプレートが追加される。
  - 空欄で保存すると `無題のテンプレート` になる。
  - 保存中は二重 tap してもテンプレートが重複作成されない。
  - キャンセルでフォームが閉じ、テンプレートは作成されない。
- Boundary:
  - `onBeforeSaveCurrent` が呼ばれてから `createTemplate` が実行される。
  - `onBeforeSaveCurrent` が例外を投げた場合、テンプレート作成を中断し、保存中状態を解除する。
- Regression:
  - `flutter test test/template_sheet_test.dart`
  - `flutter test test/widget_test.dart --plain-name "timeline island creates a named timeline from the top form"` 相当の既存フローが壊れていないことを確認する。
  - `dart analyze lib/template_sheet.dart lib/timeline_screen.dart test/template_sheet_test.dart`

## Deployment / Rollout

- schema migration は不要。
- 保存導線に問題が出た場合は、保存フォーム入口を非表示または旧即時保存ボタンへ戻すことで既存テンプレート一覧・適用・rename・delete は維持できる。
- 保存済みテンプレートデータは変更しない。
