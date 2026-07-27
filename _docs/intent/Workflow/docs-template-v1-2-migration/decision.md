---
title: Docs Template v1.2.0 Migration Decisions
status: active
draft_status: n/a
intent_schema: 2
created_at: 2026-07-28
updated_at: 2026-07-28
references:
  - "_docs/plan/Workflow/docs-template-v1-2-migration/plan.md"
  - "_docs/qa/Workflow/docs-template-v1-2-migration/test-plan.md"
related_issues: []
related_prs: []
---

# Docs Template v1.2.0 Migration Decisions

## Context

Backcast は v1.0.0 の exact tag / full SHA を lock 済みで、以後に project 固有の
guidance と records が追加されている。v1.2.0 は validators の TypeScript 化、frontmatter
hardening、workflow-sensitive path の guardrail、template 配布物の `starter/` 再編を含む。

## Decisions

### DEC-001: exact release 間だけを migration lane とする

- **What**: `B=v1.0.0/f71e9ab...` と `U=v1.2.0/a7fb411...` を full SHA で固定し、active tree cutoff `P=9b865210...` と比較する。
- **Why**: moving branch tip や別 branch を混ぜると、統合した配布物と lock の内容を再現できないため。
- **Change freedom**: 将来の更新では、当時の lock と新しい推奨 release tag の exact SHA を新しい B/U として使える。

### DEC-002: upstream の starter 再編を downstream root へ正規化する

- **What**: `starter/` 内の consumer-facing paths は root path として比較・統合し、template-repository 用 router と `starter/` directory 自体は導入しない。
- **Why**: Backcast は初期化済み consumer project であり、starter state を導入すると active AGENTS / hooks / TODO の探索経路が変わるため。
- **Change freedom**: upstream が別の明示的な consumer manifest を提供した場合は、同じ「初期化済み project の active root を保つ」目的を満たす変換へ変更できる。

### DEC-003: project customization と legacy records を semantic review なしに置換しない

- **What**: Medo 固有の README、AGENTS、TODO、standards extension、records を keep / merge し、新規 migration docs のみ schema v2 で作る。
- **Why**: generic template での wholesale replacement や bulk schema edit は、project 固有の判断理由と実行経路を失わせるため。
- **Change freedom**: project-specific semantics を保つ pathwise merge と、別 task での record-by-record strict schema migration は実施できる。

### DEC-004: lock は reconciled release の事後証明とする

- **What**: validators、standards、skills、hooks、CI の compatibility が確認された後にだけ、lock を U へ進める。
- **Why**: lock の先行更新は、未統合または検証失敗した release を adopted と誤表示するため。
- **Change freedom**: verification の具体的な command set は release 内容に応じて更新できるが、lock が実統合済み exact release を指す順序は保つ。

### DEC-005: owner-authorized cleanup は置換証拠と参照閉包がある files に限定する

- **What**: v1.2.0 で TypeScript bundle / strict fixture に置換され、現行 caller から参照されない旧 `.mjs` 10件と旧frontmatter fixture 3件だけを削除する。
- **Why**: duplicate implementation とobsolete fixture を残すと、保守者が非canonical entrypointを実行し、現行validator契約と異なる結果を得るため。
- **Change freedom**: 将来のreleaseでも、exact replacement、参照元なし、owner authorityを確認できたobsolete fileは同じ手順で削除できる。

## Consequences / Impact

- canonical workflow は `.ts` へ移り、置換済みの旧 `.mjs` と旧fixtureはowner authorizationに基づき削除する。
- compatibility migration と strict schema migration は別 verdict になる。
- application runtime と product records は migration diff の対象外として保護する。

## Quality Implications

- inventory の missing / unresolved path は compatibility PASS を妨げる。
- branch mixing、blind replacement、premature lock、bulk schema edit、無許可 deletion を agent misbehavior failure とする。
- paired skills、hook configs、validators、CI callers が同じ canonical TypeScript bundle を指す必要がある。
- 削除対象は現行callerから参照されず、削除後のvalidator / hook / lintがPASSする必要がある。

## Intent-derived Invariants

- INV-001 (from DEC-004): `docs-template.lock.json` は project に実際に統合済みの exact release tag と full SHA だけを指す。

## Enforced in (optional)

- DEC-001〜DEC-003: `_docs/qa/Workflow/docs-template-v1-2-migration/inventory.tsv`
- INV-001: `docs-template.lock.json` と closure provenance check。

## Rollback / Follow-ups

- migration diff を採用しない、または後続 commit を revert する。data rollback は不要。
- strict schema migration は必要なら別 task で扱う。置換済みlegacy filesの削除authorityは2026-07-28にownerから得た。
