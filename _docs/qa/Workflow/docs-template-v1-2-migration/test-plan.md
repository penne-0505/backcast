---
title: "QA Test Plan: docs template v1.2.0 migration"
status: active
draft_status: n/a
qa_status: planned
risk: High
qa_schema: 2
created_at: 2026-07-28
updated_at: 2026-07-28
references:
  - "_docs/intent/Workflow/docs-template-v1-2-migration/decision.md"
  - "_docs/plan/Workflow/docs-template-v1-2-migration/plan.md"
related_issues: []
related_prs: []
---

# QA Test Plan: docs template v1.2.0 migration

## Source of Intent

- TODO: `Workflow-Chore-64`
- Plan: `_docs/plan/Workflow/docs-template-v1-2-migration/plan.md`
- Intent: `_docs/intent/Workflow/docs-template-v1-2-migration/decision.md`

## Quality Goal

Backcast 固有の guidance、records、application paths を保ったまま、v1.2.0 の exact
consumer workflow を legacy-compatible に統合し、次回 migration の再現可能な起点を作る。

## Acceptance Criteria

- AC-001: clean cutoff、exact B/U/P、destination、included/excluded lanes が記録される。
- AC-002: normalized B/U/P union の全 path に classification、resolution、rationale が一つずつある。
- AC-003: validators / fixtures が unchanged project docs と新しい schema marker cases を正しく検証する。
- AC-004: paired skills、hooks、Docs CI、reader guidance が canonical `.ts` workflow と整合する。
- AC-005: Medo 固有の README、AGENTS、TODO、standards extension、product records が wholesale replacement されない。
- AC-006: branch mixing、blind replacement、premature lock、bulk schema edit、無許可 deletion がない。
- AC-007: docs wrapper、format、markdownlint、hook tests、paired-skill checks が PASS する。
- AC-008: compatibility PASS 後の lock が exact U を指し、strict schema verdict が別に報告される。
- AC-009: owner-authorized legacy files 13件がexact targetだけ削除され、現行callerにdangling referenceがない。

## Decision Review Scope

- DEC-001: exact release lane と cutoff provenance。
- DEC-002: starter normalization と active root preservation。
- DEC-003: customization / legacy semantics の保全。
- DEC-004: lock ordering と exact release representation。
- DEC-005: replacement evidence、reference closure、owner authorityに基づく限定削除。

## Intent-derived Invariants

- INV-001: lock は project に実際に統合済みの exact release tag と full SHA を指す。

## Risk Assessment

- Risk level: High
- Risk rationale: validator、CI、hook、agent skill、migration provenance を同時に変更する。
- Regression risk: stale caller、paired tree drift、project guidance の上書き、legacy docs rejection。
- Data safety risk: application data / database は変更しない。protected path diff を確認する。
- Security / privacy risk: secret / permission scope を追加せず、hook の sensitive operation guard を fixture で確認する。
- UX risk: product runtime は変更しない。
- Agent misbehavior risk: branch mixing、blind replacement、premature lock、bulk schema edit、無許可 deletion。

## Test Strategy

- Unit: validator fixtures、hook unit tests。
- Integration: `./scripts/check-docs.sh`、scoped validation、paired-skill checks。
- E2E: Docs CI workflow の static review。remote run は scope 外。
- Manual QA: inventory reconciliation、customized shared paths、lock ordering。
- Validator / static check: Deno format、markdownlint、frontmatter / TODO / links / intent / QA。
- Diff review: cutoff 以後の changes、protected application paths、upstream B→U union。

## Test Matrix

| ID | Source | Requirement / Optional Invariant | Test Type | Command / File | Expected Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| AC-001 | TODO | exact provenance と clean cutoff | static review | Plan / lock / `git status` / tag resolution | B/U/P と lane が再現できる | verified |
| AC-002 | TODO | 全 path inventory | generated inventory review | `inventory.tsv` reconciliation script | missing / unresolved が 0 | verified |
| AC-003 | TODO | legacy-compatible validators | validator | `./scripts/check-docs.sh` | valid/invalid/warning cases が期待どおり | verified |
| AC-004 | TODO | canonical workflow alignment | fixture / diff review | hook tests、paired-skill checks、CI diff | `.ts` caller と paired trees が整合 | verified |
| AC-005 | DEC-003 | project customization preservation | diff review | `git diff -- README.md AGENTS.md TODO.md _docs` | semantic wholesale replacement がない | verified |
| AC-006 | TODO | agent misbehavior absence | inventory / diff review | refs、lock ordering、schema diff、deletion diff | prohibited pattern が 0 | verified |
| AC-007 | TODO | local closure gates | validator / lint | wrapper、Deno fmt、markdownlint | 全 command が exit 0 | verified |
| AC-008 | DEC-004 | compatibility / strict verdict separation | QA review | verification / final lock | exact U と separate verdict | verified |
| AC-009 | DEC-005 | owner-authorized obsolete file cleanup | static / regression | deleted path manifest、`rg`、wrapper | exact 13 targets deleted、active dangling refs 0 | verified |
| INV-001 | DEC-004 | lock exactness | provenance check | tag resolution と JSON comparison | tag / full SHA が U と一致 | verified |

## Manual QA Checklist

- [x] `starter/` が downstream root に導入されていない。
- [x] project-specific README / AGENTS / TODO / UI standard が保全されている。
- [x] owner-authorized 13 targets 以外に恒久削除がない。
- [x] lock が compatibility evidence より先に更新されていない。

## Regression Checklist

- [x] baseline で PASS した docs checks が migration 後も PASS する。
- [x] legacy project intent / QA docs が受理される。
- [x] `.agents` と `.claude` skill pairs が一致する。
- [x] product runtime/source/tests/assets に migration diff がない。

## High-risk Checklist

- [x] Rollback or recovery path is documented.
- [x] Data safety has been checked in the plan; runtime data paths are out of scope.
- [x] Security / privacy implications have been checked; permission scope is not expanded.
- [x] Failure mode is understood; FAIL / BLOCKED leaves the lock at B.

## Out of Scope

- strict schema bulk migration、permanent deletion、commit / push、remote CI execution。

## Open Questions

- None。
