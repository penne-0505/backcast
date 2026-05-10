---
title: RevenueCat Purchase Flow
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - README.md
  - _docs/archives/plan/Core/revenuecat-purchase-flow.md
  - _docs/intent/medo/revenuecat_supabase_entitlement_sync.md
  - _docs/intent/medo/pro_free_gate.md
related_issues: []
related_prs: []
---

## Context

Paywall は restore 導線だけでは、closed testing のテスターがアプリ内から sandbox purchase を開始できません。
RevenueCat の offering / package を取得し、購入成功後に RevenueCat と Supabase entitlement を再読込する導線が必要でした。

## Decision

- Paywall は RevenueCat の `current` offering から Pro package を取得して価格・期間を表示する
- 購入ボタンは `Purchases.purchasePackage(...)` を呼び出す
- loading、商品未設定、キャンセル、失敗、成功後の確認中を区別する
- purchase と restore のどちらでも CustomerInfo と Supabase entitlement
  provider を refresh する
- Web / Linux / Windows など RevenueCat SDK 非対応 platform は Free fallback とする

## Alternatives

- 外部ストアページへ誘導するだけの案は、アプリ内課金の closed testing 導線を再現できないため不採用
- 購入成功直後に即 Pro とみなす案は、Supabase entitlement を source of truth とする設計とずれるため不採用

## Rationale

購入直後には RevenueCat webhook から Supabase へ反映されるまでの遅延があり得ます。
そのため UI は「購入処理が成功したこと」と「Pro gate が開いたこと」を分けて扱う必要があります。

## Consequences / Impact

- Paywall は商品情報取得と購入処理の非同期 state を持つ
- closed testing では Play Store install、sandbox purchase、RevenueCat
  dashboard、Supabase entitlement、アプリ内 Pro gate を順に確認する
- 最終的な Pro 判定は Supabase の `user_pro_entitlements` に残る

## Rollback / Follow-ups

- 商品未設定時は購入ボタンを無効化し、restore 導線を残す
- iOS の RevenueCat API key と sandbox 検証は別途 platform task として扱う
