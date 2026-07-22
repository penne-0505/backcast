---
title: "QA Verification: docs template v1 synthetic-baseline migration"
status: active
draft_status: n/a
qa_status: partial
risk: High
qa_schema: 2
created_at: 2026-07-22
updated_at: 2026-07-22
references:
  - "_docs/intent/Workflow/docs-template-v1-migration/decision.md"
  - "_docs/plan/Workflow/docs-template-v1-migration/plan.md"
  - "_docs/qa/Workflow/docs-template-v1-migration/test-plan.md"
related_issues: []
related_prs: []
---

# QA Verification: docs template v1 synthetic-baseline migration

## Summary

Owner-authorized synthetic comparison baseline
`B=1f7c92c53fa9df63de05da046a049507fcb4efac` と clean cutoff
`P=7990a6c68e9b6c0a25e6bc4ed41e7add5b6866a3` を使い、
`U=v1.0.0@f71e9ab20466ea2972158334261f5ae2b2265754` を pathwise merge した。
B は exact adoption record ではない。direct tree evidence は B tree 32 path、B/P
common 26 path、B/P exact blob 17 path で、P には U exact blob も24 path ある。
この mixed evidence と owner authorization に基づき、P に現存した B/U overlap
は byte-identical を含めすべて `customized-shared` とした。

Compatibility migration: PASS。source union 407 path と migration-created / learned-hardening
artifact 13 path は inventory 420 row に対応し、raw/artifact missing/extra はすべて0。
resolution は apply=40、merge=47、keep=322、remove=6、defer=5、
disposition は quarantine=2、absent-at-P=6 である。`remove` 6 件はすべて
P ですでに absent な B-only path で、worktree 削除はない。P の
`_docs/standards/jj_workflow.md` は exact blob を `.template-legacy/standards/` に
quarantine し、active standard から外した。

Strict schema migration: DEFERRED。legacy project docs/tasks の一括 semantic rewrite は行っていない。
Backlog task は canonical future QA path を保持し、file existence は Ready / In Progress
で要求する regression test を追加した。

この compatibility PASS は、legacy-compatible な v1 統合の結果だけを表す。B より前の
template adoption history を再構築したことでも、legacy records の strict schema
migration を完了したことでもない。synthetic B の historical uncertainty、owner-scoped
strict migration、隔離済み旧 standard の保持と将来の deletion 判断が残るため、移行全体の
verification verdict は PARTIAL とする。

## Verification Verdict

Verdict: PARTIAL

Compatibility: PASS

## Commands Run

```bash
date --iso-8601=seconds
git status --short --branch
git rev-parse HEAD
git -C /home/penne/dev/tools/templates/docs_driven_dev_template rev-parse 'refs/tags/v1.0.0^{}'
./scripts/check-docs.sh
DD_SCOPE_PATHS="$SCOPE" DD_SCOPE_DIFF_FILTER=ACMR ./scripts/check-docs.sh
npx --yes markdownlint-cli2 "_docs/**/*.md" "_evals/**/*.md" README.md AGENTS.md TODO.md --config .markdownlint.jsonc
deno run --allow-read --allow-write --allow-env --allow-run scripts/test-validators.mjs
deno run --allow-read --allow-run=git scripts/test-agent-workflow-hook.mjs
deno run --allow-read scripts/test-agent-workflow-smoke.mjs
/home/penne/sdk/flutter/flutter/bin/flutter analyze
/home/penne/sdk/flutter/flutter/bin/flutter test
TMPDIR=/dev/shm/backcast-docs-template-v1/tmp /home/penne/sdk/flutter/flutter/bin/flutter test
TMPDIR=/dev/shm/backcast-docs-template-v1/tmp /home/penne/sdk/flutter/flutter/bin/flutter build web
git diff --name-only P -- lib test assets public web android ios linux macos windows supabase pubspec.yaml pubspec.lock analysis_options.yaml devtools_options.yaml _docs/plan/UI _docs/intent/medo _docs/qa/UI _docs/guide/medo _docs/reference/medo _docs/survey/UI
git diff --check
cmp .agents/skills/<skill>/SKILL.md .claude/skills/<skill>/SKILL.md
```

Result:

```text
B=1f7c92c53fa9df63de05da046a049507fcb4efac (synthetic; not exact adoption)
U=v1.0.0@f71e9ab20466ea2972158334261f5ae2b2265754
P=7990a6c68e9b6c0a25e6bc4ed41e7add5b6866a3 (clean cutoff)
unscoped/scoped docs wrapper: PASS
full docs markdownlint: 126 files, 0 issues
fixtures/hooks/smoke/paired skills: PASS
inventory: 407 source + 13 artifact = 420 rows; missing=0; extra=0
flutter analyze: PASS, no issues
flutter test first attempt: BLOCKED before test execution by /tmp ENOSPC
flutter test retry with tmpfs cache: PASS, 208 tests
flutter build web: PASS
protected project path diff: empty
```

## Automated Test Results

| Command / Test | Result | Notes |
| --- | --- | --- |
| unscoped `./scripts/check-docs.sh` | PASS | Full validators, fixtures, hooks, smoke checks passed. |
| working-tree scoped wrapper | PASS | Added/modified/deleted migration paths were explicitly supplied through `DD_SCOPE_PATHS`; ACMR accepted. |
| full docs markdownlint | PASS | 126 files, 0 issues; no global or local path exemption. |
| validator fixtures | PASS | correct-type, wrong-type, unknown-field, duplicate-block, scope, TODO/QA/Intent positive and negative cases passed. |
| agent hook unit/smoke | PASS | lifecycle hooks, audit guardrails, provenance reader docs and skill activation surfaces passed. |
| paired skill comparison | PASS | Nine `.agents` / `.claude` skill pairs are byte-identical. |
| Flutter analyze | PASS | No issues found. |
| Flutter tests | PASS | Retry after tmpfs redirect completed 208 tests. |
| Flutter web build | PASS | `build/web` completed; generated output remained outside Git diff. |
| protected path diff | PASS | runtime/source/tests/assets/UI project docs/checkpoint WIP are unchanged from P. |
| inventory schema/set checks | PASS | Five resolution values only; disposition separate; raw/artifact missing and extra are 0. |

## Manual QA Results

| Checklist Item | Result | Notes |
| --- | --- | --- |
| Synthetic provenance | PASS | Every migration authority describes B as synthetic/non-exact and records owner authorization. |
| Customization preservation | PASS | Every P-present B/U overlap is `customized-shared`; unchanged paths use keep and changed paths use merge. |
| Non-destructive removal handling | PASS | P's jj standard blob is exact in quarantine; no `rm` / `git rm` was used. |
| Active guidance hygiene | PASS | jj standard and upstream lifecycle-self-audit records are absent from active paths; generic QUICKSTART was not imported. |
| CI/lint scope | PASS | CI records ACMR and runs unscoped because no compatibility baseline was needed; full docs lint has no path ignores. |
| Original checkout/remotes | PASS | original checkout remains detached at P; no push, main change, or remote ref update occurred. |

## Acceptance Criteria Coverage

| ID | Result | Evidence |
| --- | --- | --- |
| AC-001 | PASS | Exact B/U/P, synthetic limitation, owner authorization and clean isolated cutoff are in Plan/Intent/QA/inventory. |
| AC-002 | PASS | Source union and artifact manifest each reconcile with missing/extra 0. |
| AC-003 | PASS | All overlap is conservatively customized; P content is merged/kept; jj is exact-blob quarantine. |
| AC-004 | PASS | Schema/Intent/QA fixtures pass, including wrong/unknown/duplicate cases and Backlog future refs. |
| AC-005 | PASS | CI has ACMR; no compatibility base was needed; full docs lint reports 0 issues without path ignores. |
| AC-006 | PASS | Scoped/unscoped wrappers, fixtures, hooks, smoke and paired skill comparison pass. |
| AC-007 | PASS | Analyze/tests/build pass and protected diff is empty. |
| AC-008 | PASS | UI-Feat-61 retains the planned QA/Verification trace with canonical path syntax; Backlog existence timing is tested. |
| AC-009 | PASS | Compatibility is PASS and strict schema is separately DEFERRED; exact-U lock is present. Overall verification remains PARTIAL for the documented residuals. |

## Decision Conformance

| ID | Result | Why the implementation remains aligned |
| --- | --- | --- |
| DEC-001 | PASS | B is used only as an owner-authorized synthetic comparison and never as exact adoption provenance. |
| DEC-002 | PASS | All P overlap is classified customized and resolved through keep/merge. |
| DEC-003 | PASS | New migration docs use schema v2 while legacy project records remain compatible until semantic edit/promotion; this is not strict schema completion. |
| DEC-004 | PASS | No permanent deletion occurred; stale standard/self-history is inactive or excluded. |
| DEC-005 | PASS | Product paths and checkpoint WIP have no diff and their project gates pass. |
| DEC-006 | PASS | Compatibility evidence is complete before creation of the exact-U lock. |

## Invariant Coverage

| ID | Result | Evidence |
| --- | --- | --- |
| INV-001 | PASS | Tag resolution and final lock source/tag/full SHA match U. |
| INV-002 | PASS | Protected P diff is empty. |
| INV-003 | PASS | Plan/Intent/QA/inventory/verification consistently say synthetic and non-exact. |

## Deferred / Not Covered

| ID | Reason | Follow-up |
| --- | --- | --- |
| Strict schema | Bulk conversion could invent DEC rationale or redefine legacy QA intent. | Migrate records individually when they receive semantic edits or through a separately owner-approved task. |
| QUICKSTART | Upstream generic root guidance would be stale in the established Medo repository. | Keep `_docs/documentation_guide.md` as the active project-specific reader entrypoint. |
| Upstream lifecycle self-history | It records template-repository implementation history, not Backcast project decisions. | Continue to exclude it from project guidance. |
| Pre-v1 exact history | Historical adoption cannot be reconstructed beyond the owner-authorized synthetic comparison. | Use the new exact U lock for every future migration; never reinterpret synthetic B as exact. |
| Quarantined jj standard | Owner prohibited permanent deletion of the customized removed path. | Keep its exact blob inactive under `.template-legacy/` unless deletion is separately authorized. |

## Residual Risks

- **Synthetic historical provenance**: B is owner-authorized comparison evidence, not an
  exact adoption record. Pre-v1 adoption history remains non-reconstructable unless new
  primary evidence is found; B must never be promoted to exact provenance.
- **Strict schema migration**: legacy records remain compatibility-accepted rather than
  strict-schema-complete. A separately owner-scoped task must semantic-review records
  before any bulk conversion; it is not part of this migration.
- **Quarantine and deletion**: the customized jj standard is retained inactive under
  `.template-legacy/` because permanent deletion was not authorized. Its future retention,
  removal, or deletion requires an owner decision and must preserve the non-destructive
  boundary until then.

## Follow-up TODOs

- Create a separately owner-scoped strict schema migration task only when its record-by-record
  semantic review scope is defined. It must not treat compatibility PASS as strict completion.
- If historical adoption evidence is discovered, review it as historical analysis only; do not
  replace the exact-U lock or reinterpret synthetic B as exact provenance.
- Keep the quarantined jj standard inactive until the owner explicitly decides whether to retain
  or delete it; any deletion remains outside this migration.
