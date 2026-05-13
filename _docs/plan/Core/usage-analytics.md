---
title: "Privacy-first Usage Analytics"
status: active
draft_status: n/a
created_at: "2026-05-13"
updated_at: "2026-05-14"
references:
  - "usage-analytics-hardening.md"
  - "../../intent/medo/drift_persistence_repository.md"
  - "../../reference/medo/persistence_repository_reference.md"
  - "../../standards/privacy-policy.md"
  - "../../guide/medo/privacy_policy_operations.md"
related_issues: []
related_prs: []
---

## Overview

Medo の利用改善に必要な最小 telemetry を、Firebase Analytics などの第三者自動計測 SDK に依存せずに実装する。

現在の Medo は、タイムライン、テンプレート、履歴、ローカル通知、カレンダー登録データを Supabase に同期しない方針を持つ。この plan では、その境界を維持したまま、利用 funnel の把握に必要な allowlist event だけを端末内 queue に保存し、ユーザーが明示的に同意した場合だけ Supabase Edge Function へ batch 送信する。

目的は「ユーザーが何を書いたか」を知ることではなく、「どの機能導線が使われ、どこで離脱しているか」を知ることである。

## Hardening Follow-up

初期実装レビュー後の修正計画は [`usage-analytics-hardening.md`](usage-analytics-hardening.md) を原典とする。

特に、退会時の `account_deleted` tracking、`track(...)` と `flush()` の境界、永続 `uploading` state、`usage-analytics` Edge Function の auth / idempotency は、hardening plan の判断を優先する。

## Scope

- Drift / SQLite に analytics 用のローカル queue と consent state を追加する。
- `UsageAnalyticsService` を追加し、UI や service layer から直接 Drift / Supabase を触らず `track(...)` 経由で記録する。
- allowlist event name と property schema を Dart 側で定義し、自由入力・具体的な予定内容・raw timestamp を送信対象から除外する。
- 同意済みの場合のみ、ローカル queue を Supabase Edge Function `usage-analytics` へ batch upload する。
- Supabase 側に ingestion 用 table と Edge Function を追加する。
- 設定画面に利用改善データ送信の opt-in / opt-out を追加する。
- README、privacy policy、persistence reference、運用 guide を更新する。

## Non-Goals

- Firebase Analytics、PostHog、Amplitude などの第三者 analytics SDK 導入。
- session recording、screen autocapture、widget text autocapture。
- タイムライン本文、plan title、block title、target title、テンプレート名、自由入力文字列の送信。
- ユーザー単位の詳細行動履歴を長期保存する分析基盤。
- A/B testing framework。
- dashboard UI の作成。初期段階では SQL / Supabase dashboard で確認する。
- 複数デバイス間で analytics state を同期すること。

## Requirements

- **Functional**: 初期状態では外部送信を行わない。
- **Functional**: opt-in 後に記録済み queue を送信対象にできる。ただし opt-in 前の event を送るかは設定値で明示し、初期実装では opt-in 後の event のみ送る。
- **Functional**: opt-out 時は未送信 queue を削除し、以後の外部送信を停止する。
- **Functional**: event name は allowlist 以外を記録・送信しない。
- **Functional**: properties は event ごとの schema に通し、許可されていない key と値型を破棄する。
- **Functional**: 送信失敗時は queue に残し、後続起動または次回 flush で再試行する。
- **Functional**: アカウント削除時はローカル analytics queue と consent / install identifier を削除対象に含める。
- **Non-Functional**: raw user content、raw calendar content、precise location、contacts、広告識別子を扱わない。
- **Non-Functional**: install identifier は random UUID とし、Supabase user id とは分離する。
- **Non-Functional**: property の時間情報は raw timestamp ではなく bucket 化する。
- **Non-Functional**: 1 batch は件数と payload size に上限を設ける。
- **Non-Functional**: Edge Function は method、auth、schema、batch size、event allowlist を検証し、不正 payload を保存しない。

## Local Analytics Queue

Drift schema version を更新し、以下を追加する。

- `analytics_events`
  - `id`: local event UUID
  - `eventName`: allowlist event name
  - `propertiesJson`: sanitizer 通過後の JSON
  - `occurredAt`: event 発生時刻
  - `sessionId`: app session UUID
  - `installId`: random install UUID
  - `uploadState`: `pending` / `failed`
  - `attemptCount`: 送信試行回数
  - `lastAttemptAt`: nullable
  - `createdAt`: row 作成時刻
- `app_preferences`
  - `analyticsConsent`: `enabled` / `disabled`
  - `analyticsInstallId`: random UUID
  - `analyticsLastFlushAt`: nullable ISO8601

`analytics_events` は user content table と FK で結ばない。アカウント削除 cleanup では `analytics_events` と analytics 関連 preference を削除する。

## Consent and Privacy Boundary

設定画面に「利用改善データの送信」相当の toggle を追加する。

- 既定値は off。
- off の間も、初期実装では event queue 自体を作らない。
- on にした時点で install id を作成し、以後の allowlist event を queue に入れる。
- off に戻した場合、未送信 event を削除し、以後の flush を停止する。
- 送信済み event の削除要求はアカウント削除フローで扱う。匿名 install id ベースのため、個別削除の UX を追加する場合は server 側の削除 function が別途必要になる。

この設計は、現行 privacy policy の「アプリ内コンテンツは端末内のみ」という約束を維持するための境界である。analytics は端末内コンテンツの同期ではなく、同意済みの利用イベント送信として扱う。

## Event Contract

初期 allowlist は以下に限定する。

| Event | Purpose | Allowed properties |
| --- | --- | --- |
| `app_opened` | 起動継続率 | `launch_source`, `platform` |
| `first_plan_created` | 初回価値到達 | `block_count_bucket` |
| `plan_created` | 作成頻度 | `source`, `block_count_bucket` |
| `plan_saved` | 編集継続 | `block_count_bucket`, `has_buffer` |
| `block_added` | editor 利用 | `block_type`, `block_count_bucket` |
| `block_reordered` | editor 深度 | `block_count_bucket` |
| `template_created` | template 価値 | `block_count_bucket` |
| `template_applied` | template 再利用 | `block_count_bucket` |
| `calendar_export_started` | calendar funnel 開始 | `event_count_bucket`, `platform` |
| `calendar_export_completed` | calendar funnel 完了 | `event_count_bucket`, `result` |
| `text_share_completed` | share funnel | `block_count_bucket` |
| `image_share_completed` | share funnel | `block_count_bucket`, `result` |
| `paywall_viewed` | monetization funnel | `source` |
| `purchase_started` | monetization funnel | `source` |
| `purchase_completed` | monetization funnel | `result` |
| `account_deleted` | reserved churn signal; 初期 hardening 後の production caller なし | `had_pro_cache` |

禁止する property:

- `title`
- `name`
- `text`
- `description`
- `calendar_title`
- `target_time`
- `start_time`
- `end_time`
- `email`
- `user_id`
- 任意の自由文字列

bucket 例:

- `block_count_bucket`: `0`, `1`, `2-3`, `4-5`, `6-10`, `11+`
- `duration_bucket`: `0`, `1-15`, `16-30`, `31-60`, `61-120`, `121+`
- `event_count_bucket`: `1`, `2-3`, `4-5`, `6-10`, `11+`

## Supabase Ingestion

Supabase migration で以下を追加する。

- `analytics_event_batches`
  - batch 単位の受信記録
  - `install_id`
  - `app_version`
  - `platform`
  - `received_at`
- `analytics_events`
  - batch に紐づく allowlist event
  - `event_name`
  - `properties jsonb`
  - `occurred_at`
  - `session_id`
  - `install_id`

RLS 方針:

- client から table へ direct insert させない。
- anon / authenticated には analytics tables の direct 権限を付与しない。
- `usage-analytics` Edge Function が service role client で insert する。

Edge Function `usage-analytics`:

- `POST` のみ許可。
- 未ログインの opt-in event を受けるため、`supabase/config.toml` で `verify_jwt = false` を明示する。
- request body の batch size と payload size を検証する。
- app version、platform、install id、session id、event name、properties を schema validation する。
- allowlist にない event name は batch 全体を reject するか、該当 event を reject して error として返す。初期実装では安全側に倒して batch 全体を reject する。
- duplicate `(install_id, client_event_id)` retry は受理済みとして扱い、client queue を恒久的に詰まらせない。bulk insert が unique violation になった場合は row 単位で再試行し、同じ retry batch に混ざった新規 event は保存する。
- batch insert 後に event insert が失敗した場合は、作成済み batch row を cleanup する。
- server logs に raw payload を出さない。

## Instrumentation Points

最初に接続する場所は、価値到達と離脱が見える user action に限定する。

- app 起動後の analytics service 初期化時: `app_opened`
- timeline 作成完了時: `first_plan_created`, `plan_created`
- auto save または明示保存の安定点: `plan_saved`
- block 追加時: `block_added`
- 並び替え確定時: `block_reordered`
- template 作成 / 適用時: `template_created`, `template_applied`
- calendar export preview / save result: `calendar_export_started`, `calendar_export_completed`
- text / image share 完了時: `text_share_completed`, `image_share_completed`
- paywall 表示 / purchase result: `paywall_viewed`, `purchase_started`, `purchase_completed`
- account deletion: 初期 hardening 後は production caller から外す。将来 server-side deletion metrics を設計する場合だけ再検討する。

直接 UI に分析ロジックを散らさず、action handler から `UsageAnalyticsService.track(...)` を呼ぶ。値の bucket 化は service 側または dedicated helper に寄せる。

## Tasks

1. Drift schema と generated code を更新する。
2. `lib/analytics/` に event model、sanitizer、repository、service、providers を追加する。
3. 設定画面に opt-in / opt-out toggle を追加する。
4. アカウント削除 cleanup に analytics queue / preferences 削除を追加する。
5. Supabase migration と `usage-analytics` Edge Function を追加する。
6. 主要 funnel action へ instrumentation を接続する。
7. README、privacy policy、persistence reference、privacy operations guide を更新する。

## Test Plan

- Dart unit test:
  - allowlist 外 event が reject される。
  - 禁止 property が保存前に破棄される。
  - bucket helper が境界値を正しく分類する。
  - consent off では queue が増えない。
  - opt-out で未送信 queue が削除される。
  - `track(...)` が network upload 完了を待たずに返る。
  - flush 成功時に queue から event が削除される。
  - flush 失敗時に pending / failed と attempt count が保持される。
- Drift repository test:
  - pending event の取得順と batch limit。
  - account deletion cleanup 後に analytics table / preference が空になる。
- Supabase function test:
  - method 不正、schema 不正、allowlist 外 event、payload 過大を reject する。
  - valid batch を insert する。
  - duplicate `client_event_id` retry を success 扱いにする。
  - event insert failure 時に batch cleanup を行う。
- Integration smoke:
  - `flutter analyze`
  - `flutter test`
  - `deno test` for `supabase/functions/usage-analytics`

## Deployment / Rollout

1. privacy policy と Google Play Data Safety の更新要否を確認する。
2. Supabase migration を適用する。
3. `usage-analytics` Edge Function を `supabase/config.toml` の `verify_jwt = false` 設定込みで deploy する。
4. アプリ側は初期状態 off のため、リリース後も opt-in されるまで送信は発生しない。
5. 問題があれば、設定値またはアプリ update で flush を停止する。server 側は Edge Function を undeploy または reject-only にして受信を止められる。

Rollback:

- アプリ側の toggle を off にする、または service の flush を no-op にする。
- Edge Function を reject-only にする。
- Supabase table は残してもアプリ挙動に影響しない。
