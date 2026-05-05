---
title: Timeline Templates
status: proposed
draft_status: n/a
created_at: "2026-05-03"
updated_at: "2026-05-03"
references:
  - TODO.md
  - _docs/plan/Core/pro-free-gate.md
  - _docs/reference/medo/persistence_repository_reference.md
  - _docs/guide/medo/timeline_editor.md
related_issues: []
related_prs: []
---

## Overview

Medo の現在タイムラインを再利用可能なテンプレートとして保存し、別のタイムラインへ適用できるようにする。

テンプレートは、日常的に繰り返す逆算パターンを保存する Pro 専用機能として扱う。Free ではテンプレート UI を利用できず、テンプレートボタンを押した場合は Pro 説明 / paywall へ遷移する。Pro ではテンプレートの作成・保存・適用に数の上限を設けない。

実装は一括ではなく、次の4タスクに分割する。

- `Core-Feat-27`: テンプレート永続化基盤
- `Core-Enhance-28`: テンプレート適用フロー
- `UI-Feat-29`: テンプレート管理 UI
- `Core-Enhance-30`: テンプレート Pro gate 接続

## Scope

- 現在の `TimelineState` をテンプレートとして保存する。
- 保存済みテンプレート一覧を表示する。
- テンプレートを現在のタイムラインへ適用する。
- テンプレート名を編集できるようにする。
- 不要なテンプレートを削除できるようにする。
- Pro のみテンプレート作成・保存・適用・編集・削除を実行できるようにする。
- Free ではテンプレートボタン押下時に Pro 説明 / paywall へ遷移する。
- 実装後、persistence reference と timeline editor guide を更新する。

## Non-Goals

- Free でのテンプレート使用。
- テンプレート数の上限設定。
- テンプレートのクラウド同期。
- テンプレートのカテゴリ、タグ、検索、並び替え。
- テンプレート適用時の部分挿入。
- 現在タイムラインとの差分マージ。
- テンプレート共有 / インポート / エクスポート。
- テンプレートごとの履歴 snapshot。

## Data Model

Drift schema にテンプレート用テーブルを追加する。

- `timeline_templates`
  - `id`: template ID
  - `title`: テンプレート名
  - `targetTime`: 保存時の目標時刻
  - `targetTimeTitle`: 保存時の目標ラベル
  - `createdAt`
  - `updatedAt`
- `timeline_template_blocks`
  - `id`: template block ID
  - `templateId`: 所属 template ID
  - `type`: `action` または `actionPoint`
  - `title`: block title
  - `duration`: 分単位の所要時間
  - `colorIndex`: block color index
  - `position`: `TimelineState.blocks` 上の順序

保存形式は既存の `plans` / `plan_blocks` に近い正規化テーブルを推奨する。実装者は `TimelineState` JSON snapshot 形式を選んでもよいが、一覧表示、rename、将来の移行を考えると正規化テーブルを優先する。

テンプレートから `TimelineState` を復元するときは、保存済み block ID をそのまま使わず、新しい block ID を採番する。これにより、適用先 timeline 内の既存 block ID と衝突しないようにする。

## Entitlement Model

- `Core-Feat-19` の effective Pro 判定を使用する。
- Free ではテンプレート一覧を開かない。
- Free ではテンプレート作成・保存・適用・編集・削除 action を実行しない。
- Free でテンプレートボタンを押した場合は Pro 説明 / paywall へ遷移する。
- Pro ではテンプレートを無制限に作成・保存・適用・編集・削除できる。
- Pro から Free へ戻ってもテンプレートデータは削除しない。
- Pro に戻った場合、既存テンプレートは再び利用可能にする。

## Interaction Model

### Template Button

- 編集画面にテンプレートボタンを置く。
- Free ではボタン押下で Pro 説明 / paywall へ遷移する。
- Pro ではボタン押下で template sheet を開く。
- ボタンの見た目は既存の header / floating controls と衝突しないようにする。

### Template Sheet

template sheet には次を含める。

- 現在タイムラインをテンプレートとして保存する action。
- 保存済みテンプレート一覧。
- 各テンプレートの名前、目標ラベル、目標時刻、block 数、更新日時。
- テンプレート適用 action。
- テンプレート名編集 action。
- テンプレート削除 action。

### Save Current Timeline As Template

- 現在の `TimelineState` 全体をテンプレートとして保存する。
- 初期テンプレート名は、現在の timeline name、`targetTimeTitle`、または `無題のテンプレート` から補完する。
- 空文字または whitespace のみの名前は `無題のテンプレート` に正規化する。
- 空 blocks でも保存できる。ただし UI 上は block 数 0 として表示する。

### Apply Template

- テンプレート適用は、初回では現在タイムラインの内容を置き換える操作とする。
- 適用前に確認 UI を出し、既存 blocks / target anchor が置き換わることを明示する。
- 適用時は `targetTime`, `targetTimeTitle`, `blocks` をテンプレートから復元する。
- 適用後は `selectedBlockId`, `activeInlineEditorId`, `preciseDraggingId` などの一時 UI 状態をクリアする。
- 適用先 plan が存在する場合、適用前または適用後に snapshot を作成し、復元可能性を確保する。

## Requirements

- **Functional**: Pro ユーザーは現在 timeline をテンプレートとして保存できる。
- **Functional**: Pro ユーザーはテンプレートを無制限に保持できる。
- **Functional**: Pro ユーザーは保存済みテンプレートを現在 timeline へ適用できる。
- **Functional**: Pro ユーザーはテンプレート名を編集できる。
- **Functional**: Pro ユーザーはテンプレートを削除できる。
- **Functional**: Free ユーザーはテンプレート UI を利用できない。
- **Functional**: Free ユーザーがテンプレートボタンを押すと Pro 説明 / paywall へ遷移する。
- **Functional**: Pro から Free へ戻ってもテンプレートデータは削除されない。
- **Functional**: Pro に戻ると既存テンプレートを再び利用できる。
- **Non-Functional**: テンプレート適用で block ID が衝突しない。
- **Non-Functional**: テンプレート適用で直前の現在 timeline を復元できる余地を残す。
- **Non-Functional**: gate は UI 表示だけに依存せず action boundary でも判定する。

## Tasks

### Core-Feat-27: Persistence Foundation

1. Drift schema に template / template blocks テーブルを追加し、migration を作成する。
2. `TimelineTemplateRepository` または同等の repository を追加する。
3. 現在 `TimelineState` から template を作成する処理を実装する。
4. template から fresh block IDs を持つ `TimelineState` を復元する処理を実装する。
5. template list / rename / delete の repository API を実装する。
6. repository test を追加する。

### Core-Enhance-28: Apply Flow

1. template から復元した `TimelineState` を現在 timeline へ適用する service / notifier 境界を作る。
2. 適用前確認 UI から呼び出せる action を用意する。
3. 適用前または適用後に snapshot を作成し、復元余地を確保する。
4. 適用後に transient UI state をクリアする。
5. autosave と current plan 更新の順序を整理する。
6. apply flow の targeted test を追加する。

### UI-Feat-29: Management UI

1. 編集画面に template button を追加する。
2. template sheet を追加する。
3. sheet で保存、一覧、適用、rename、delete を操作できるようにする。
4. apply confirmation を表示する。
5. empty state / long title / many templates の表示を整える。
6. widget test と manual viewport check を追加する。

### Core-Enhance-30: Pro Gate Integration

1. `Core-Feat-19` の effective Pro 判定を参照する。
2. Free では template button から Pro 説明 / paywall へ遷移する。
3. Free では保存・適用・編集・削除 action を action boundary で拒否する。
4. Pro ではテンプレートを無制限に作成・保存・適用・編集・削除できるようにする。
5. Pro から Free へ戻っても template data を削除しないことを保証する。
6. gate test を追加する。
7. 実装後、persistence reference、timeline editor guide、README を更新する。

## Test Plan

- Repository test
  - template 作成
  - template list
  - template rename
  - template delete
  - template apply 用 `TimelineState` 復元
  - 復元時に block ID が fresh になること
  - 空 blocks template
  - action / actionPoint 混在 template
- Gate test
  - Free では save / apply / rename / delete action が実行されない
  - Pro では save / apply / rename / delete action が実行できる
  - Pro から Free へ戻っても template data が削除されない
  - Pro 復帰後に既存 template が再利用できる
- Widget test
  - Free で template button 押下時に Pro 説明 / paywall へ遷移する
  - Pro で template button 押下時に template sheet が開く
  - template sheet に保存済み template が表示される
  - apply confirmation が表示される
  - apply 後に current timeline が template 内容へ置き換わる
  - rename / delete UI が repository 結果へ反映される
- Manual test
  - Android / iOS 相当の narrow viewport で template sheet が破綻しない
  - 長い title / 空 title / 多数 blocks で一覧が読める
  - Pro override を使って Free / Pro の挙動を切り替えて確認する

## Deployment / Rollout

- schema migration を伴うため、既存 database からの起動確認を行う。
- 既存 `plans` / `plan_blocks` / `plan_snapshots` は削除しない。
- gate 実装が未完成の場合、template button は hidden または Pro 説明 / paywall のみへ接続し、template mutation action を開放しない。
- 不具合時は template button を feature flag 相当の条件で隠し、基本編集機能へ戻せるようにする。
