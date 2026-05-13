---
title: "Privacy-first Usage Analytics"
status: active
draft_status: n/a
created_at: "2026-05-13"
updated_at: "2026-05-14"
references:
  - "../../plan/Core/usage-analytics.md"
  - "../../reference/medo/persistence_repository_reference.md"
related_issues: []
related_prs: []
---

## Context

Medo はタイムライン、テンプレート、履歴、ローカル通知、カレンダー登録データを Supabase に同期しない方針を持つ。一方で、未リリース段階から利用率改善のために、どの導線が使われ、どこで離脱しているかを把握する必要がある。

第三者 analytics SDK を導入すると、自動収集や SDK 固有の識別子、Data Safety / privacy policy の説明範囲が広がりやすい。Medo では自由入力を含む timeline editor が中心であるため、screen autocapture や汎用 event logging は現在の privacy boundary と相性が悪い。

## Decision

- Firebase Analytics などの第三者自動計測 SDK は導入しない。
- 初期状態では analytics 送信を off にする。
- 設定画面で明示同意した場合だけ、allowlist event を端末内 queue に保存して Supabase Edge Function へ batch 送信する。
- `track(...)` はローカル queue 保存までを責務とし、upload は background best-effort とする。
- `UsageAnalyticsService` を境界にし、UI や domain service は直接 Drift / Supabase analytics table を触らない。
- event properties は event ごとの schema と sanitizer を通し、schema 外 key は保存前に破棄する。
- タイムライン本文、plan title、block title、target title、自由入力、raw time、メールアドレス、Supabase user id は保存・送信しない。
- install identifier は random UUID とし、Supabase user id とは分離する。

## Consequences

- 利用 funnel は把握できるが、個別ユーザーの詳細な行動履歴やコンテンツ内容の分析はできない。
- 同意前の event は初期実装では queue しないため、初回導線の一部は同意後のユーザーに限って観測される。
- Supabase 側は direct table insert を許可せず、`usage-analytics` Edge Function で schema validation してから service role client で保存する。
- Drift schema version は 6 になり、`analytics_events` table が追加される。
- アカウント削除と opt-out はローカル analytics queue と analytics preferences を削除する。
- 永続 queue の upload state は `pending` / `failed` だけを使い、crash 後も再送対象から落ちないようにする。
- `account_deleted` event は contract 上 reserved として残すが、初期 hardening 後の production caller からは外す。

## Alternatives Considered

- Firebase Analytics:
  Flutter との統合は容易だが、第三者 SDK の収集範囲、platform 設定、privacy policy / Data Safety 対応が増えるため不採用。
- PostHog などの product analytics SDK:
  分析 UI は強いが、未リリース段階の最小 funnel 把握には過剰であり、autocapture 系を誤って有効化した場合の privacy risk が大きいため初期実装では不採用。
- 端末内だけで集計する:
  privacy risk は小さいが、開発者が funnel を確認できず、利用率改善の目的を満たさないため不採用。
