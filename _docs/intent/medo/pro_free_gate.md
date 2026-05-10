---
title: Pro Free Gate
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - README.md
  - _docs/archives/plan/Core/pro-free-gate.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/reference/medo/persistence_repository_reference.md
related_issues: []
related_prs: []
---

## Context

Medo では、基本編集を Free で成立させつつ、複数タイムライン、テンプレート、画像共有、buffer 編集を Pro 価値として扱う必要がありました。
課金状態は UI の表示分岐だけでなく、作成・適用・共有などの action 境界でも一貫して参照する必要があります。

## Decision

- Pro 判定は `effectiveIsProProvider` を UI/action 境界の source of truth として使う
- Free はタイムライン 2 件まで作成・利用できる
- Pro はタイムライン数、テンプレート作成・適用、画像共有、buffer 編集を利用できる
- Pro から Free へ戻っても作成済みデータは削除しない
- Free で制限に当たった場合は、対象機能の文脈を持つ Paywall へ遷移する

## Alternatives

- 各 UI に個別の判定を埋め込む案は、課金境界が散らばり保守しづらいため不採用
- Free へ戻った時点で超過データを削除する案は、ユーザー作成データを壊すため不採用

## Rationale

Pro gate は売上上の境界であると同時に、ユーザーデータ保護の境界でもあります。
編集できる範囲を縮退させても、保存済みの計画やテンプレートは保持する方針にすると、解約や一時的な entitlement 不整合に耐えやすくなります。

## Consequences / Impact

- Paywall は機能文脈ごとの説明を持つ
- persistence 層は Free/Pro にかかわらず作成済みデータを保持する
- action 境界での gate 漏れが UX と課金仕様の両方に影響する

## Rollback / Follow-ups

- RevenueCat / Supabase の Pro 判定に障害がある場合は Free fallback として扱う
- 将来 Pro 機能が増える場合も、データ削除ではなく利用導線の縮退を優先する
