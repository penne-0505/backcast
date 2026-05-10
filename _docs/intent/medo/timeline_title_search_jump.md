---
title: Timeline Title Search Jump
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - README.md
  - _docs/archives/plan/UI/timeline-title-search-jump.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
related_issues: []
related_prs: []
---

## Context

長い timeline では、タイトルを覚えている block へ手動スクロールで戻る負担が大きくなります。
初期スコープでは全文検索ではなく、現在 plan 内の `Block.title` 検索とジャンプに絞る必要がありました。

## Decision

- 検索対象は現在 plan 内の `Block.title` のみとする
- 検索 UI state は plan persistence に保存しない
- match は timeline 順に保持し、next / previous で移動できるようにする
- ジャンプ時は対象 block の始点を読める位置へ scroll し、一時 highlight を付ける
- 検索開始時やジャンプ前に inline editor、詳細 sheet、plan panel との競合を閉じる

## Alternatives

- description / memo / time まで検索する案は、初期導線として対象が広すぎるため不採用
- 複数 plan 横断検索は、timeline list の役割と混ざるため不採用

## Rationale

検索ジャンプは移動補助であり、永続的なデータではありません。
UI state として閉じることで、plan の保存形式を汚さずに操作性だけを高められます。

## Consequences / Impact

- scroll offset は edit view の block 高さ推定に依存する
- compact overview と edit view は同じ matching model を共有する
- 検索中の highlight は時間経過で解除される

## Rollback / Follow-ups

- jump 精度に問題がある場合は対象 block key への ensure-visible 実装を検討する
- 複数 plan 検索が必要になった場合は persistence query と UI を別機能として設計する
