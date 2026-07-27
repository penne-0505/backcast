---
title: Docs Template v1.2.0 Migration Plan
status: active
draft_status: n/a
created_at: 2026-07-28
updated_at: 2026-07-28
references:
  - "_docs/intent/Workflow/docs-template-v1-2-migration/decision.md"
  - "_docs/qa/Workflow/docs-template-v1-2-migration/test-plan.md"
related_issues: []
related_prs: []
---

# Docs Template v1.2.0 Migration Plan

## Overview

Backcast の owner-approved cutoff `P=9b86521052c2001419875504b4d0458d37162a00`
に対し、docs-driven template の exact release `v1.0.0` から `v1.2.0` までを
provenance-locked three-way migration で統合する。

## Provenance and cutoff

- Source: `https://github.com/penne-0505/docs_driven_dev_template.git`
- `B`: `v1.0.0` / `f71e9ab20466ea2972158334261f5ae2b2265754`
- `U`: `v1.2.0` / `a7fb411edb8974d0c4418fc675edc829c7600728`
- `P`: `main` / `9b86521052c2001419875504b4d0458d37162a00`
- Cutoff time: `2026-07-28T04:28:23+09:00`
- Cutoff manifest: staged 0、unstaged 0、untracked 0。`origin/main` と一致。
- Destination: owner-approved active working tree。
- Concurrent writers: none。parallel branch heads は対象外。
- Upstream included lane: `v1.0.0..v1.2.0` の release ancestry のみ。
- Upstream excluded lane: `origin/main` に未統合の branch head はなし。

baseline `./scripts/check-docs.sh` は全 validator、fixture、hook、paired-skill
check を通過した。この PASS を migration regression の比較起点とする。

## Scope

- Deno TypeScript validator bundle、fixtures、hooks、paired skill trees。
- TypeScript bundle に置換済みで参照元のない旧 `.mjs` と旧frontmatter fixture の削除。
- docs standards、templates、reader guidance、Docs CI。
- `starter/` に再編された consumer-facing files を downstream root へ正規化する。
- B/U/P union の全 path inventory と exact provenance lock。
- Risk High の QA verification と project path preservation review。

## Non-Goals

- upstream template repository 用の root router や `starter/` directory の導入。
- Medo の runtime/source/tests/assets、product behavior、feature scope の変更。
- project README、AGENTS、TODO を generic template 内容で置換すること。
- legacy intent / QA records の一括 strict schema conversion。
- migration と無関係な project files の削除。

## Requirements

- **Functional**: v1.2.0 の canonical TypeScript validators と hooks が Backcast の既存 records を legacy-compatible に検証する。
- **Functional**: `.agents` と `.claude` の paired skills が同期する。
- **Functional**: lock は compatibility PASS 後の最終 migration write とする。
- **Non-Functional**: inventory の各 path は upstream delta、project relation、resolution、rationale を一意に持つ。
- **Non-Functional**: blind replacement、branch mixing、premature lock、bulk schema edit、無許可 deletion を許容しない。
- **Non-Functional**: canonical callers を `.ts` へ移し、owner が明示許可した置換済み legacy files だけを参照確認後に削除する。

## Tasks

1. baseline と exact B/U/P を固定する。
2. normalized consumer view で三者 inventory を作る。
3. validator / fixture を導入し、unchanged project docs に対する compatibility を確認する。
4. standards / skills / hooks / CI / reader guidance を pathwise に統合する。
5. owner-authorized legacy files の参照元がないことを確認して削除する。
6. docs wrapper、fixtures、hook tests、paired skills、markdownlint、protected paths を検証する。
7. compatibility PASS 後に lock を v1.2.0 へ更新し、qa-review で closure を確認する。

## QA Plan

- QA document: `_docs/qa/Workflow/docs-template-v1-2-migration/test-plan.md`
- Risk level: High
- Validator / static check: `./scripts/check-docs.sh`、Deno format、markdownlint、lock review。
- Diff review: inventory reconciliation、project customization、protected runtime paths。
- Decision review: DEC-001〜DEC-004 の Why / Change freedom への適合を確認する。
- Rollback: migration diff の revert、または未コミット変更の採用中止。project data migration はない。

## Deployment / Rollout

active tree で pathwise に統合する。compatibility verification が FAIL / BLOCKED の場合は
lock を進めない。owner-authorized cleanup 後、`docs:` prefix の commit を作成して
`main` を origin へ push し、remote ref と CI state を確認する。
