---
title: "QA Verification: docs template v1.2.0 migration"
status: active
draft_status: n/a
qa_status: verified
risk: High
qa_schema: 2
created_at: 2026-07-28
updated_at: 2026-07-28
references:
  - "_docs/intent/Workflow/docs-template-v1-2-migration/decision.md"
  - "_docs/plan/Workflow/docs-template-v1-2-migration/plan.md"
  - "_docs/qa/Workflow/docs-template-v1-2-migration/test-plan.md"
related_issues: []
related_prs: []
---

# QA Verification: docs template v1.2.0 migration

## Summary

Backcast の clean cutoff `P=9b86521052c2001419875504b4d0458d37162a00` に、
docs-driven template `v1.0.0` から exact `v1.2.0` を pathwise に統合した。
Medo 固有の guidance、legacy records、product paths は保全し、canonical workflow
caller は Deno TypeScript bundle へ更新した。
owner の明示許可後、置換済みでactive referenceのない旧 `.mjs` 10件と
旧frontmatter fixture 3件を削除した。

Compatibility migration: **PASS**。
Strict schema migration: **NOT PERFORMED / OUT OF SCOPE**。既存 legacy records は
互換受理し、新規または semantic edit する record から schema v2 を使う。

## Verification Verdict

Verdict: PASS

## Commands Run

```bash
./scripts/check-docs.sh
npx markdownlint-cli2 "_docs/**/*.md" "_evals/**/*.md" "README.md" "AGENTS.md" "TODO.md" --config .markdownlint.jsonc
git diff --check
git diff --name-only --diff-filter=D 9b86521052c2001419875504b4d0458d37162a00 --
git diff --quiet 9b86521052c2001419875504b4d0458d37162a00 -- lib test assets android ios linux macos public supabase pubspec.yaml pubspec.lock
git -C /home/penne/dev/tools/templates/docs_driven_dev_template rev-parse 'refs/tags/v1.0.0^{}'
git -C /home/penne/dev/tools/templates/docs_driven_dev_template rev-parse 'refs/tags/v1.2.0^{}'
```

Result:

```text
check-docs: PASS
markdownlint-cli2: 133 files, 0 issues
inventory: expected=430 rows=430 missing=0 extra=0 duplicates=0
inventory enums/rationales: 0 invalid or unresolved
deleted paths: exact owner-authorized 13 targets
active dangling references to deleted targets: 0
starter directory: absent
protected project paths: unchanged
B: f71e9ab20466ea2972158334261f5ae2b2265754
U/lock: a7fb411edb8974d0c4418fc675edc829c7600728
```

430-path inventory は inline Python reconciliation で B/U/P union と照合し、row count、
missing、extra、duplicate、enum、rationale を検査した。lock JSON は resolved tag SHA と比較した。

## Automated Test Results

| Command / Test | Result | Notes |
| --- | --- | --- |
| `./scripts/check-docs.sh` | PASS | TypeScript format、validators、fixtures、hook unit/smoke、paired skills |
| markdownlint-cli2 | PASS | 133 Markdown files、0 issues |
| Inventory reconciliation | PASS | 430 / 430 paths、missing / extra / duplicate / unresolved 0 |
| Provenance lock check | PASS | B と U の tag resolution、final lock が full SHA と一致 |
| Protected path diff | PASS | product runtime/source/tests/assets に migration diff なし |
| Authorized cleanup / starter check | PASS | exact 13 targets deleted、active dangling refs 0、downstream `starter/` なし |

## Manual QA Results

| Checklist Item | Result | Notes |
| --- | --- | --- |
| Exact B/U/P and active-tree cutoff | PASS | full SHA、clean manifest、destination、lane を Plan に記録 |
| Customized shared paths | PASS | Medo README / AGENTS / TODO / UI standard を保全 |
| Starter normalization | PASS | consumer files は root caller として統合し、template router は導入せず |
| Legacy compatibility | PASS | flat legacy intent、Backlog future QA refs、project root references を regression coverage 付きで維持 |
| Lock ordering | PASS | compatibility gates の PASS 後にだけ lock を更新 |
| Owner-authorized cleanup | PASS | replacement、参照閉包、exact target manifestを確認して13件だけ削除 |

## Acceptance Criteria Coverage

| ID | Result | Evidence |
| --- | --- | --- |
| AC-001 | PASS | exact B/U/P と 430-path inventory が再現可能で未解決 path 0 |
| AC-002 | PASS | v1.2.0 validators / skills / hooks / CI caller が local closure gates を通過し、customization を保全 |
| AC-003 | PASS | final lock は exact v1.2.0 SHA を指し、strict schema は別判定で明記 |
| AC-004 | PASS | paired skills、hooks、Docs CI、reader guidanceはcanonical TypeScript workflowと整合 |
| AC-005 | PASS | Medo固有のguidance、records、product pathsを保全 |
| AC-006 | PASS | branch mixing、blind replacement、premature lock、bulk schema edit、無許可削除なし |
| AC-007 | PASS | wrapper、format、hook tests、paired checks、markdownlintがPASS |
| AC-008 | PASS | compatibility PASSとstrict schema未実施を別判定で記録 |
| AC-009 | PASS | owner-authorized 13 targetsのみ削除し、active dangling refs 0 |

## Decision Conformance

| ID | Result | Why the implementation remains aligned |
| --- | --- | --- |
| DEC-001 | PASS | release ancestry は exact `v1.0.0..v1.2.0` だけで、branch head を混在させていない |
| DEC-002 | PASS | `starter/` consumer view を root へ正規化し、初期化済み project の active path を維持した |
| DEC-003 | PASS | customized shared paths は keep / merge し、legacy records の bulk semantic rewrite を行っていない |
| DEC-004 | PASS | reconciliation と compatibility checks の後に lock を U へ進めた |
| DEC-005 | PASS | exact replacementとreference closureを確認し、owner-authorized targetsだけを削除した |

## Invariant Coverage

| ID | Result | Evidence |
| --- | --- | --- |
| INV-001 | PASS | lock source / tag / full SHA が resolved U と一致 |

## Deferred / Not Covered

| ID | Reason | Follow-up |
| --- | --- | --- |
| Strict schema migration | compatibility update に semantic bulk conversion は不要で、rationale を発明する危険がある | 既存 record を semantic edit するときに record-by-record で schema v2 へ移行 |
| Remote Docs CI | commit 前には実行できない | local CI-equivalent checks は PASS。push 後にremote runを確認する |

## Residual Risks

None

## Follow-up TODOs

None
