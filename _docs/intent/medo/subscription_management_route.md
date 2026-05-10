---
title: Subscription Management Route
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - README.md
  - _docs/archives/plan/Core/subscription-management-route.md
  - _docs/intent/medo/revenuecat_purchase_flow.md
related_issues: []
related_prs: []
---

## Context

Pro ユーザーが設定画面の `Proプラン利用中` カードから Paywall へ戻ると、再購入導線へ到達できてしまいます。
Pro ユーザーに必要なのは再購入ではなく、ストア側の購読管理画面へ進む導線です。

## Decision

- Free ユーザーのプランカードは従来通り Paywall へ遷移する
- Pro ユーザーのプランカードは RevenueCat `CustomerInfo.managementURL` から購読管理画面を開く
- `managementURL` がない場合や外部起動に失敗した場合は、復旧可能な案内を表示する
- RevenueCat SDK 非対応 platform では購読管理導線を無効化または説明表示に倒す

## Alternatives

- Pro でも Paywall を表示し続ける案は、再購入と購読管理の目的が混ざるため不採用
- アプリ内で解約処理を実行する案は、ストア購読の管理責務を越えるため不採用

## Rationale

購読の解約・更新停止・プラン管理は Google Play / App Store 側の操作です。
RevenueCat が返す management URL を使うことで、アプリは購読状態を確認する入口だけを提供し、実管理はストアに委ねられます。

## Consequences / Impact

- 設定画面のカード tap は Free / Pro で分岐する
- Pro 状態のユーザーには Paywall の購入ボタンではなく購読管理導線を提示する
- management URL 不在時の案内文と restore 導線が重要になる

## Rollback / Follow-ups

- URL 起動に問題がある platform では案内表示に fallback する
- ストア別の管理 URL 表示差異は closed testing / sandbox で確認する
