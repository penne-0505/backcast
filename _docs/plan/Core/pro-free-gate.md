---
title: Pro Free Gate
status: implemented
draft_status: n/a
created_at: "2026-05-02"
updated_at: "2026-05-04"
references:
  - TODO.md
  - _docs/plan/UI/timeline-slot-toggle.md
  - _docs/plan/Core/timeline-templates.md
  - _docs/plan/Core/timeline-image-share.md
related_issues: []
related_prs: []
---

## Overview

Medo の Pro / Free 境界を `isProProvider` を source of truth として整理する。

初期対象は、タイムライン保持数、テンプレート、画像エクスポートの3つとする。Free でも逆算タイムラインの基本編集は成立させ、日常利用を過度に阻害しない。一方で、省力化・共有品質・大量運用にあたる機能を Pro 価値として扱う。

## Scope

- タイムライン保持数の gate を実装する。
- テンプレート機能の gate を実装する。
- 画像エクスポートの gate を実装する。
- Free から Pro、Pro から Free への entitlement 変化に対する縮退方針を実装する。
- Pro 説明 / paywall への遷移導線を用意する。
- gate 判定を UI だけでなく、作成・適用・実行の action 境界でも確認する。

## Non-Goals

- RevenueCat 設定値の投入。
- 価格・商品文言の最終決定。
- クラウド同期。
- Free 超過データの自動削除。
- テンプレート一覧 / 編集体験そのものの詳細設計。
- 画像エクスポートの visual design 詳細。

## Gates

### Timeline Count

- Free は最大2つのタイムラインを保持できる。
- Pro はタイムラインを無制限に保持できる。
- Free で2件保持済みの場合、新規タイムライン作成はできない。
- Pro から Free へ戻ったときに3件以上のタイムラインが存在しても、データは削除しない。
- Free への縮退時は、利用可能な範囲を2件に制限し、Pro 復帰時に全件を再び利用可能にする。
- 詳細な UI / data model は `_docs/plan/UI/timeline-slot-toggle.md` に従う。

### Templates

- Free はテンプレートを使用不可とする。
- Pro はテンプレートを無制限に作成・保存・適用できる。
- Free ではテンプレート作成、テンプレート保存、テンプレート適用を action 境界で拒否する。
- Pro から Free へ戻っても既存テンプレートデータは削除しない。
- Free 中は既存テンプレートが端末内に残っていても作成・保存・適用できない。
- Pro に戻った場合、既存テンプレートは再び利用可能にする。
- テンプレート機能本体の保存・一覧・適用・編集・削除仕様は `_docs/plan/Core/timeline-templates.md` に従う。

Free で残す導線は次に限定する。

- 設定画面の Pro 説明導線。
- Pro 説明 / paywall 内のテンプレート説明。
- テンプレートボタンそのもの。

Free でテンプレートボタンを押した場合は、テンプレート UI を開かず、Pro 説明 / paywall へ遷移する。

### Image Export

- Free は画像エクスポートを使用不可とする。
- Pro は画像エクスポートを使用できる。
- Free で画像エクスポート導線を押した場合は、画像生成処理を開始せず、Pro 説明 / paywall へ遷移する。
- 画像エクスポート自体の生成仕様は `_docs/plan/Core/timeline-image-share.md` に従う。

## Paywall

- Pro 説明 / paywall は、現在押された機能に応じた文脈を受け取れるようにする。
- テンプレートボタンから遷移した場合は、テンプレートが Pro 機能であることを説明する。
- timeline count 上限から遷移した場合は、Free は2件まで、Pro は無制限であることを説明する。
- 画像エクスポートから遷移した場合は、共有専用画像を生成できることを説明する。

## Requirements

- **Functional**: `isProProvider` が `false` の場合、テンプレートの作成・保存・適用はできない。
- **Functional**: `isProProvider` が `true` の場合、テンプレートの作成・保存・適用に数の上限を設けない。
- **Functional**: Free でテンプレートボタンを押すと Pro 説明 / paywall へ遷移する。
- **Functional**: Free でテンプレート関連データが既に存在しても削除しない。
- **Functional**: Free はタイムライン2件まで、Pro は無制限に作成できる。
- **Functional**: Free は画像エクスポートを実行できない。
- **Non-Functional**: gate は UI 表示だけに依存せず、実行 action 側でも判定する。
- **Non-Functional**: billing loading / error の間は Free 相当として扱い、Pro 専用 action は実行しない。
- **Non-Functional**: Pro から Free への縮退でユーザーデータを破壊しない。

## Tasks

1. `isProProvider` を用いた共通 gate helper または action-level 判定を追加する。
2. timeline 作成導線に Free 2件 / Pro 無制限の作成可否を接続する。
3. テンプレートボタンを Free では Pro 説明 / paywall 遷移に接続する。
4. テンプレート作成・保存・適用 action に Pro 判定を追加する。
5. テンプレート関連データを Pro 解約時に削除しないことを保証する。
6. 画像エクスポート導線と実行 action に Pro 判定を追加する。
7. Pro 説明 / paywall が feature context を受け取れるようにする。
8. Free / Pro / billing loading / downgrade / restore Pro の targeted test を追加する。
9. 実装後、関連する guide / reference / README を更新する。

## Test Plan

- Free でテンプレートボタンを押すと Pro 説明 / paywall へ遷移する。
- Free でテンプレート作成・保存・適用 action が実行されない。
- Pro でテンプレートを複数作成・適用できる。
- Pro から Free へ戻ってもテンプレートデータが削除されない。
- Free から Pro へ戻ると既存テンプレートが再利用できる。
- Free で timeline が2件ある場合、新規作成できない。
- Pro で timeline が2件以上あっても新規作成できる。
- Free で画像エクスポートを押すと生成せず Pro 説明 / paywall へ遷移する。
- billing loading / error 中は Free 相当として扱われる。

## Deployment / Rollout

- gate は機能単位で段階的に接続できる。
- 既存ユーザーデータを削除する migration は行わない。
- 不具合時は各 gate 導線を feature flag 相当の条件で隠し、基本編集機能へ戻せるようにする。
