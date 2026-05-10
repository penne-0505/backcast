---
title: Subscription Management Route
status: proposed
draft_status: n/a
created_at: "2026-05-10"
updated_at: "2026-05-10"
references:
  - TODO.md
  - _docs/archives/plan/Core/revenuecat-purchase-flow.md
  - _docs/archives/plan/Core/revenuecat-supabase-entitlement-sync.md
related_issues: []
related_prs: []
---

## Overview

設定画面のサブスクリプションセクションで、Pro ユーザーが `Proプラン利用中` カードを押すと Paywall に遷移し、`Proにアップグレード` ボタンへ到達できてしまう問題を修正する。

現状の Paywall は Free ユーザーの購入導線として成立している。一方で、Pro ユーザーにとって必要なのは再購入ではなく、現在の購読状態を確認し、必要に応じて Google Play / App Store の購読管理画面で解約・更新停止・プラン管理を行う導線である。

この plan では、Free ユーザーは従来通り Paywall へ遷移し、Pro ユーザーは RevenueCat `CustomerInfo.managementURL` を使ってストア側の購読管理画面を開く分岐を追加する。

## Scope

- `RevenueCatGateway` に購読管理 URL を取得できる境界を追加する。
- Pro 状態の設定カード押下時は Paywall ではなく購読管理導線へ分岐する。
- Free 状態の設定カード押下時は従来通り Paywall へ遷移する。
- `managementURL` が取得できない場合の復旧可能な UI state を用意する。
- RevenueCat SDK 非対応 platform では購読管理導線を無効化または説明表示に倒す。
- 設定画面または課金 state に、処理中・失敗・URL 未取得の状態を表示する。
- 実装後、README または guide/reference に Pro ユーザーの購読管理導線を反映する。

## Non-Goals

- アプリがユーザーの代わりにストア購読をキャンセルすること。
- Google Play Developer API による backend cancellation の追加。
- 返金、revocation、support 向け手動解約処理。
- RevenueCat dashboard / Google Play Console / App Store Connect の商品設定変更。
- Paywall の新規購入 UI の再設計。
- アカウント削除フローの再設計。
- iOS / App Store の本番購読検証。

## Requirements

- **Functional**: Free ユーザーが設定のプランカードを押すと、既存通り Paywall に遷移する。
- **Functional**: Pro ユーザーが設定のプランカードを押すと、`Purchases.getCustomerInfo()` 由来の `managementURL` を開く。
- **Functional**: `managementURL` が `null` の場合、購入復元またはストア管理画面を確認する説明を表示し、Paywall の購入ボタンへ誘導しない。
- **Functional**: 購読管理 URL を開けない場合、復旧可能なエラーとして設定画面に表示する。
- **Functional**: 設定画面の `購入を復元` 導線は維持する。
- **Non-Functional**: Pro gate の source of truth は引き続き Supabase `user_pro_entitlements` / `effectiveIsProProvider` とする。
- **Non-Functional**: アプリ内に RevenueCat secret API key や Google Play Developer API credential を入れない。
- **Non-Functional**: ストア購読の解約はユーザー操作として扱い、アプリ側で代行しない。
- **Non-Functional**: Google Play の購読キャンセル要件に対して、アプリ内から購読管理画面へ到達できる状態を維持する。

## Interaction Model

1. 設定画面のサブスクリプションセクションで `effectiveIsProProvider` を読む。
2. Free の場合:
   - `ProStatusCard` は `Freeプラン` / `タップしてPro機能を確認` を表示する。
   - tap で既存の `PaywallScreen(feature: PaywallFeature.timelineCount)` へ遷移する。
3. Pro の場合:
   - `ProStatusCard` は `Proプラン利用中` を表示する。
   - 補足文は `購読を管理` または `ストアで購読を管理` に変える。
   - tap で RevenueCat の `managementURL` を取得し、外部 URL として開く。
4. URL 取得中は多重 tap を抑止する。
5. URL が取得できない場合は、購入復元を試すか Google Play / App Store のサブスクリプション管理を確認する短い説明を表示する。

## Implementation Notes

- `CustomerInfo.managementURL` は RevenueCat SDK が購入元 store に応じて返す購読管理 URL として扱う。
- `url_launcher` など外部 URL を開く dependency が未導入の場合は、最小限の追加で `launchUrl(..., mode: LaunchMode.externalApplication)` を使う。
- `BillingNotifier` に購読管理 URL open まで含めると UI dependency が混ざるため、URL 取得は billing provider 側、URL open は settings UI 側に置く方が境界が明確になる。
- `effectiveIsProProvider` は Supabase entitlement の最終判定であり、RevenueCat `CustomerInfo` とは短時間ずれる可能性がある。Pro UI から管理 URL が取れない場合に購入導線へ戻すのではなく、復元・ストア確認の案内に倒す。

## Tasks

1. `RevenueCatGateway` に `getCustomerInfo()` から `managementURL` を取得する provider / method を追加する。
2. 必要であれば `url_launcher` を依存に追加し、Android / iOS / macOS の外部 URL 起動を確認する。
3. 設定画面の `ProStatusCard` tap handler を Free / Pro で分岐する。
4. Pro 分岐では management URL を開き、loading / failure / unavailable state を表示する。
5. Paywall は Free ユーザー専用の購入導線として残し、Pro ユーザーの設定カードからは到達しないようにする。
6. provider / widget test で Free は Paywall、Pro は購読管理取得へ進むことを確認する。
7. README または guide/reference に、Pro ユーザーの購読管理導線と、解約はストア側で行うことを反映する。

## Test Plan

- Unit / provider test
  - RevenueCat SDK 対応 platform で `managementURL` を取得できる。
  - RevenueCat SDK 非対応 platform では unavailable として扱う。
  - `managementURL == null` の場合、購入 flow ではなく unavailable state になる。

- Widget test
  - Free 状態で設定のプランカードを tap すると `PaywallScreen` が開く。
  - Pro 状態で設定のプランカードを tap しても `PaywallScreen` が開かない。
  - Pro 状態で URL 取得中は多重 tap できない。
  - Pro 状態で URL 未取得時に復旧可能な説明が表示される。
  - `購入を復元` ボタンは既存通り表示される。

- Manual test
  - Android closed testing / sandbox purchase 済み account で設定画面を開く。
  - `Proプラン利用中` カードを押すと Play Store の購読管理画面へ遷移する。
  - 戻る操作後、アプリの Pro gate が壊れていないことを確認する。
  - Free account では同じカードから Paywall へ遷移する。

## Deployment / Rollout

1. 開発 build で Free / Pro の分岐を確認する。
2. closed testing build に含め、sandbox purchase 済み account で購読管理画面への遷移を確認する。
3. Play Console の審査メモやサポート文面が「アプリ内から購読管理へ到達可能」という事実と矛盾しないか確認する。

Rollback:

- management URL 起動に platform 固有の問題がある場合は、Pro 状態のカードから Paywall へ戻さず、購読管理の説明と `購入を復元` のみを残す。
- URL 起動 dependency に問題がある場合は、実装を feature flag 相当の条件で無効化し、ドキュメント上の手動管理案内を維持する。
