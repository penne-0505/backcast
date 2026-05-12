---
title: Billing Logout State Boundary
status: active
draft_status: n/a
created_at: "2026-05-12"
updated_at: "2026-05-12"
references:
  - README.md
  - _docs/intent/medo/pro_free_gate.md
  - _docs/intent/medo/revenuecat_purchase_flow.md
  - _docs/intent/medo/revenuecat_supabase_entitlement_sync.md
related_issues: []
related_prs: []
---

## Context

Medo の Pro 判定は、Supabase の `user_pro_entitlements` を最終的な source of truth としつつ、RevenueCat の購入導線と Drift の `cached_pro_entitlements` snapshot を併用します。
この構成では、ログアウト時に「現在の Supabase user」「RevenueCat customer」「ローカルの暫定 Pro snapshot」「UI が保持している billing state」が同時に境界をまたぐため、古い Pro 状態が UI/action gate に残らないことを明示する必要があります。

特に Drift cache は UI 崩れや起動直後のちらつきを防ぐために意図的に信頼する snapshot です。
そのため、cache を持つこと自体ではなく、未ログイン状態や別ユーザー状態でその snapshot を読ませないことが重要です。

## Decision

- ログアウト後の Pro gate は `currentUserIdProvider == null` を境界として Free 相当へ戻す
- `effectiveProAccessProvider` は未ログイン状態で user-scoped Drift cache を読まない
- `billingProvider` は未ログイン状態で RevenueCat `CustomerInfo` を読まず、空の `BillingState` を返す
- ログアウト時は `currentProEntitlementProvider` だけでなく、`billingProvider`、`subscriptionManagementUrlProvider`、`proPackageProvider` も invalidate して再評価する
- Paywall の商品表示は未ログインでも許可するが、`purchasePackage` と `restorePurchases` は Supabase login 後の user id があり、RevenueCat identity が同じ user id へ同期済みの場合だけ実行する
- `cached_pro_entitlements` は user id を主キーにした snapshot として残し、ログアウトだけでは削除しない

## Alternatives

- ログアウト時に Drift の `cached_pro_entitlements` を削除する案は、再ログイン時の UX fallback を失い、同一ユーザーの起動直後表示を不安定にするため不採用
- RevenueCat の `BillingState.isPro` を Pro gate の source of truth にする案は、Supabase entitlement と reviewer temporary entitlement を同じ境界で扱えなくなるため不採用
- ログアウト時に `Purchases.logOut()` だけを呼び、Riverpod provider の再評価を暗黙の依存に任せる案は、将来 `billingProvider` を直接参照する UI が増えたときに古い Pro 状態を拾う余地があるため不採用

## Rationale

ログアウトは単なる画面表示の切り替えではなく、ユーザー単位で信頼してよい状態の境界です。
Pro entitlement は課金・権限・ユーザーデータ保護に関わるため、Supabase user id がない状態では、RevenueCat customer state や Drift snapshot を Pro 判定として使わない方針にします。

一方で、Drift cache は「問い合わせ完了までの暫定判定」という役割を持つため、ログアウトのたびに破棄すると本来の目的を失います。
cache は保持し、読み取り条件を user id に閉じることで、UX と安全性を両立します。

## Consequences / Impact

- ログアウト直後は billing state と subscription management URL が再評価され、古い Pro customer 情報を UI が参照しにくくなる
- Pro / Free の action gate は引き続き `effectiveProAccessProvider` を優先して参照する
- Paywall は未ログインでも価格・期間を表示できるが、購入・復元 action はログイン案内に留まり、ログイン直後の RevenueCat identity 同期中も購入・復元を開始しない
- 同一ユーザーが再ログインした場合、Supabase 再問い合わせ中は user-scoped Drift cache を暫定 snapshot として使える
- 別ユーザーでログインした場合、前ユーザーの cache は user id が一致しないため Pro 判定に使われない

## Rollback / Follow-ups

- ログアウト後に Pro 導線が残る場合は、該当 UI が `billingProvider.isPro` や RevenueCat `CustomerInfo` を直接 gate に使っていないか確認する
- 新しい Pro 機能を追加するときは、表示だけでなく mutation/action 境界でも `effectiveProAccessProvider` を使う
- 将来アカウント切り替え UX を明示的に持つ場合は、ログアウト、別ユーザーログイン、RevenueCat identity sync、Drift cache read の順序を widget/provider test で固定する
