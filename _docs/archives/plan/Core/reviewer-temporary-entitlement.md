---
title: Reviewer Temporary Entitlement
status: proposed
draft_status: n/a
created_at: "2026-05-10"
updated_at: "2026-05-10"
references:
  - TODO.md
  - _docs/archives/plan/Core/revenuecat-supabase-entitlement-sync.md
  - _docs/archives/plan/Core/revenuecat-purchase-flow.md
  - _docs/standards/privacy-policy.md
related_issues: []
related_prs: []
---

## Overview

Google Play / App Store のレビュワーや、事前に指定された検証用アカウントが、ストア購読を実際に完了しなくても Pro 機能を確認できるようにする。

Medo は Google OAuth により Supabase Auth user を作成し、Pro 判定は Supabase `user_pro_entitlements` を source of truth とする。RevenueCat の granted entitlement は、すでに RevenueCat customer / App User ID が存在するユーザーには有効だが、初回ログイン前のメールアドレスだけを使った事前付与には向かない。

この plan では、メールアドレス allowlist を Supabase 側に持ち、ユーザーが Google OAuth で初回ログインした直後に、期限付きの temporary entitlement を `user_pro_entitlements` へ upsert する。アプリ側の Pro gate は既存の `effectiveIsProProvider` を引き続き参照し、reviewer 専用 bypass を直接 UI や provider に埋め込まない。

## Scope

- Supabase に reviewer / support 用の temporary entitlement allowlist を追加する
- allowlist はメールアドレス、期限、用途メモ、作成日時、無効化日時を保持する
- authenticated Edge Function または RPC で、現在ログイン中の Supabase user のメールアドレスを allowlist と照合する
- 一致し、期限内で、無効化されていない場合だけ `user_pro_entitlements` に `is_pro = true` / `status = temporary` を upsert する
- ログイン後またはアプリ起動時に temporary entitlement sync を呼び、完了後に `currentProEntitlementProvider` を invalidate する
- 期限切れや allowlist 無効化時に、temporary entitlement が Pro として残り続けないようにする
- README または guide に、reviewer account の登録、審査提出時の説明、削除/無効化手順を記載する

## Non-Goals

- RevenueCat の購入フロー、Offering、Product、Entitlement 設定の変更
- Google Play / App Store 側の購読キャンセル代行
- アプリ内にレビュワーメールアドレスを直書きする bypass
- debug / profile 専用の Pro override
- 永続的な無料 Pro アカウント管理機能
- 一般ユーザー向けの coupon / promo code 機能
- `pro_entitlement_events` を authenticated client へ公開すること

## Requirements

- **Functional**: 管理者はレビュワーのメールアドレスを事前に allowlist へ登録できる。
- **Functional**: Google OAuth 後に確定した Supabase user email が allowlist と一致すれば、temporary Pro entitlement が作成される。
- **Functional**: temporary entitlement の期限は `expires_at` として保存され、期限切れ後は Pro 判定として扱われない。
- **Functional**: allowlist が無効化された場合、該当 reviewer の temporary entitlement は次回 sync で inactive に戻せる。
- **Functional**: 既存の paid / webhook 由来 Pro entitlement を、reviewer temporary sync が不用意に弱めない。
- **Non-Functional**: Pro 判定の最終 source of truth は引き続き `user_pro_entitlements` とする。
- **Non-Functional**: service role key は Edge Function / RPC など server-side 境界に閉じ込める。
- **Non-Functional**: allowlist には審査・サポートに必要な最小限のメールアドレスと運用メモだけを保存する。
- **Non-Functional**: レビュー用途であること、期限、削除手順が運用ドキュメントから追える。

## Data Model

### `reviewer_entitlement_allowlist`

`auth.users` が作成される前に管理できるよう、主キーは Supabase user id ではなく normalized email とする。

```sql
create table public.reviewer_entitlement_allowlist (
  email text primary key,
  entitlement_id text not null default 'pro',
  expires_at timestamptz not null,
  note text,
  disabled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

方針:

- `email` は lower-case / trim 済みの値で保存する
- `disabled_at is null` かつ `expires_at > now()` の行だけ有効とする
- 初期実装では dashboard / SQL で管理し、アプリ内管理 UI は作らない
- authenticated client から allowlist を直接 select できないようにする

### `user_pro_entitlements`

temporary access は既存の `user_pro_entitlements` を使う。

- `is_pro = true`
- `status = 'temporary'`
- `product_id = null` または `reviewer_temporary`
- `expires_at = reviewer_entitlement_allowlist.expires_at`
- `last_synced_at = now()`

既存 row が `active` / `trial` / `grace_period` / `cancelled_but_active` など RevenueCat 由来の有効状態である場合、reviewer sync はその状態を inactive にしない。temporary row だけを作成・更新・期限切れ処理の対象にする。

## Server Flow

1. アプリはログイン後、authenticated Edge Function `sync-reviewer-entitlement` を呼ぶ。
2. function は JWT から current user を取得し、`user.id` と `user.email` を確認する。
3. email を normalize し、`reviewer_entitlement_allowlist` を service role で検索する。
4. 有効な allowlist がなければ、既存 `user_pro_entitlements.status = temporary` かつ期限切れ/無効化対象の row だけ inactive に戻す。
5. 有効な allowlist があれば、`user_pro_entitlements` を temporary Pro として upsert する。
6. function は `{ ok: true, applied: boolean }` を返す。
7. アプリは response の成否にかかわらず `currentProEntitlementProvider` を invalidate し、最終判定は通常の read-only provider に任せる。

## App Flow

- `AuthNotifier` または起動時の auth listener から、ログイン成功後に sync を呼ぶ。
- sync 失敗はログイン失敗として扱わない。通常の Free / paid entitlement 判定へフォールバックする。
- Paywall や Settings に reviewer 専用表示は追加しない。
- `status = temporary` を表示する必要が出た場合でも、既存の Pro 状態表示に小さく収め、審査用の内部実装を前面に出さない。

## Security / Privacy

- allowlist は service role だけが読み書きできる。
- authenticated user は自分の email が allowlist にあるかどうかを直接列挙できない。
- function は current user の email だけを照合し、任意 email を request body から受け取らない。
- expires_at を必須にし、期限なしの reviewer access を作らない。
- 運用メモには個人情報や審査担当者名を過剰に書かない。

## Tasks

1. `reviewer_entitlement_allowlist` migration を追加し、RLS / grant を service role 専用にする。
2. authenticated Edge Function `sync-reviewer-entitlement` を追加する。
3. function で current user email を normalize し、有効な allowlist に一致する場合だけ temporary entitlement を upsert する。
4. temporary entitlement の期限切れ / allowlist 無効化時の inactive 戻しを実装する。
5. Flutter 側からログイン後に function を呼び、`currentProEntitlementProvider` を invalidate する。
6. SQL / Edge Function / provider のテストを追加する。
7. README または guide に、reviewer email 登録、審査提出時の App access 記載、期限切れ/無効化手順を反映する。

## Test Plan

- SQL / schema
  - allowlist table が authenticated client から直接読めない
  - `expires_at` が必須である
  - service role では insert / update / disable できる

- Edge Function
  - 未ログイン request は 401
  - current user に email がない場合は no-op
  - allowlist にない email は no-op
  - allowlist にあり期限内なら temporary entitlement が upsert される
  - allowlist が期限切れなら Pro が付与されない
  - `disabled_at` がある allowlist は Pro が付与されない
  - 既存 paid entitlement は temporary sync で上書きされない

- Flutter
  - Google OAuth 後に sync function が呼ばれる
  - sync 成功後に `currentProEntitlementProvider` が再読込される
  - sync 失敗時でもログイン状態と通常の Free fallback が壊れない

- Manual
  - レビュワー用メールを allowlist に登録する
  - そのメールで Google OAuth ログインする
  - Supabase `user_pro_entitlements.status = temporary` / `is_pro = true` を確認する
  - Pro gate が開くことを確認する
  - allowlist を disable または期限切れにし、次回 sync 後に Pro が残り続けないことを確認する

## Deployment / Rollout

1. migration を staging / production Supabase project へ適用する。
2. `sync-reviewer-entitlement` Edge Function を deploy する。
3. レビュワー用メールと期限を allowlist に登録する。
4. Google Play Console / App Store Connect の review notes に、ログイン方法、Pro 機能への到達手順、レビュー用アカウントの説明を記載する。
5. 審査完了後、allowlist の `disabled_at` を設定するか、期限切れを確認する。

Rollback:

- function 呼び出しをアプリ側で無効化しても、通常の RevenueCat / Supabase entitlement flow は維持される。
- allowlist を空または disabled にすれば、新規 temporary entitlement は付与されない。
- 誤付与があった場合は、該当 `user_pro_entitlements` row が temporary であることを確認して inactive に戻す。
