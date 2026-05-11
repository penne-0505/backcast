---
title: Purchase Auth Gate
status: proposed
draft_status: n/a
created_at: "2026-05-12"
updated_at: "2026-05-12"
references:
  - README.md
  - _docs/intent/medo/revenuecat_purchase_flow.md
  - _docs/intent/medo/revenuecat_supabase_entitlement_sync.md
  - _docs/intent/medo/pro_free_gate.md
  - _docs/intent/medo/subscription_management_route.md
related_issues: []
related_prs: []
---

## Overview

未ログイン状態でも Pro 機能説明と価格確認はできるが、実際の購入 API 呼び出しは Supabase Auth user が存在する場合だけ許可する。

現状は `currentUserIdProvider == null` が `ProEntitlementState.free()` として扱われるため、設定画面、テンプレート、画像共有、buffer 編集などの Free gate から Paywall へ到達できる。Paywall 自体にも購入前の認証確認がないため、RevenueCat SDK 対応 platform では未ログインのまま `Purchases.purchasePackage(...)` に進む余地がある。

この plan では、Paywall の閲覧は許可したまま、購入実行時だけログイン必須にする。これにより、Pro 価値の説明をアカウント作成前に見せつつ、購入と RevenueCat App User ID / Supabase user id の紐付け不整合を防ぐ。

## Scope

- `PaywallScreen` で現在の認証状態を読み、未ログイン時は購入ボタン押下で `purchaseProPackage(...)` を呼ばない。
- 未ログイン時の購入ボタン押下では、ログインが必要であることを明示し、設定画面または認証導線へ誘導する。
- Paywall の商品情報表示、Pro 機能説明、購入復元導線は維持する。
- `BillingNotifier.purchaseProPackage(...)` 側にも防御的な認証ガードを置き、UI 以外の呼び出しからも未ログイン購入を開始できないようにする。
- README または関連 intent / reference に、Paywall は閲覧可能だが購入にはログインが必要であることを反映する。
- widget / provider test で未ログイン購入が RevenueCat gateway を呼ばないことを確認する。

## Non-Goals

- Paywall 到達前にログインを必須化しない。
- 未ログイン時に Paywall の価格・商品説明を隠さない。
- ログイン完了後に元の Paywall / purchase intent へ自動復帰する導線は今回の対象外とする。
- Google OAuth / Apple OAuth の認証 UI 自体は作り替えない。
- RevenueCat offering、product、entitlement、Supabase schema、webhook の変更は行わない。
- 購入済みユーザーの購読管理画面導線は変更しない。

## Requirements

- **Functional**: 未ログインで Paywall の購入ボタンを押しても `Purchases.purchasePackage(...)` は呼ばれない。
- **Functional**: 未ログイン時は、購入にはログインが必要であることがユーザーに伝わる。
- **Functional**: ログイン済み Free ユーザーは、従来どおり Paywall から購入フローを開始できる。
- **Functional**: RevenueCat SDK 非対応 platform では、既存どおり購入不可 state を表示する。
- **Functional**: restore は既存仕様を維持する。ただし、restore も Supabase user へ entitlement を紐付ける必要があるため、未ログイン時の扱いを確認し、必要なら購入と同じ認証ガードへ揃える。
- **Non-Functional**: 購入開始前に Supabase user id と RevenueCat App User ID が同期済みであることを前提にする。
- **Non-Functional**: UI ガードだけに依存せず、billing provider 層でも未ログイン購入を拒否する。
- **Non-Functional**: 未ログインを Pro gate 上の Free として扱う既存方針は維持し、Paywall への到達可能性は残す。

## Proposed Interaction

1. ユーザーが未ログイン状態で Pro 機能 gate に触れる。
2. 既存どおり Paywall が開き、機能説明と商品情報を表示する。
3. ユーザーが「Proにアップグレード」を押す。
4. Paywall は認証状態を確認し、未ログインなら購入 API を呼ばずにログインが必要な旨を表示する。
5. ユーザーは設定画面のアカウントセクションからログインする。
6. ログイン後、RevenueCat identity listener が `Purchases.logIn(currentUserId)` を実行する。
7. ログイン済み状態で Paywall の購入ボタンを押した場合だけ、`BillingNotifier.purchaseProPackage(...)` が `Purchases.purchasePackage(...)` を呼ぶ。

## Implementation Notes

- `PaywallScreen` は `authProvider` または `isAuthenticatedProvider` を watch し、未ログインかつ purchase button tap の場合は SnackBar / inline message / 設定画面への導線のいずれかに倒す。
- 既存の設定画面にはログイン UI があるため、最小実装では Paywall から SettingsScreen へ遷移する導線を追加するのが自然。ただしナビゲーションが循環しすぎる場合は、まず SnackBar と「設定でログインしてください」の明示に留めてもよい。
- `BillingNotifier.purchaseProPackage(...)` は `currentUserIdProvider` を read し、null の場合は failed / idle 相当の recoverable state と message を返す。ここで RevenueCat gateway を呼ばないことをテストで固定する。
- `restorePurchases()` は既存では未ログインでも呼べる。RevenueCat の restore 結果を Supabase user に反映する設計と衝突する可能性があるため、実装時に purchase と同じ認証必須にするかを確認する。判断基準は「restore 後に Supabase entitlement の source of truth へ確実に紐付くか」とする。
- `currentUserIdProvider` 変更後に `Purchases.logIn(next)` が非同期で走るため、ログイン直後の購入 tap が早すぎるケースに注意する。必要なら `BillingNotifier.purchaseProPackage(...)` で `Purchases.logIn` 完了前の race を避ける追加 state を検討する。

## Tasks

1. `PaywallScreen` に認証状態の読み取りを追加し、未ログイン時の購入ボタン押下をログイン案内へ分岐する。
2. `BillingNotifier.purchaseProPackage(...)` に `currentUserIdProvider` null check を追加し、未ログインでは RevenueCat gateway を呼ばない。
3. `restorePurchases()` の未ログイン時挙動を確認し、購入と同じガードが必要なら同時に適用する。
4. 未ログイン時の UI message を、設定画面の文言と矛盾しない形に統一する。
5. `purchase_flow_test` に未ログイン購入拒否の provider test を追加する。
6. Paywall widget test または既存 widget test に、未ログイン時に購入 API へ進まずログイン案内が出るケースを追加する。
7. README の Supabase / RevenueCat 課金状態同期セクションを、Paywall 閲覧可能 / 購入ログイン必須の仕様へ更新する。

## Test Plan

- Provider test
  - `currentUserIdProvider == null` で `purchaseProPackage(...)` を呼ぶと、RevenueCat gateway の `purchasePackage` が呼ばれない。
  - ログイン済み user id がある場合は、従来どおり `purchasePackage` が呼ばれる。
  - RevenueCat SDK 非対応 platform では、未ログイン判定よりも既存の platform unavailable message が破綻しない。
- Widget test
  - 未ログイン Paywall で商品情報は表示される。
  - 未ログイン Paywall で「Proにアップグレード」を押すと、購入ではなくログイン案内が表示される。
  - ログイン済み Free 状態では、購入ボタンが既存どおり billing provider へ接続される。
- Regression
  - 設定画面 Free plan card から Paywall へ到達できる。
  - テンプレート / 画像共有 / buffer 編集 gate から Paywall へ到達できる。
  - Pro ユーザーの設定カードは Paywall ではなく購読管理導線へ進む。

## Deployment / Rollout

- アプリ側のみの変更として通常リリースに含める。
- Supabase migration、RevenueCat dashboard、Google Play Console、App Store Connect の設定変更は不要。
- closed testing では、未ログイン状態で Paywall の購入ボタンを押してもストア購入シートが出ないことを確認する。
- ログイン後に同じ Paywall から sandbox purchase を開始できることを確認する。
- 問題が出た場合は、Paywall の認証分岐と `BillingNotifier` の null check を戻せば、既存の購入フローへ戻せる。ただし未ログイン購入リスクも戻るため、rollback はストア審査や購入検証を止めた状態で行う。
