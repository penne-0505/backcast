---
title: Timeline Two Step Density
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - README.md
  - _docs/archives/plan/UI/timeline-compact-overview.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
related_issues: []
related_prs: []
---

## Context

時間比例の編集ビューでは、長時間 block が画面の大半を占め、全体把握が難しくなります。
一方で、ユーザーが日常的に使う表示状態は「細部を編集する」か「全体を俯瞰する」かの二つに寄っており、連続的な倍率調整や固定高さの完全別 view は主導線として過剰でした。

## Decision

- 表示密度は「詳細編集」と「俯瞰」の二段階にする
- 詳細編集は旧 zoom slider の `0.9x` 相当を標準密度とする
- 俯瞰は固定高さ row の完全別 view ではなく、通常 timeline renderer を低密度で読む状態にする
- 俯瞰中は直接編集ではなく、全体把握と詳細編集への復帰に寄せる
- 表示切り替えボタンは左下の timeline list button の上に配置する
- view mode は `TimelineViewMode` として UI state に保持し、plan persistence には保存しない

## Alternatives

- 連続 slider は中間倍率をほとんど使わないため不採用
- pinch gesture を主導線にする案は、scroll、swipe delete、duration drag、reorder、inline edit と競合しやすいため不採用
- 固定高さ row の完全 compact overview は編集画面との断絶が強いため、主導線から外す
- 俯瞰で直接編集する案は、読む状態と触る状態の操作密度が衝突するため不採用

## Rationale

俯瞰は「どこに何があるか」を素早く読むための視点です。
ただし固定高さの別 renderer に切り替えると、詳細編集へ戻る前提が強くなり、見ている対象と編集対象の連続性が弱くなります。
同じ timeline renderer を低密度にすることで、画面上の構造を保ったまま詳細編集と俯瞰を往復できます。

## Consequences / Impact

- 俯瞰では下部の追加 toolbar、edit sheet、duration drag、reorder handle、inline edit を主操作として出さない
- 検索ジャンプやハイライトは view mode をまたいでも同じ timeline 上で意味が通る
- ヘッダーから zoom slider / compact toggle が消え、検索・export・設定に絞られる

## Rollback / Follow-ups

- 二段階 density が合わない場合は表示切り替えボタンを隠し、edit view のみへ戻せる
- 将来の比較 view は compact overview ではなく専用 renderer として扱う
