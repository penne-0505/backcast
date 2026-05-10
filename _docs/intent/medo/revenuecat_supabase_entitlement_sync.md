---
title: RevenueCat Supabase Entitlement Sync
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - README.md
  - _docs/archives/plan/Core/revenuecat-supabase-entitlement-sync.md
  - _docs/standards/privacy-policy.md
  - _docs/intent/medo/pro_free_gate.md
related_issues: []
related_prs: []
---

## Context

Medo はタイムライン本体を端末内に保持し、Supabase には Auth と Pro entitlement の現在状態だけを置く方針です。
RevenueCat webhook 由来のイベントは監査ログとして残し、Flutter client からは現在の Pro 状態だけを read-only で取得します。

## Decision

- Flutter app は anon / publishable key だけを使い、
  `user_pro_entitlements` を select する
- `pro_entitlement_events` は service role 処理専用の監査ログとする
- RevenueCat webhook Edge Function が event を検証し、entitlement の
  現在状態を upsert / update する
- Supabase Auth user 削除時は entitlement と event log を cascade delete する
- アプリ作成コンテンツは Supabase に同期しない

## Alternatives

- Flutter client が RevenueCat customer state を直接 Pro 判定に使う案は、
  server-side entitlement と監査ログを一元化できないため不採用
- タイムラインを Supabase に同期する案は、今回の課金状態同期の範囲を超えるため不採用

## Rationale

Pro gate の source of truth を Supabase に置くと、RevenueCat webhook、
temporary entitlement、将来の support 操作を同じ読み取り境界に集約できます。
一方で、ユーザー作成コンテンツをクラウド同期しないことで、課金状態同期の blast radius を抑えられます。

## Consequences / Impact

- service role key は Edge Function 側に閉じる
- RLS と grant は `user_pro_entitlements` の本人 select と service-only event log を分ける
- 実 Supabase project 上の RLS / webhook replay / sandbox purchase 検証は運用上の確認として残る

## Rollback / Follow-ups

- webhook 障害時は RevenueCat dashboard と Supabase event log を突き合わせて再送する
- entitlement の現在状態が不整合になった場合は service role 側で再計算または補正する
