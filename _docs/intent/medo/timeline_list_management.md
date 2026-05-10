---
title: Timeline List Management
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - README.md
  - _docs/archives/plan/UI/timeline-slot-toggle.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/persistence_repository_reference.md
related_issues: []
related_prs: []
---

## Context

複数タイムラインは固定 slot ではなく、既存の `plans` を日常的に扱う保存済み timeline list として提供する必要がありました。
また、最後に開いた plan を復元し、切り替え前に現在の未保存変更を flush する必要があります。

## Decision

- `plans` を timeline list の source of truth とする
- 起動時は persisted `currentPlanId` を優先して復元する
- timeline list は下端に接地した sheet ではなく、独立した island modal として表示する
- 作成時に名前を入力できるようにし、rename / delete も modal 内に集約する
- current plan 削除時は残存 plan または新規空 plan へ切り替え、削除済み ID を current として残さない
- Free は最大 2 件、Pro は無制限とする

## Alternatives

- 固定 2 slot toggle は、将来の利用実態と rename/delete 管理に弱いため不採用
- header に timeline 名 inline edit を置く案は、検索や export などの入口と競合するため不採用

## Rationale

保存済み timeline は「別々の予定の棚」であり、比較機能とは別概念です。
list-first にすると作成、命名、切り替え、削除、Pro gate を同じ操作面で扱えます。

## Consequences / Impact

- `PlanRepository` は current plan preference を保存・復元する
- UI は切り替え前に autosave を flush する
- Pro から Free へ戻っても超過 plan は削除しない

## Rollback / Follow-ups

- list modal に問題がある場合は入口表示を止め、既存の current plan 利用へ縮退できる
- 同じ予定の候補比較は `Timeline Alternative Comparison` として別 plan に残す
