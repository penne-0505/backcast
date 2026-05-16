---
title: Timeline Templates
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-18"
references:
  - README.md
  - _docs/archives/plan/Core/timeline-templates.md
  - _docs/plan/UI/template-toolbar-popover.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/persistence_repository_reference.md
  - _docs/intent/medo/pro_free_gate.md
related_issues: []
related_prs: []
---

## Context

日常的に繰り返す逆算パターンは、現在 timeline を毎回手で再構成するより、テンプレートとして保存・適用できる方が効率的です。
ただしテンプレート適用は現在 plan を置き換える操作なので、保存、復元、snapshot、Pro gate の境界を明確にする必要がありました。

## Decision

- テンプレートは Drift の `timeline_templates` / `timeline_template_blocks` に正規化して保存する
- 保存、一覧、読み込み、rename、delete は `TimelineTemplateRepository` に集約する
- 適用時は fresh block IDs を採番し、現在 plan へ反映する
- 適用前または適用時に snapshot を作成し、復元可能性を確保する
- テンプレート UI は Pro 機能として gate する
- テンプレート入口はヘッダーではなく、Pro の編集ビュー下部ツールバーに置く
- Free ではテンプレート入口ボタン自体を表示しない
- テンプレート保存は即時保存ボタンではなく、template popover 上部の命名フォームを通す
- テンプレート作成前に current plan の pending autosave を flush し、保存対象を確定する

## Alternatives

- `TimelineState` JSON snapshot だけで保存する案は、一覧表示や rename、将来 migration に弱いため不採用
- テンプレート適用で既存 block ID を再利用する案は、選択状態や比較・履歴との衝突を招くため不採用
- Free ユーザーにもテンプレートボタンを表示して Paywall へ遷移させる案は、編集ツールバー上の利用可能 action と実際に使える action がずれるため不採用
- 保存ボタン押下だけで即時にテンプレート化する案は、timeline list の新規作成と操作モデルがずれ、保存対象の名前と未保存編集の境界が曖昧になるため不採用

## Rationale

テンプレートは「現在 plan のコピー」ではなく、再利用可能な型です。
fresh ID と snapshot を組み合わせることで、適用後の編集と復元を安全に扱えます。
入口を下部ツールバーへ寄せることで、テンプレートを全体設定ではなく現在 timeline の編集操作として扱えます。
保存時に命名フォームと autosave flush を挟むことで、「どの名前で、どの時点の timeline を型として残したか」が UI と永続化境界の両方で明確になります。

## Consequences / Impact

- schema 変更時は template block 側にも migration が必要になる
- bufferMinutes は template block 属性として保存・復元される
- Free ではテンプレート入口を表示しない
- 保存・適用・rename・delete の action 境界 Pro gate は残るため、内部的に UI が呼ばれても Free では mutation できない

## Rollback / Follow-ups

- テンプレート UI に問題がある場合は入口を閉じても保存済みテンプレートは保持する
- 将来、テンプレート分類や並び替えが必要になった場合は metadata を追加する
