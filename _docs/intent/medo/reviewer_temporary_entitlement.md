---
title: Reviewer Temporary Entitlement
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - README.md
  - _docs/archives/plan/Core/reviewer-temporary-entitlement.md
  - _docs/intent/medo/revenuecat_supabase_entitlement_sync.md
related_issues: []
related_prs: []
---

## Context

ストア審査担当者や検証用アカウントには、実際の購読完了前に Pro 機能を確認できる導線が必要です。
ただし reviewer 専用 bypass を Flutter UI や provider に埋め込むと、通常の Pro 判定と分岐して保守が難しくなります。

## Decision

- Supabase に `reviewer_entitlement_allowlist` を持つ
- `sync-reviewer-entitlement` Edge Function がログイン中ユーザーの
  メールアドレスを allowlist と照合する
- 期限内かつ無効化されていない allowlist の場合だけ
  `user_pro_entitlements.status = temporary` を upsert する
- 期限切れまたは無効化済みの場合は temporary entitlement を Pro として残さない
- Flutter 側の Pro gate は通常の `currentProEntitlementProvider` /
  `effectiveIsProProvider` を使い続ける

## Alternatives

- アプリ内に reviewer メールをハードコードする案は、秘密情報と審査運用を client に持ち込むため不採用
- RevenueCat の事前付与だけに寄せる案は、初回ログイン前のメールアドレス allowlist 運用と相性が悪いため不採用

## Rationale

temporary entitlement も通常の entitlement table に集約すると、Pro gate は単一の読み取りモデルを保てます。
allowlist を service-role only にすることで、登録・無効化の運用権限を client から切り離せます。

## Consequences / Impact

- 審査提出時は allowlist 登録、期限、無効化手順を運用として管理する必要がある
- メールアドレスは小文字化・trim 済みで登録する
- temporary entitlement は審査完了後に `disabled_at` または期限切れで無効化する

## Rollback / Follow-ups

- reviewer 導線を止める場合は allowlist の `disabled_at` を設定する
- function 障害時は通常の sandbox purchase / restore 導線で Pro 判定を確認する
