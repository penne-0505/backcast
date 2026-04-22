---
title: Drift Persistence Repository
status: active
draft_status: n/a
created_at: "2026-04-23"
updated_at: "2026-04-23"
references:
  - README.md
  - _docs/guide/backcast/timeline_editor.md
  - _docs/reference/backcast/timeline_domain_reference.md
  - _docs/reference/backcast/persistence_repository_reference.md
  - _docs/intent/backcast/reverse_timeline_interaction_model.md
related_issues: []
related_prs: []
---

## Context

`Ato` は当初、操作感検証を優先するため `TimelineNotifier` のインメモリ状態のみでタイムラインを扱っていました。
一方で、今後は複数プランの保存・ロードと、過去状態を閲覧できる履歴機能が確実に必要になります。

単一状態の保存だけであれば key-value store でも成立しますが、複数プラン一覧、更新日時順の表示、プラン単位の履歴参照を扱うには、クエリ可能な永続層を早い段階で用意するほうが後戻りが少なくなります。

## Decision

- 永続化基盤として Drift / SQLite を採用する
- 現在プランは `plans` と `plan_blocks` の正規化テーブルで保持する
- 履歴は `plan_snapshots` に `TimelineState` の versioned JSON snapshot として保持する
- `selectedBlockId`、`preciseDraggingId`、`activeInlineEditorId`、`pixelsPerMinute` は一時 UI 状態として永続化しない
- UI から直接 Drift を呼ばず、`PlanRepository` を経由して保存・ロード・履歴操作を行う
- 初期実装では Repository とテストを整備し、`TimelineNotifier` / 画面への自動保存接続は後続作業に分ける

## Alternatives

- `shared_preferences` に単一 JSON を保存する:
  単一タイムライン復元には軽量だが、複数プラン一覧や履歴閲覧で検索・絞り込み・削除が扱いづらくなるため不採用
- 履歴も完全に正規化して差分保存する:
  将来の監査や比較には有利だが、現段階ではモデル変更コストが高く、復元の単純さを優先して不採用
- Drift を UI 状態管理層へ直接注入する:
  実装は短くなるが、ドメインモデルと保存形式の責務が混ざるため不採用

## Rationale

- `plans` と `plan_blocks` を分けることで、プラン一覧と現在状態のロードを SQL で扱いやすい
- 履歴を JSON snapshot にすると、閲覧・復元時に `TimelineState` をそのまま再構成できる
- 保存 JSON に `schemaVersion` を持たせることで、将来のモデル変更時に migration 分岐を追加できる
- 一時 UI 状態を保存しないことで、再ロード後に編集シートやドラッグ状態が不意に復元される事故を避けられる

## Consequences / Impact

- `drift`、`drift_flutter`、`build_runner`、`drift_dev` が依存関係に追加される
- Drift の schema 変更時は生成コード更新と migration 方針の追加が必要になる
- 履歴 snapshot は差分圧縮しないため、極端に大きいプランや高頻度保存では DB サイズが増える
- 現時点のアプリ画面はまだ Repository に接続されていないため、再起動後の自動復元は後続実装が必要

## Rollback / Follow-ups

- Repository 採用を戻す場合は、UI 接続前であれば `lib/persistence/` と Drift 依存を外すだけで影響を閉じられる
- 次の作業で `TimelineNotifier` の hydrate / save 接続、プラン選択 UI、履歴閲覧 UI を追加する
- 複数デバイス同期やエクスポートが必要になった段階で、snapshot JSON の互換性ポリシーを明文化する
