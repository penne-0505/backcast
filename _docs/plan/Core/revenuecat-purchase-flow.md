---
title: RevenueCat Purchase Flow
status: proposed
draft_status: n/a
created_at: "2026-05-09"
updated_at: "2026-05-09"
references:
  - TODO.md
  - _docs/plan/Core/revenuecat-supabase-entitlement-sync.md
  - _docs/plan/Core/pro-free-gate.md
related_issues: []
related_prs: []
---

## Overview

Medo の Paywall に RevenueCat の新規購入導線を接続する。

現状は RevenueCat SDK の初期化、ログイン時の `Purchases.logIn(...)`、CustomerInfo listener、restore、Supabase entitlement read-only provider は存在する。一方で、Paywall には新規購入を開始する UI と `Purchases.purchasePackage(...)` の呼び出しがない。そのため、Google Play closed testing のテスターは、設定が整っていてもアプリ内から sandbox purchase に入れない。

この plan では、closed testing の本流である「Play Store からインストール → ログイン → Paywall からテスト購入 → RevenueCat webhook → Supabase entitlement → Pro gate 解放」を再現可能にする。

## Scope

- RevenueCat offerings を取得する provider / notifier / repository 相当の境界を追加する。
- Paywall に Pro package の価格・期間・購入ボタンを表示する。
- Paywall から `Purchases.purchasePackage(...)` を呼び出す。
- 購入キャンセル、購入失敗、商品未設定、loading、購入成功を区別して UI state として扱う。
- 購入成功後に RevenueCat CustomerInfo と Supabase entitlement provider を再読込する。
- webhook 反映に短い遅延がある前提で、購入直後の「確認中」状態または再読込導線を用意する。
- 既存の restore 導線は維持し、purchase / restore のどちらでも entitlement refresh が走るようにする。
- Android closed testing / sandbox purchase で手動検証できる状態にする。
- 実装後、README または guide/reference に課金導線の現在仕様を反映する。

## Non-Goals

- Google Play Console の商品作成、価格設定、closed testing track 設定。
- RevenueCat dashboard の product / offering / entitlement 設定そのもの。
- iOS / App Store の購入導線検証。
- Web の RevenueCat stub / Free fallback。
- debug/profile 限定の Pro override。
- Supabase entitlement schema / webhook / account deletion の再設計。
- 購入履歴 UI。
- ストア購読のキャンセル代行。

## Requirements

- **Functional**: Paywall は RevenueCat offering から購入可能な Pro package を取得できる。
- **Functional**: Pro package が取得できた場合、価格と購入ボタンを表示できる。
- **Functional**: Pro package が取得できない場合、購入ボタンを無効化し、設定未完了として扱える。
- **Functional**: 購入ボタン押下で `Purchases.purchasePackage(...)` を実行できる。
- **Functional**: ユーザーキャンセルはエラー扱いで gate を壊さず、Paywall に戻れる。
- **Functional**: 購入失敗は復旧可能なエラーとして表示し、再試行できる。
- **Functional**: 購入成功後、RevenueCat CustomerInfo listener または明示 refresh により billing state を更新できる。
- **Functional**: 購入成功後、`currentProEntitlementProvider` を invalidate し、Supabase 上の server entitlement を再読込できる。
- **Functional**: restore でも purchase と同じ entitlement refresh 境界を通る。
- **Non-Functional**: Pro gate の最終判定は引き続き `effectiveIsProProvider` / Supabase entitlement を source of truth とする。
- **Non-Functional**: Flutter app に service role key や RevenueCat secret API key を入れない。
- **Non-Functional**: closed testing のテスターが同じ手順で再現できる導線にする。

## Purchase Flow

1. Paywall 起動時に RevenueCat offerings を取得する。
2. `current` offering から Pro 用 package を選ぶ。初期実装では RevenueCat dashboard の current offering に Pro package が1つある前提でよい。
3. package がない場合は、購入ボタンを無効化し、restore は残す。
4. package がある場合は、価格・期間・説明を Paywall に表示する。
5. 購入ボタン押下で `Purchases.purchasePackage(package)` を呼ぶ。
6. `PlatformException` または RevenueCat の cancellation signal を見て、ユーザーキャンセルと失敗を分ける。
7. 成功時は返却された CustomerInfo を billing state に反映するか、`Purchases.getCustomerInfo()` を再取得する。
8. 成功時に `currentProEntitlementProvider` を invalidate する。
9. Supabase webhook 反映待ちの間は、即時に Pro gate が開かない可能性を許容し、確認中表示または短い再読込導線を出す。
10. server entitlement が `is_pro = true` になったら Pro gate が開く。

## Tasks

1. `billingProvider` または専用 provider に offerings / package 取得 state を追加する。
2. `BillingNotifier` に purchase method を追加し、CustomerInfo 更新と entitlement provider invalidation を共通化する。
3. Paywall に package loading / unavailable / available / purchasing / purchased / error の表示状態を追加する。
4. Paywall の主ボタンを restore だけでなく purchase に接続する。
5. restore ボタンを維持し、purchase と restore の refresh 境界を揃える。
6. cancellation と failure の扱いを分ける。
7. widget test で package unavailable、purchase success、purchase cancel/error の主要 state を確認する。
8. Android closed testing build で sandbox purchase を実行し、RevenueCat dashboard、Supabase `user_pro_entitlements`、アプリの Pro gate を確認する。
9. README または guide/reference に、closed testing での課金確認導線と制約を反映する。

## Test Plan

- Unit / provider test
  - offering 取得成功時に Pro package が選ばれる
  - offering なし / package なしで unavailable state になる
  - purchase success 後に CustomerInfo refresh と entitlement invalidation が走る
  - restore success 後に entitlement invalidation が走る
  - user cancellation は recoverable state として扱われる
  - purchase failure は error state として再試行可能になる

- Widget test
  - Paywall loading 中は購入ボタンが押せない
  - package available 時に価格と購入ボタンが表示される
  - package unavailable 時に設定未完了表示と restore 導線が残る
  - purchase 中は多重 tap が抑止される
  - purchase success 後に確認中または完了表示へ遷移する
  - restore 導線が既存通り残る

- Manual test
  - Android closed testing の opt-in 経由で Play Store からインストールする
  - Supabase login 後に RevenueCat app user id が Supabase user UUID へ寄る
  - Paywall から Google Play sandbox purchase を開始できる
  - purchase 後に RevenueCat dashboard の customer / entitlement が更新される
  - RevenueCat webhook から Supabase `user_pro_entitlements` が `is_pro = true` になる
  - アプリの Pro gate が開く
  - restore でも同じ Pro gate が開く

## Deployment / Rollout

1. Google Play Console と RevenueCat dashboard 側で Pro product / offering / entitlement を整える。
2. closed testing track の build に purchase flow 実装を含める。
3. 自分の license tester account で sandbox purchase を通す。
4. RevenueCat dashboard と Supabase の entitlement row を確認する。
5. 12人テスター向け手順書に、購入開始、restore、失敗時の報告項目を記載する。

Rollback:

- purchase flow に問題がある場合は Paywall の購入ボタンを feature flag 相当の条件で非表示または disabled にし、既存の restore と Free fallback を残す。
- Supabase entitlement provider failure 時は既存方針通り Free 相当に倒す。
