---
title: RevenueCat Supabase Entitlement Sync
status: active
draft_status: n/a
created_at: "2026-05-09"
updated_at: "2026-05-09"
references:
  - TODO.md
  - _docs/standards/privacy-policy.md
  - _docs/archives/plan/Core/pro-free-gate.md
  - https://supabase.com/docs/guides/api/securing-your-api
  - https://supabase.com/docs/guides/database/postgres/row-level-security
  - https://supabase.com/docs/guides/functions
  - https://supabase.com/docs/guides/functions/secrets
  - https://www.revenuecat.com/docs/integrations/webhooks
  - https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields
  - https://www.revenuecat.com/docs/api-v1
  - https://support.google.com/googleplay/android-developer/answer/13327111
related_issues: []
related_prs: []
---

## Overview

Medo の Supabase 利用範囲を、Supabase Auth と Pro entitlement の現在状態確認に限定する。

アプリ内のタイムライン、テンプレート、履歴などのユーザー作成コンテンツは引き続き端末内の Drift / SQLite に保存し、Supabase へ同期しない。Supabase Postgres には、有料プラン利用可否の現在状態と、RevenueCat webhook 由来の監査ログだけを保持する。

この plan の中心判断は次の通り。

- Flutter アプリは anon key / publishable key のみを使い、`user_pro_entitlements` を select する
- Flutter アプリは `pro_entitlement_events` を読まない、書かない
- RevenueCat webhook / Edge Function / サーバー処理だけが service role key を使う
- service role 処理は `pro_entitlement_events` に insert し、`user_pro_entitlements` を upsert / update する
- `pro_entitlement_events` は authenticated client に grant しない
- `pro_entitlement_events.user_id` は `auth.users(id) on delete cascade` とし、アカウント削除時に Supabase 上の課金履歴識別子を残さない

## Decision

### Source of Truth

`user_pro_entitlements` を Flutter アプリから見た Pro 判定の server-side source of truth とする。

RevenueCat SDK は購入、復元、CustomerInfo 更新通知のために引き続き利用する。ただし、アプリ内 gate が最終的に参照するクラウド状態は `user_pro_entitlements` とし、RevenueCat webhook / subscriber sync がこのテーブルを更新する。

### Privacy Boundary

`pro_entitlement_events` は監査・webhook 冪等化・障害調査のための service-side log とする。次のような識別子系フィールドを含むため、本人であっても authenticated client には直接公開しない。

- `transaction_id`
- `original_transaction_id`
- `original_app_user_id`
- `related_app_user_ids`
- `revenuecat_app_user_id`

初期ローンチでは、購入履歴 UI は実装しない。将来アプリ内に購入履歴を表示する場合は、`pro_entitlement_events` を直接公開せず、transaction 系 ID と RevenueCat alias 系 ID を除外した sanitized view または server API を別途設計する。

### Account Deletion

`user_pro_entitlements.user_id` と `pro_entitlement_events.user_id` はどちらも `auth.users(id) on delete cascade` とする。

Medo の privacy policy は、アカウント削除時に Supabase 上のメールアドレスと課金状態を削除すると説明している。初期ローンチでは、Supabase 側に transaction 系 ID や RevenueCat app user ID をアカウント削除後も保持する明確な理由を置かない。

## Scope

- Supabase SQL schema を新規前提で作成する
- `user_pro_entitlements` の RLS / grant / policy を作成する
- `pro_entitlement_events` を service role 専用にする
- RevenueCat webhook を受ける Supabase Edge Function script を追加する
- webhook event から Supabase `user_id` に解決できるイベントだけを `pro_entitlement_events` に保存する
- `user_id` に解決できないイベントは DB に保存せず、redacted structured log に逃がす
- webhook 受信後、可能な限り RevenueCat subscriber API から正規状態を再取得し、その結果を `user_pro_entitlements` に反映する
- Flutter 側に `user_pro_entitlements` read-only provider / repository を追加する
- 既存の `effectiveIsProProvider` が最終的に server entitlement を参照できるようにする
- アカウント削除時に Supabase 上の課金状態・課金履歴ログが cascade delete されることを検証する
- privacy policy / Google Play Data Safety / アカウント削除導線に必要な記述を同期する

## Non-Goals

- タイムライン、テンプレート、履歴、ローカル通知、カレンダー登録データのクラウド同期
- Supabase Storage の利用
- `pro_entitlement_events` の authenticated client への直接公開
- 初期ローンチでの購入履歴 UI
- transaction 系 ID をアカウント削除後も Supabase に保持する設計
- RevenueCat の商品設定、価格、Offering 文言の最終決定
- Google Play / App Store 側の購読キャンセル代行

## Architecture Boundaries

### Flutter App

- 使用できるキーは anon key / publishable key のみ
- `user_pro_entitlements` を select する
- `pro_entitlement_events` には触らない
- entitlement の insert / update / delete は行わない
- 未ログイン、読み込み中、読み込み失敗、行なしの場合は Free 相当として扱う
- RevenueCat SDK は購入・復元・CustomerInfo 更新の入口として使う
- `Purchases.logIn(currentUserId)` により RevenueCat app user ID を Supabase user UUID に寄せる

### Webhook / Edge Function / Server

- service role key または Supabase hosted Edge Function の secret key を使う
- RevenueCat webhook authorization header を検証する
- RevenueCat secret API key で subscriber 情報を再取得する
- `pro_entitlement_events` に insert する
- `user_pro_entitlements` を upsert / update する
- `pro_entitlement_events` の raw payload 全体は保存せず、必要な whitelisted fields だけを保存する
- `user_id` に解決できない event は DB に保存しない

## Schema Design

### `user_pro_entitlements`

アプリが読む現在状態テーブル。本人は自分の1行だけ select できる。

```sql
create extension if not exists pgcrypto;

create table public.user_pro_entitlements (
  user_id uuid primary key references auth.users(id) on delete cascade,

  is_pro boolean not null default false,
  status text not null default 'inactive'
    check (status in (
      'inactive',
      'active',
      'trial',
      'cancelled_but_active',
      'billing_issue',
      'grace_period',
      'temporary',
      'expired'
    )),

  revenuecat_app_user_id text,
  environment text,
  store text,
  product_id text,
  period_type text,

  purchased_at timestamptz,
  expires_at timestamptz,
  grace_period_expires_at timestamptz,

  last_revenuecat_event_id text unique,
  last_revenuecat_event_type text,
  last_event_at timestamptz,
  last_synced_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_pro_entitlements enable row level security;

revoke all on table public.user_pro_entitlements from anon, authenticated;
grant select on table public.user_pro_entitlements to authenticated;
grant select, insert, update, delete on table public.user_pro_entitlements to service_role;

create policy "Users can read own pro entitlement"
on public.user_pro_entitlements
for select
to authenticated
using ((select auth.uid()) = user_id);
```

### `pro_entitlement_events`

RevenueCat webhook 由来の service-only 監査ログ。authenticated client には公開しない。

```sql
create table public.pro_entitlement_events (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references auth.users(id) on delete cascade,

  revenuecat_event_id text not null unique,
  revenuecat_event_type text not null,

  revenuecat_app_user_id text,
  original_app_user_id text,
  related_app_user_ids text[],

  pro_after boolean not null,
  status_after text not null
    check (status_after in (
      'inactive',
      'active',
      'trial',
      'cancelled_but_active',
      'billing_issue',
      'grace_period',
      'temporary',
      'expired'
    )),

  environment text,
  store text,
  product_id text,
  entitlement_ids text[],

  transaction_id text,
  original_transaction_id text,
  period_type text,

  purchased_at timestamptz,
  expires_at timestamptz,
  grace_period_expires_at timestamptz,
  event_at timestamptz not null,
  processed_at timestamptz not null default now()
);

alter table public.pro_entitlement_events enable row level security;

revoke all on table public.pro_entitlement_events from anon, authenticated;
grant select, insert, update, delete on table public.pro_entitlement_events to service_role;

create index pro_entitlement_events_user_time_idx
  on public.pro_entitlement_events (user_id, event_at desc);

create index pro_entitlement_events_rc_app_user_idx
  on public.pro_entitlement_events (revenuecat_app_user_id);
```

### Timestamp Trigger

`updated_at default now()` は自動更新ではないため、初期 schema で trigger まで入れる。

```sql
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger user_pro_entitlements_set_updated_at
before update on public.user_pro_entitlements
for each row
execute function public.set_updated_at();
```

### Notes

- 新規前提なので既存 production data migration は扱わない
- `pro_entitlement_events` は `on delete set null` にしない
- `pro_entitlement_events` に full webhook payload は保存しない
- 未解決 event を保存する dedicated table は初期ローンチでは作らない
- 将来、監査要件で未解決 event を保存する場合も raw payload ではなく redacted fields のみにする

## Edge Function Script Design

### Files

- `supabase/functions/revenuecat-webhook/index.ts`
- `supabase/functions/revenuecat-webhook/deno.json` または project-level import map
- `supabase/config.toml` の function config

RevenueCat は Supabase JWT を持たない外部 webhook なので、webhook function は JWT 検証を無効化し、RevenueCat dashboard で設定した authorization header を function 内で検証する。

### Secrets

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` または hosted Edge Function の `SUPABASE_SECRET_KEYS`
- `REVENUECAT_SECRET_API_KEY`
- `REVENUECAT_WEBHOOK_AUTHORIZATION`
- `REVENUECAT_PRO_ENTITLEMENT_ID` 例: `pro`

service role / secret key は Flutter アプリに入れない。

### Processing Flow

1. `POST` 以外は `405` を返す。
2. `Authorization` header が `REVENUECAT_WEBHOOK_AUTHORIZATION` と一致しなければ `401` を返す。
3. JSON body を parse し、`event.id`, `event.type`, `event.event_timestamp_ms` を検証する。
4. `event.app_user_id`, `event.original_app_user_id`, `event.aliases`, `event.transferred_to` などから user id candidate を作る。
5. UUID として parse でき、かつ Supabase Auth user として存在する candidate だけを採用する。
6. user id に解決できない場合、event id / type / reason だけを redacted structured log に出し、DB へ保存せず `200` を返す。
7. RevenueCat `GET /subscribers/{app_user_id}` を secret API key で呼び、subscriber の現在状態を取得する。
8. `REVENUECAT_PRO_ENTITLEMENT_ID` に対応する entitlement から `is_pro`, `status`, `product_id`, `purchased_at`, `expires_at`, `grace_period_expires_at` を導出する。
9. `pro_entitlement_events.revenuecat_event_id` unique で冪等化しながら、解決済み event を insert する。
10. event insert が duplicate でも、subscriber sync は再実行できるようにする。
11. `user_pro_entitlements` を upsert する。現在状態は webhook body から直接推定せず、subscriber API の正規状態を優先する。
12. `last_event_at` は `greatest(existing.last_event_at, webhook.event_at)` 相当で更新し、古い webhook が metadata を巻き戻さないようにする。
13. RevenueCat API 障害や DB 障害など再試行で回復しうる失敗は `5xx` を返し、RevenueCat retry に任せる。

### Event Semantics

- `CANCELLATION` だけで `is_pro = false` にしない
- `SUBSCRIPTION_PAUSED` だけで access を剥奪しない
- `EXPIRATION` または subscriber API の current entitlement が inactive であることを access removal の根拠にする
- `BILLING_ISSUE` は grace period の有無を見て status を分ける
- `TEMPORARY_ENTITLEMENT_GRANT` は `temporary` として扱い、期限を保存する
- RevenueCat が将来 event type / fields を追加しても function が落ちないよう、unknown fields は無視する

## Flutter App Design

### Repository / Provider

追加候補:

- `lib/billing/pro_entitlement_repository.dart`
- `lib/billing/pro_entitlement_providers.dart`

責務:

- current user id を取得する
- `user_pro_entitlements` を `.select()` で読む
- row がない場合は Free として扱う
- `pro_entitlement_events` は参照しない
- insert / update / delete は実装しない
- loading / error は既存 gate 方針と同じく Free 相当へ倒す

想定 query:

```dart
await Supabase.instance.client
    .from('user_pro_entitlements')
    .select('is_pro,status,product_id,expires_at,last_synced_at')
    .eq('user_id', userId)
    .maybeSingle();
```

### Gate Integration

- `effectiveIsProProvider` は server entitlement を最終判定に含める
- 未ログイン時は Free
- 購入直後や restore 直後は RevenueCat SDK の更新を受けたあと、server entitlement を再読込する
- webhook 反映待ちの短い遅延は loading / retry UI で扱い、クライアントから entitlement を直接書き換えない
- `billingProvider` の RevenueCat CustomerInfo は purchase / restore UX と同期 trigger 用に残せるが、Pro gate の永続的な正本にはしない

## Account Deletion Design

設定画面には現状 sign out はあるが、privacy policy が説明する account deletion path はまだ実装されていない。

アカウント削除は Flutter から直接 `auth.users` を削除できないため、別途 authenticated Edge Function を用意する。function は user JWT を検証した上で service role により `auth.admin.deleteUser(user.id)` を呼ぶ。

削除時の期待結果:

- Supabase Auth user が削除される
- `user_pro_entitlements` が cascade delete される
- `pro_entitlement_events` が cascade delete される
- 端末内 Drift / SQLite のタイムラインデータはクラウド対象ではないため、削除要否を UI で明示する
- store subscription のキャンセルは Google Play / App Store 側の管理であり、削除 UI から subscription 管理画面への案内を出す

## Requirements

- **Functional**: Flutter は `user_pro_entitlements` を select して現在の Pro 状態を取得できる
- **Functional**: Flutter は `pro_entitlement_events` を select できない
- **Functional**: Flutter は entitlement table を insert / update / delete できない
- **Functional**: RevenueCat webhook は service role で `pro_entitlement_events` に event を保存できる
- **Functional**: RevenueCat webhook は service role で `user_pro_entitlements` を upsert / update できる
- **Functional**: `user_id` に解決できない event は `pro_entitlement_events` に保存されない
- **Functional**: webhook 受信後、可能な限り RevenueCat subscriber API の正規状態を `user_pro_entitlements` に反映する
- **Functional**: duplicate webhook は `revenuecat_event_id` unique により冪等に処理される
- **Functional**: アカウント削除時、Supabase 上の課金状態と課金履歴ログが cascade delete される
- **Non-Functional**: service role key は Flutter bundle、CI log、公開 docs に出さない
- **Non-Functional**: `pro_entitlement_events` には raw webhook payload 全体を保存しない
- **Non-Functional**: 古い webhook event が現在状態を巻き戻さない
- **Non-Functional**: privacy policy と Google Play Data Safety の説明を軽く保てるよう、Supabase に残す課金関連データを最小化する

## Tasks

1. SQL schema / RLS / grant / trigger を migration として追加する
2. RevenueCat webhook Edge Function script を追加する
3. webhook event から Supabase `user_id` を解決する helper を実装する
4. RevenueCat subscriber API から Pro entitlement の現在状態を取得する helper を実装する
5. 解決済み event を `pro_entitlement_events` へ冪等 insert する
6. subscriber 正規状態を `user_pro_entitlements` へ upsert / update する
7. unresolved event を redacted structured log へ逃がす
8. Flutter に read-only entitlement repository / provider を追加する
9. `effectiveIsProProvider` と settings / paywall / gate 周辺を server entitlement に接続する
10. account deletion Edge Function と設定画面導線を追加する
11. privacy policy、Google Play Data Safety 記入方針、README または guide を更新する
12. SQL / Edge Function / Flutter provider / account deletion の検証を追加する

## Implementation Notes

2026-05-09 時点で、local repository には以下を実装済み。

- `supabase/migrations/20260509081731_revenuecat_supabase_entitlement_sync.sql`
- `supabase/functions/revenuecat-webhook/index.ts`
- `supabase/functions/delete-account/index.ts`
- `lib/billing/pro_entitlement_repository.dart`
- `lib/billing/pro_entitlement_providers.dart`
- `lib/billing/gate_helper.dart` の server entitlement 接続
- `lib/auth/auth_providers.dart` と `lib/settings/settings_screen.dart` の account deletion 導線
- 実 Supabase project への SQL migration 適用
- `revenuecat-webhook` / `delete-account` Edge Function deploy
- RevenueCat dashboard から Supabase `revenuecat-webhook` への webhook URL / authorization header 接続

未完了の検証は、実 Supabase project 上での RLS / grant / cascade delete 確認、RevenueCat webhook replay、sandbox purchase からの entitlement sync 確認である。この作業環境では `docker` command が存在しないため、local Supabase DB への migration apply は未実行。

## Test Plan

### SQL / RLS

- authenticated user が自分の `user_pro_entitlements` だけ select できる
- authenticated user が他人の `user_pro_entitlements` を select できない
- authenticated user が `user_pro_entitlements` を insert / update / delete できない
- anon user が `user_pro_entitlements` を select できない
- authenticated user が `pro_entitlement_events` を select できない
- service role が両 table を必要範囲で読み書きできる
- `auth.users` 削除で両 table の user rows が cascade delete される
- `status` / `status_after` check constraint が typo を拒否する
- `updated_at` trigger が update 時に動く

### Edge Function

- authorization header 不一致で `401`
- malformed body で `400`
- duplicate `revenuecat_event_id` で二重 event row が作られない
- duplicate event でも subscriber sync が再実行できる
- `user_id` に解決できない event が DB に保存されない
- RevenueCat subscriber API failure で retry 可能な `5xx`
- `CANCELLATION` だけでは `is_pro = false` にならない
- `EXPIRATION` または subscriber current state inactive で `is_pro = false` になる
- out-of-order event で `last_event_at` が古い値へ戻らない
- `TEMPORARY_ENTITLEMENT_GRANT` が `temporary` と期限で保存される

### Flutter

- 未ログイン時は Free
- entitlement row なしは Free
- `is_pro = true` で Pro gate が開く
- loading / error 中は Free 相当
- restore / purchase 後に entitlement provider を再読込する
- `pro_entitlement_events` を参照するコードが存在しない
- service role key が Flutter asset / Dart code / build args に混入していない

### Account Deletion / Privacy

- 設定画面からアカウント削除を開始できる
- 削除確認で Supabase account data と store subscription の扱いを区別して表示する
- 削除後に `user_pro_entitlements` / `pro_entitlement_events` が残らない
- privacy policy の記述と実装が一致する
- Google Play Data Safety の account deletion / data deletion answers と実装が一致する

## Deployment / Rollout

1. [x] Supabase CLI / MCP の現在仕様を確認する。
2. [x] SQL migration を作成し、実 Supabase project に適用する。
3. [ ] RLS / grant / cascade delete を SQL で検証する。
4. [x] Edge Function secrets を登録する。
5. [x] `revenuecat-webhook` function を deploy する。
6. [x] RevenueCat dashboard に webhook URL と authorization header を設定する。
7. [ ] RevenueCat dashboard の test event と sandbox purchase で sync を確認する。
8. [ ] Flutter app を実 Supabase project に向け、read-only entitlement provider を検証する。
9. [ ] account deletion function と UI を実 Supabase project で検証する。
10. [ ] privacy policy / Google Play Data Safety / account deletion URL の記述を最終化する。
11. [ ] production migration、function deploy、RevenueCat production webhook 設定の順に rollout する。

Rollback:

- Flutter 側は entitlement provider failure 時に Free 相当へ倒す
- RevenueCat webhook を一時停止しても既存 `user_pro_entitlements` は最後の状態を保持する
- function 障害時は RevenueCat dashboard から webhook retry できる
- schema 自体は新規前提のため、production 適用前に staging で RLS と delete behavior を検証してから進める
