---
title: Timeline Compact Overview
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
俯瞰には編集時の物理的な長さより、順序、時刻、所要時間、節目の識別が重要です。

## Decision

- compact overview は時間比例の縮小ではなく、固定高さ row の list とする
- block の長さは row height ではなく duration badge / time range / 補助表示で伝える
- compact view は直接編集ではなく、一覧性と編集ビューへの復帰に寄せる
- view mode は `TimelineViewMode` として UI state に保持し、plan persistence には保存しない

## Alternatives

- `pixelsPerMinute` を下げるだけの案は、長時間 block の占有問題を根本的に解決しないため不採用
- compact view で直接編集する案は、固定高さ row の目的と操作密度が衝突するため不採用

## Rationale

俯瞰は「どこに何があるか」を素早く読むための視点です。
編集ビューと同じ時間比例を維持するより、固定行高で scan しやすくする方が目的に合います。

## Consequences / Impact

- compact view では現在時刻インジケーターなど edit view 専用表示を出さない
- 検索ジャンプやハイライトは view mode をまたいでも意味が通るようにする

## Rollback / Follow-ups

- compact view が不要になった場合は view mode toggle を隠し、edit view のみへ戻せる
- 将来の比較 view は compact overview ではなく専用 renderer として扱う
