---
title: "QA Test Plan: docs template v1 synthetic-baseline migration"
status: active
draft_status: n/a
qa_status: planned
risk: High
qa_schema: 2
created_at: 2026-07-22
updated_at: 2026-07-22
references:
  - "_docs/intent/Workflow/docs-template-v1-migration/decision.md"
  - "_docs/plan/Workflow/docs-template-v1-migration/plan.md"
related_issues: []
related_prs: []
---

# QA Test Plan: docs template v1 synthetic-baseline migration

## Source of Intent

- TODO: `Workflow-Chore-63`
- Plan: `_docs/plan/Workflow/docs-template-v1-migration/plan.md`
- Intent: `_docs/intent/Workflow/docs-template-v1-migration/decision.md`

## Decision Review Scope

- DEC-001: synthetic provenance と owner authorization。
- DEC-002: all-overlap conservative customization preservation。
- DEC-003: compatibility / strict schema separation。
- DEC-004: no deletion と active-guidance hygiene。
- DEC-005: application / WIP preservation。
- DEC-006: lock ordering と exact U provenance。

## Quality Goal

synthetic B の限界を隠さず、Backcast 固有の product と WIP を変えずに v1 docs
workflow を legacy-compatible に統合する。

## Completion Boundary

この QA の compatibility PASS は、現存する legacy records を受理したまま exact U を
pathwise に統合できることだけを示す。B 以前の採用履歴を復元したこと、または legacy
records の strict schema migration を完了したことは示さない。したがって、compatibility
checks が PASS でも、synthetic historical provenance、strict schema の別 task、隔離した
旧 standard の保持に残る判断は verification で residual として報告する。

## Acceptance Criteria

- AC-001: exact B/U/P、clean cutoff、synthetic/non-standard provenance、owner authorization が記録される。
- AC-002: raw B/U/P union と migration artifacts が inventory に全件対応し、missing/extra が 0 である。
- AC-003: P の template overlap がすべて customized として keep/merge され、恒久削除がない。
- AC-004: validators が legacy compatibility を保ち、wrong/unknown/duplicate schema fixture を区別する。
- AC-005: docs CI が `ACMR` scope を使い、full lint が local/global exemption なしで0 error である。
- AC-006: docs wrapper の scoped/unscoped、fixtures、hooks、paired skills が成功する。
- AC-007: Flutter analyze/test/build が成功し、protected project paths の diff が 0 である。
- AC-008: baseline `UI-Feat-61` path failure が内容を隠さず canonical path syntax だけの修正で解消する。
- AC-009: compatibility PASS 後の lock が exact U を指し、strict schema は別 verdict である。

## Intent-derived Invariants

- INV-001: lock は exact U source/tag/full SHA を指す。
- INV-002: runtime/source/tests/assets/UI docs に migration diff がない。
- INV-003: B は synthetic と明記され、exact adoption と主張されない。

## Risk Assessment

- Risk level: High
- Regression risk: legacy docs の誤拒否、customization loss、validator/CI の scope 漏れ。
- Data safety risk: synthetic baseline を exact と誤認した deletion。
- Security / privacy risk: lifecycle hooks が authority を拡張する、secret を出力する。
- Agent misbehavior risk: branch mixing、blind replacement、premature lock、bulk schema edit、stale active guidance。
- Operational risk: docs CI の実行時間と agent hook の呼び出しが増える。fixture/hook
  tests で deterministic な境界を確認し、product operation とは分離する。

## Test Strategy

- validator: unchanged project docs への compatibility、fixtures、scoped/unscoped wrapper。
- static: inventory schema/set equality、paired skill cmp、hook settings、provenance、CI ACMR。
- lint: repository canonical full markdownlint run で0 error。
- regression: Flutter analyze/test/build と protected path diff。
- review: migration diff と DEC / AC / INV conformance。

## Test Matrix

| ID | Source | Requirement / Invariant | Test Type | Command / File | Expected Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| AC-001 | TODO | synthetic B/U/P provenance | static | `git rev-parse`, migration docs | exact identities and authorization wording | verified |
| AC-002 | TODO | zero inventory gaps | diff | inventory reconciliation script | missing=0, extra=0 | verified |
| AC-003 | TODO | customization/no-deletion | diff | inventory + `git diff --name-status` | overlap is merge/keep; no deletion | verified |
| AC-004 | TODO | schema compatibility | fixture | `scripts/test-validators.mjs` | all positive/negative/warning cases PASS | verified |
| AC-005 | TODO | ACMR and lint 0 | static/lint | CI review + markdownlint | exact ACMR; 0 errors | verified |
| AC-006 | TODO | docs/hook/paired checks | automated | `./scripts/check-docs.sh`, hook tests, `cmp` | PASS | verified |
| AC-007 | TODO | product preservation | regression | Flutter analyze/test/build + path diff | PASS / empty | verified |
| AC-008 | TODO | baseline failure repair | validator/diff | TODO diff + wrapper | canonical paths, unchanged semantics | verified |
| AC-009 | TODO | final lock / split verdict | static | lock and verification review | exact U; compatibility PASS と strict schema DEFERRED、overall PARTIAL の境界 | verified |
| INV-001 | intent | exact U lock | static | JSON/tag/SHA checks | exact values | verified |
| INV-002 | intent | project path preservation | diff | P..HEAD protected paths | empty | verified |
| INV-003 | intent | no exact-B claim | search/review | migration record review | synthetic wording throughout | verified |

## Manual QA Checklist

- [x] B を exact adoption baseline と読める記載がない。
- [x] migration-created artifacts も inventory に含まれる。
- [x] upstream lifecycle self-history が active project guidance に導入されていない。
- [x] compatibility と strict schema verdict が別々に記録される。
- [x] compatibility PASS を historical reconstruction または strict completion と読めない。

## Regression Checklist

- [x] P の runtime/source/tests/assets/UI docs/checkpoint WIP は保存される。
- [x] README と project-specific standards/guides は project context を保つ。
- [x] original checkout / main / remote は更新しない。

## High-risk Checklist

- [x] rollback / recovery は isolated branch の単一 commit revert とする。
- [x] no permanent deletion を data safety boundary とする。
- [x] security 境界として external upstream scripts は実行前に内容を review する。

## Out of Scope

- strict schema bulk conversion、product feature changes、dependency updates、push/main/ref update。

## Open Questions

- None。
