---
title: "Usage Analytics Hardening"
status: active
draft_status: n/a
created_at: "2026-05-14"
updated_at: "2026-05-14"
references:
  - "usage-analytics.md"
  - "../../intent/medo/usage_analytics.md"
  - "../../guide/medo/privacy_policy_operations.md"
  - "../../guide/medo/google_play_data_safety_memo.md"
  - "../../reference/medo/persistence_repository_reference.md"
related_issues: []
related_prs: []
---

## Overview

Medo の利用改善 analytics は、privacy-first の allowlist event と opt-in を前提に追加された。一方、初期実装レビューでは、analytics upload が退会 cleanup や起動・操作フローを待たせること、永続 `uploading` state が crash 後に再送不能になること、Supabase Edge Function の deployment/auth/idempotency が曖昧であることが見つかった。

この plan では、analytics の正確性や即時性よりも、アプリ本体の UX、退会時のローカル削除保証、queue の再送可能性、privacy policy / Google Play Data Safety との整合を優先して hardening する。

設計上の目標は「取れたら有用な改善データ」を、ユーザー操作や削除保証の critical path から外すことである。

## Scope

- `UsageAnalyticsService.track(...)` を、同意確認、property sanitize、ローカル enqueue までの処理にする。
- upload / flush は background best-effort として実行し、UI action、起動処理、退会処理を待たせない。
- Drift 上の永続 `uploading` state を使わない、または再送可能な状態へ整理する。
- retry 回数と最終試行時刻を、再送判断と調査に使える形で更新する。
- 退会フローでは、`delete-account` 成功直後に cleanup marker を保存し、analytics は削除保証より優先しない。
- `account_deleted` event は初期 hardening では production caller から外す。保持する場合も best-effort のみとし、退会 cleanup の前提にしない。
- `usage-analytics` Edge Function の `supabase/config.toml` 設定を明示する。
- Edge Function を匿名 opt-in 送信に対応させる場合は、public endpoint として schema validation、payload limit、duplicate retry 処理を固める。
- batch insert と event insert の中途失敗で orphan batch や恒久 retry failure が残らないようにする。
- README、plan、privacy operations、Data Safety memo、persistence reference の実装説明と検証コマンドを同期する。

## Non-Goals

- Firebase Analytics、PostHog、Amplitude など第三者 analytics SDK の導入。
- dashboard UI、A/B testing、remote config、campaign attribution の実装。
- exact-once delivery の保証。
- IP address、広告 ID、端末固有 ID、位置情報を使った rate limit。
- `account_deleted` を分析上必ず取得する仕組み。
- 送信済み anonymous analytics event をアプリ内アカウント削除だけで server-side 物理削除する仕組み。
- タイムライン、予定、テンプレート、カレンダー本文などユーザー作成データの cloud sync。

## Requirements

- **Functional**: consent disabled では queue 作成も upload も発生しない。
- **Functional**: consent enabled でも、`track(...)` は network upload 完了を待たない。
- **Functional**: upload 失敗時、event は再送可能な状態で queue に残る。
- **Functional**: app crash や process kill が upload 中に起きても、次回 flush で再送対象から落ちない。
- **Functional**: `attemptCount` は試行ごとに増え、`lastAttemptAt` は試行時刻へ更新される。
- **Functional**: opt-out は未送信 queue、install id、last flush state を削除する。
- **Functional**: 退会時は `delete-account` 成功直後に cleanup marker を保存し、analytics 失敗で cleanup retry 可能性を失わない。
- **Functional**: Edge Function は duplicate `client_event_id` retry を恒久失敗にしない。
- **Functional**: Edge Function は event insert 失敗時に不要な batch row を残さない、または DB 側 transaction/RPC で一貫性を保つ。
- **Non-Functional**: analytics は app core flow の failure source にならない。
- **Non-Functional**: external endpoint は allowlist event と schema validation だけを受け付け、raw payload を server log に出さない。
- **Non-Functional**: Google Play Data Safety と privacy policy に、任意 opt-in analytics と収集内容の粒度が一致している。

## Design Decisions and Trade-offs

### Account Deletion

退会フローでは、analytics より cleanup marker を優先する。`account_deleted` event は churn signal として有用だが、これを待つことで Auth user 削除後のローカル cleanup retry marker が残らない状態を作るべきではない。

初期 hardening では、`deleteAccount()` から `account_deleted` の awaited tracking を外す。event contract に残す場合も production caller は持たず、将来 server-side deletion metrics を設計するまで未使用にする。

### Track and Flush Boundary

`track(...)` は local enqueue までを同期的責務とし、upload は `unawaited(flush())` で試行する。即時送信率は少し下がるが、操作完了、起動、calendar export、template action、purchase flow が network state に引っ張られなくなる。

analytics は監査ログではなく product improvement signal なので、delivery は best-effort でよい。

### Queue State

永続 `uploading` state は初期実装から外す。process 内の `_isFlushing` で二重 flush を抑止し、DB 上では `pending` / `failed` の event を再送可能なまま残す。

この判断により、DB だけを見た upload in-progress 観測は弱くなる。一方で、crash 後に event が永久に再送対象から外れる failure mode を避けられる。

### Edge Function Auth

未ログインユーザーの opt-in analytics を受け取るため、`usage-analytics` は `verify_jwt = false` を明示する。これは endpoint を public にする判断であり、security boundary は JWT ではなく payload size、batch size、schema allowlist、duplicate handling、service-role table isolation に置く。

IP address を保存して rate limit する案は初期 hardening では採用しない。privacy scope が広がるため、まずは小さい payload と strict schema で受け、濫用が確認された場合だけ別 plan で対策する。

### Ingestion Idempotency

初期 hardening では、Postgres RPC 化より小さい修正を優先する。

- duplicate `(install_id, client_event_id)` は受理済みとして扱い、client queue を詰まらせない。bulk insert が unique violation になった場合は row 単位で再試行し、同じ batch に混ざった新規 event は保存する。
- batch insert 後に event insert が失敗した場合は、作成済み batch を削除する。
- それでも一貫性要件が強くなった場合に、DB transaction を持つ `ingest_usage_analytics_batch(...)` RPC へ移行する。

## Tasks

1. `AuthNotifier.deleteAccount()` の順序を変更し、`delete-account` 成功直後に `cleanup.markPending()` を保存する。
2. `account_deleted` tracking を退会 cleanup の critical path から外す。初期 hardening では production caller から削除し、必要なら event schema 側も削除または reserved として明記する。
3. `UsageAnalyticsService.track(...)` を local enqueue までにし、flush は background best-effort にする。
4. `UsageAnalyticsRepository` から永続 `uploading` 依存を外し、送信試行前に `attemptCount` と `lastAttemptAt` を更新する。
5. flush 成功時は送信済み event を削除し、失敗時は `failed` として再送対象に残す。
6. `supabase/config.toml` に `[functions.usage-analytics]` を追加し、匿名 opt-in 送信に合わせて `verify_jwt = false` を明示する。
7. `usage-analytics` Edge Function で duplicate retry を成功扱いにし、event insert 失敗時の orphan batch を cleanup する。
8. Dart test に non-blocking `track(...)`、retry count、upload 中断後の再送、退会時 analytics 失敗でも marker が残るケースを追加する。
9. Deno test に duplicate event、event insert failure、method/schema/payload limit の regression を追加する。
10. README、`usage-analytics.md`、persistence reference、privacy operations guide、Google Play Data Safety memo の検証コマンドと説明を hardening 後の仕様へ更新する。

## Implementation Notes

2026-05-14 実装では、`track(...)` はローカル enqueue 後に `unawaited(flush())` を呼ぶ形へ変更した。process 内の active flush は `Future<void>?` で共有し、DB 上の永続 state は `pending` / `failed` のみに整理している。

`account_deleted` event は schema / contract 上は残すが、`AuthNotifier.deleteAccount()` の production caller からは外した。退会フローは `delete-account` 成功直後に cleanup marker を保存し、その後にローカル cleanup を実行する。

`usage-analytics` Edge Function は `supabase/config.toml` で `verify_jwt = false` を明示した。event insert が duplicate `client_event_id` で失敗した場合は row 単位で再試行して新規 event を保存し、全件 duplicate なら受理済みとして batch row を cleanup する。それ以外の event insert failure では作成済み batch row を cleanup する。

## Test Plan

- Dart unit test:
  - consent disabled で queue と upload が発生しない。
  - `track(...)` が fake uploader の完了を待たずに返る。
  - upload 成功時に queue から event が削除される。
  - upload 失敗時に event が `failed` として残り、次回 flush で再送される。
  - upload 試行ごとに `attemptCount` が増える。
  - opt-out で queue と analytics preferences が削除される。
  - account deletion flow で analytics upload が失敗しても cleanup marker が保存され、local cleanup が実行または再試行可能になる。
- Supabase function test:
  - valid batch を insert する。
  - unsupported event / property / platform / mixed install id / payload too large を reject する。
  - duplicate `client_event_id` retry を success 扱いにする。
  - event insert failure 時に batch cleanup を行う。
- Integration smoke:
  - `/home/penne/sdk/flutter/flutter/bin/flutter analyze`
  - `/home/penne/sdk/flutter/flutter/bin/flutter test`
  - `deno test --config supabase/functions/usage-analytics/deno.json --allow-env --allow-net supabase/functions/usage-analytics/index_test.ts`

## Deployment / Rollout

1. アプリ側 hardening を先に入れ、analytics 失敗が UX / cleanup を阻害しない状態にする。
2. `supabase/config.toml` の `usage-analytics` 設定を追加し、Edge Function を deploy する。
3. migration 適用済み環境で、duplicate retry と valid batch の smoke を確認する。
4. privacy policy、public HTML、Google Play Data Safety memo、README の説明を hardening 後の仕様に合わせる。
5. リリース後に問題が出た場合、アプリ側は toggle / flush no-op、server 側は Edge Function を reject-only にして受信を止める。

Rollback:

- アプリ側は `UsageAnalyticsService.flush()` を no-op にして外部送信を止める。
- Edge Function は 200 `{ ok: true, accepted: 0, disabled: true }` を返す reject-only mode にする。
- Supabase analytics tables は残しても app core behavior に影響しない。

## Follow-up Questions

- duplicate retry は success 扱いにした。bulk insert が unique violation になった場合は row 単位で再試行するが、より強い一貫性や詳細な accepted count が必要になったら DB transaction を持つ RPC 化と合わせて再設計する。
- `account_deleted` event schema は将来の server-side metrics 用に contract 上だけ reserved とする。
- analytics retention policy を privacy policy へ明示するか。初期 hardening では送信済み event の server-side retention は別途運用判断とする。
