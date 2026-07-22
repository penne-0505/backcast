---
title: Docs Template v1 Synthetic-Baseline Migration Plan
status: active
draft_status: n/a
created_at: 2026-07-22
updated_at: 2026-07-22
references:
  - "_docs/intent/Workflow/docs-template-v1-migration/decision.md"
  - "_docs/qa/Workflow/docs-template-v1-migration/test-plan.md"
related_issues: []
related_prs: []
---

# Docs Template v1 Synthetic-Baseline Migration Plan

## Overview

Backcast の owner-approved cutoff `P=7990a6c68e9b6c0a25e6bc4ed41e7add5b6866a3`
に対し、docs-driven template `v1.0.0` (`U=f71e9ab20466ea2972158334261f5ae2b2265754`)
を pathwise に統合する。比較用 `B=1f7c92c53fa9df63de05da046a049507fcb4efac`
は owner-authorized synthetic baseline であり、exact adoption baseline とはみなさない。

## Synthetic provenance and authorization

- owner は、initial scaffold の候補の中で `B` が最大の exact/common-path
  evidence を持つ一方、exact adoption record がないことを承知した上で synthetic
  comparison baseline として使うことを承認した。
- `P` には複数の後続 upstream revision 由来の mutually exclusive blob が混在する。
  そのため `P` に現存する template overlap は byte-identical を含め全て
  `customized-shared` とし、B との一致だけで upstream-owned と判定しない。
- `B` は provenance lock に記録しない。lock は compatibility PASS 後に実際の
  adopted distribution `U` の source/tag/full SHA だけを記録する。

## Root-cause evidence and competing explanation

Root-cause evidence は、P に provenance lock と v1 の migration skill / inventory skill /
intent validator / lifecycle hooks がなく、baseline `./scripts/check-docs.sh` が
`UI-Feat-61` の non-canonical QA path を検出したことである。これは P が v1
distribution として再現可能に reconciled されていないことを示す。

反証候補は、P が単に古い template ではなく、U と exact な validator / fixture
blob と U と異なる後続 bundle blob をすでに部分導入していることである。
この説明は「全てを U で置換する」処方を否定するが、「v1 の exact
provenance で current bundle を pathwise reconcile する」必要性は否定しない。

## Non-local effects and compatibility horizon

- **Callers / data flow**: application runtime の caller/data flow は変更しない。hook は agent
  lifecycle event のみを読み、product data を読書きしないことをテストする。
- **Tests / CI**: docs wrapper は validator fixture、hook unit/smoke、markdownlint を追加する。
  CI diff scope は added/copied/modified/renamed を見落とさない `ACMR` に固定する。
- **Docs / operations**: legacy docs をすぐに rewrite せず、validator は unmarked legacy
  schema を受理する。この compatibility support horizon は「owner-approved strict
  schema migration が完了するまで」であり、無期限の新規 legacy authoring を
  認める契約ではない。
- **Future maintenance**: 次回移行は synthetic B ではなく `docs-template.lock.json`
  の exact `v1.0.0` を B とする。project-specific validator customization は inventory
  と intent で追跡する。

Local patch として validator の一部だけを直すと、provenance、paired skills、hook、
CI scope が引き続きドリフトする。durable solution は U を配布単位として
reconcile し、exact lock と path inventory を次回更新の起点にすることである。

## Scope

- B/U/P と migration-created artifacts の path inventory。
- legacy-compatible validators、fixtures、hooks、paired skills、standards、templates、CI、root guidance。
- baseline で検出された `UI-Feat-61` の QA / Verification path の canonical 化。
- exact `v1.0.0` provenance lock と verification evidence。

## Non-Goals

- runtime/source/tests/assets/UI feature documents の内容変更。
- checkpoint された QA / timeline WIP の実装継続や完了扱い。
- legacy project docs の一括 strict schema conversion。
- permanent deletion、push、main / remote ref の更新。
- upstream lifecycle-self-audit という template 自身の履歴を project record として導入すること。

## Requirements

- inventory の resolution は `apply|merge|keep|remove|defer` の5値に限定し、
  quarantine / deactivate / supersede 等は独立した disposition に記録する。
- 存在する mixed bundle path は `customized-shared` として pathwise merge または keep する。
- CI の diff scope は `DD_SCOPE_DIFF_FILTER=ACMR` とする。
- schema fixture は correct-type、wrong-type、unknown-field、duplicate-field を区別する。
- full markdown lint は 0 error とし、project-wide local/global exemption で隠さない。
- baseline compatibility pin は lint-only legacy modification が必要な場合に限り、blob 固定で使う。
- stale template guidance は active loader / standard path に残さない。ただし非破壊に
  quarantine 可能と証明できない既存 customization は keep し、residual に明記する。

## Tasks

1. clean isolated worktree と B/U/P evidence を固定する。
2. inventory を作り、全 overlap を保守的に customized として解決する。
3. validators / fixtures を先に統合し、unchanged project docs への compatibility を確認する。
4. standards / templates / paired skills / hooks / CI / guidance を pathwise merge する。
5. docs、fixtures、hooks、paired tree、Flutter analyze/test/build、protected diff を検証する。
6. verification を確定し、compatibility PASS 後に lock を最終 write する。

## QA Plan

`_docs/qa/Workflow/docs-template-v1-migration/test-plan.md` を source of truth とする。

## Deployment / Rollout

隔離 branch の P 直下に単一 commit を作る。rollback はその commit の revert
または branch を採用しないことで完了する。push と main 更新は行わない。
