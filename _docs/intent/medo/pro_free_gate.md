---
title: Pro Free Gate
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - README.md
  - _docs/archives/plan/Core/pro-free-gate.md
  - _docs/plan/UI/template-toolbar-popover.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/reference/medo/persistence_repository_reference.md
related_issues: []
related_prs: []
---

## Context

Medo では、基本編集を Free で成立させつつ、複数タイムライン、テンプレート、画像共有、buffer 編集を Pro 価値として扱う必要がありました。
課金状態は UI の表示分岐だけでなく、作成・適用・共有などの action 境界でも一貫して参照する必要があります。

## Decision

- Pro 判定は `effectiveProAccessProvider` を UI/action 境界の source of truth として使い、互換用の `effectiveIsProProvider` は「Pro 確定済みか」の bool projection に留める
- `loading` / `error` は Free と同一視せず、判定が確定するまで Paywall 遷移や Free 上限適用を保留する
- Supabase から確認済みの Pro / Free snapshot は Drift の `cached_pro_entitlements` に保存し、次の問い合わせが完了するまではその snapshot を暫定判定として採用する
- Free はタイムライン 2 件まで作成・利用できる
- Pro はタイムライン数、テンプレート作成・適用、画像共有、buffer 編集を利用できる
- Pro から Free へ戻っても作成済みデータは削除しない
- Free で制限に当たった場合は、対象機能の文脈を持つ Paywall へ遷移する
- テンプレートの編集画面入口は例外的に Free では非表示にし、Paywall 遷移用ボタンとしては出さない

## Alternatives

- 各 UI に個別の判定を埋め込む案は、課金境界が散らばり保守しづらいため不採用
- Free へ戻った時点で超過データを削除する案は、ユーザー作成データを壊すため不採用
- Free にテンプレートボタンを残して Paywall へ誘導する案は、編集ツールバー上に実行不能な action を混ぜるため不採用

## Rationale

Pro gate は売上上の境界であると同時に、ユーザーデータ保護の境界でもあります。
編集できる範囲を縮退させても、保存済みの計画やテンプレートは保持する方針にすると、解約や一時的な entitlement 不整合に耐えやすくなります。
テンプレートは編集ツールバー上の action として扱うため、Free では「使えないボタン」を置くより入口を消す方が操作面の誤解が少なくなります。

## Consequences / Impact

- Paywall は機能文脈ごとの説明を持つ
- persistence 層は Free/Pro にかかわらず作成済みデータを保持する
- action 境界での gate 漏れが UX と課金仕様の両方に影響する
- テンプレート訴求は編集ツールバーではなく、Paywall や設定画面など課金文脈のある場所に寄せる
- 起動直後や再同期中は確認済みローカル snapshot を使い、cache がない場合だけ「未判定」状態を明示する
- リモート問い合わせが成功した時点で cache を更新するため、解約・期限切れなどの最終判定は Supabase 側の状態に収束する

## Rollback / Follow-ups

- RevenueCat / Supabase の Pro 判定に障害があり、かつ確認済み cache がない場合は Free と断定せず、課金状態を確認できない状態として retry / restore / 通信確認に誘導する
- 将来 Pro 機能が増える場合も、データ削除ではなく利用導線の縮退を優先する
