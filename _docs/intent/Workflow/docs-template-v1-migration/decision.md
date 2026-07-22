---
title: Docs Template v1 Synthetic-Baseline Migration Decisions
status: active
draft_status: n/a
intent_schema: 2
created_at: 2026-07-22
updated_at: 2026-07-22
references:
  - "_docs/plan/Workflow/docs-template-v1-migration/plan.md"
  - "_docs/qa/Workflow/docs-template-v1-migration/test-plan.md"
related_issues: []
related_prs: []
---

# Docs Template v1 Synthetic-Baseline Migration Decisions

## Context

Backcast には exact template adoption record がなく、現在の docs bundle は複数の
upstream revision の blob が混在する。owner は `1f7c92c...` を exact B とは
主張せず、保守的分類に用いる synthetic baseline として承認した。

## Decisions

### DEC-001: B は owner-authorized synthetic comparison baseline とする

- **What**: `B=1f7c92c53fa9df63de05da046a049507fcb4efac` を B/U/P inventory の比較起点に使うが、exact adoption とは記載しない。
- **Why**: initial scaffold との一致証拠は他候補より多いが、履歴・lock・adoption record はなく、P 自体が mixed bundle であるため。
- **Change freedom**: 後日 exact adoption evidence が見つかれば historical analysis は更新できるが、v1 lock は実際に統合した U を指し続ける。

### DEC-002: P の template overlap は全て customization として保存する

- **What**: exact blob 一致を含め、P に存在する B/U overlap を全て `customized-shared` に分類し、`merge` または `keep` で解決する。
- **Why**: synthetic B から project ownership を復元することはできず、blind replacement は project-specific rule を失う可能性があるため。
- **Change freedom**: pathwise review で project-specific 意味がないと確認できる section は U の一般化された表現へ置き換えてよい。

### DEC-003: compatibility migration と strict schema migration を分離する

- **What**: schema-v2 validators は legacy docs と併存させ、新規 migration docs だけを v2 で作成する。既存 intent / QA の一括変換は deferred とする。
- **Why**: 機械的な schema rewrite は既存 rationale に新しい意味を追加し、project decision を変質させるため。
- **Change freedom**: 後続 task で各 decision を semantic review する strict migration は実施できる。

### DEC-004: 非破壊境界と active-guidance hygiene を両立する

- **What**: permanent deletion は行わない。U から消えた既存 path は customized として keep し、安全に証明できる場合だけ active path 外へ quarantine / deactivate する。upstream template self-history は導入しない。
- **Why**: owner は no permanent deletion を指定し、同時に stale template history を project の active guidance として誤認させないことを求めているため。
- **Change freedom**: owner-authorized deletion が後日得られれば quarantine を除去できる。

### DEC-005: migration は application behavior と checkpoint WIP を変えない

- **What**: runtime/source/tests/assets/UI project docs と P までの QA/timeline WIP を byte-preservation diff で守る。例外は TODO の `UI-Feat-61` canonical path syntax 修正だけとする。
- **Why**: docs workflow migration が product behavior や進行中 feature scope を暗黙に変えると rollback と review が困難になるため。
- **Change freedom**: product path の変更は別 task で実施できる。

### DEC-006: lock は compatibility PASS 後の最終 migration write とする

- **What**: `docs-template.lock.json` は source、`v1.0.0`、U full SHA を記録し、reconciled U compatibility が通るまで作成しない。
- **Why**: lock の先行更新は未統合の distribution を adopted と誤表示するため。
- **Change freedom**: 次回以降は exact locked B から tag-to-tag migration できる。

## Consequences / Impact

- inventory は conservative classification のため merge/keep が多くなる。
- compatibility は PASS できても strict schema migration は DEFERRED として報告する。
- synthetic B は将来も exact provenance として再解釈しない。

## Quality Implications

- branch mixing、blind replacement、premature lock、bulk schema edit、unproven deletion は failure とする。
- inventory raw diff と artifact manifest の missing/extra が 0 であることを機械検証する。
- validators / hooks / paired skills / CI scope / full lint / project gates を検証する。

## Intent-derived Invariants

- INV-001 (from DEC-006): lock は実際に統合した U の source/tag/full SHA だけを指す。
- INV-002 (from DEC-005): migration commit は runtime/source/tests/assets と UI project docs を変更しない。
- INV-003 (from DEC-001): migration record は synthetic B を exact adoption baseline と主張しない。

## Enforced in (optional)

- DEC-001 / DEC-002: `_docs/qa/Workflow/docs-template-v1-migration/inventory.tsv`
- DEC-003: validators と compatibility / strict verdict。
- INV-001: `docs-template.lock.json` と provenance checks。
- INV-002: protected path diff と Flutter regression gates。
- INV-003: Plan / Intent / QA / Verification の provenance wording review。

## Rollback / Follow-ups

- 専用 branch の単一 commit を revert する。
- strict schema migration は owner が希望する場合のみ別 task で行う。
