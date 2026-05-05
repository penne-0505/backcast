---
title: Timeline List Management
status: proposed
draft_status: n/a
created_at: "2026-05-02"
updated_at: "2026-05-02"
references:
  - TODO.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/persistence_repository_reference.md
  - _docs/intent/medo/drift_persistence_repository.md
related_issues: []
related_prs: []
---

## Overview

複数タイムライン機能を、既存の `plans` を日常的に扱う「タイムライン一覧」として実装する。

ユーザーは複数のタイムラインを保存し、floating button から一覧 UI を開いて切り替えられる。各タイムラインには名前を付けられ、現在のタイムライン名はヘッダー付近でインライン編集できる。

初期リリースでは Free は最大2つ、Pro は無制限とする。固定2スロットや toggle 専用 UI ではなく、将来の利用実態にも耐える list-first の設計にする。

## Decision

- Free の保持数上限は2つ、Pro の保持数上限は無制限とする。
- floating button は timeline list を開く入口とする。
- Free でも floating button を表示する。Free でも2つまで作成・切り替えできるため、使えない UI ではない。
- Free が2つ保持済みの場合、一覧内の新規作成は無効化し、必要なら控えめな Pro 導線を一覧内に置く。
- Pro では一覧から任意個数のタイムラインを作成・選択できる。
- Pro から Free へ戻った場合、超過分のタイムラインは削除しない。Free 中は利用可能な範囲へ縮退し、Pro 復帰時に再び全件利用できるようにする。

## Existing Implementation Notes

- 現在の永続化基盤には `plans`, `plan_blocks`, `plan_snapshots` がある。
- `plans.title` は既にプラン名として存在し、今回のタイムライン名に転用できる。
- `PlanRepository.listPlans()` は `updatedAt` 降順の summary list を返すため、一覧 UI の初期表示に利用できる。
- `currentPlanIdProvider` は runtime state であり、再起動後に現在 plan を復元する永続情報はまだない。
- `TimelineScreen` は起動時に `PlanRepository.listPlans()` の先頭、つまり `updatedAt` 降順の最新 plan を読み込む。
- `TimelineState` には `selectedBlockId`, `preciseDraggingId`, `activeInlineEditorId`, `pixelsPerMinute` などの一時 UI 状態が含まれるが、永続化では除外されている。

## Scope

- floating button から開く timeline list UI を追加する。
- list UI から既存 timeline を選択して切り替えられるようにする。
- list UI から新規 timeline を作成できるようにする。
- Free / Pro の保持数上限を作成導線へ反映する。
- 起動時に最後に開いていた plan を復元する。
- タイムライン名をヘッダー付近に表示し、インライン編集できるようにする。
- 切り替え前に現在 plan の未保存変更を保存してから、次の plan を読み込む。
- existing `PlanPanel` から plan を load する場合は、現在 plan の永続設定も合わせて更新し、timeline list と矛盾しないようにする。
- 実装後、timeline editor guide と persistence reference を更新する。

## Non-Goals

- 固定 slot モデル。
- toggle のみで完結する2件専用 UI。
- list 内での並び替え。
- timeline 削除 UI。
- snapshot / history UI の再設計。
- 複数端末同期やクラウド保存。
- Free 超過分の自動削除。

## Data Model

固定 slot は追加しない。既存の `plans` を timeline list の source of truth とする。

追加または同等の永続設定として、最後に開いていた plan を保存する。

- `app_preferences` または同等の設定保存
  - `currentPlanId`: 最後に開いていた `plans.id`

実装者は同等の安定性を満たす別設計を選んでもよいが、以下は必須とする。

- 現在 plan が再起動後に復元される。
- `plans` / `plan_blocks` / `plan_snapshots` の既存データを破壊しない。
- Free から Pro、Pro から Free への変化で timeline data を削除しない。
- Free の作成上限は2件、Pro の作成上限は無制限として判定できる。

## Entitlement Model

- `isProProvider` を Pro 判定の source of truth とする。
- `billingProvider` が loading / error の間は Free 相当として扱う。
- Free では timeline count が2未満の場合のみ新規作成できる。
- Free で timeline count が2以上の場合、新規作成は無効化する。
- Pro では timeline count による新規作成制限を設けない。
- Pro から Free へ戻り、既存 timeline が3件以上ある場合も削除しない。
- Free へ戻った場合の利用可能範囲は実装時に明示する。推奨は、現在開いている timeline と直近利用 timeline を優先して2件を利用可能にし、残りは保持したまま Pro 復帰まで選択不可にすること。

## Interaction Model

### Header Timeline Name

- ヘッダー付近に現在のタイムライン名を表示する。
- タップまたは既存 inline edit パターンに沿って編集できる。
- 編集対象は `plans.title` とする。
- 空文字または whitespace のみの場合は `無題のタイムライン` に正規化する。
- `targetTimeTitle` とは別概念として扱う。

### Floating List Button

- Free / Pro ともに表示する。
- 表示位置は既存の floating toolbar と競合しないようにする。
- tap で timeline list UI を開く。
- list には現在 timeline、timeline name、target title、target time、block count、updated time を表示する。
- current timeline は選択状態として分かるようにする。
- list から別 timeline を選ぶと、その timeline へ切り替える。
- list から新規 timeline を作成できる。
- Free が上限到達済みの場合、新規作成 affordance は disabled にする。
- list 表示中や切替中は多重 tap を無効化する。
- 切替後は `selectedBlockId`, `activeInlineEditorId`, `preciseDraggingId` などの一時 UI 状態をクリアする。

### Save / Load Ordering

- timeline 切替前に現在 plan の debounce 保存を flush する。
- flush 完了後に `currentPlanIdProvider` と persisted `currentPlanId` を更新し、選択した plan の `TimelineState` を load する。
- 切替中に自動保存 listener が旧 plan に書き戻さないよう、保存対象 plan id と load timing を明示的に制御する。

## Requirements

- **Functional**: Free ユーザーは最大2つのタイムラインを保持できる。
- **Functional**: Pro ユーザーはタイムラインを無制限に保持できる。
- **Functional**: Free / Pro ともに floating button から timeline list を開ける。
- **Functional**: timeline list から既存 timeline を選択して切り替えられる。
- **Functional**: timeline list から新規 timeline を作成できる。
- **Functional**: Free が2件保持済みの場合、新規作成はできない。
- **Functional**: 各タイムラインは独立した名前を持ち、ヘッダー付近でインライン編集できる。
- **Functional**: Pro から Free へ戻っても超過分のデータは削除されない。
- **Functional**: 再起動後、最後に開いていた current plan が復元される。
- **Non-Functional**: list UI は既存の block 追加、inline edit、edit sheet、reorder、pinch zoom と競合しない。
- **Non-Functional**: 切替時に直前の編集が失われない。
- **Non-Functional**: migration は既存 plan データを破壊しない。

## Tasks

1. Drift schema または同等の永続設定を拡張し、`currentPlanId` を保存できるようにする。
2. 起動時の plan 復元を、`updatedAt` 降順の先頭ではなく persisted `currentPlanId` 優先に置き換える。
3. `PlanRepository` または専用 repository に timeline count、canCreateTimeline、create timeline、switch timeline、rename current timeline を追加する。
4. 自動保存 debounce を flush できる境界を作り、timeline 切替前に現在 plan を保存する。
5. ヘッダー付近に timeline name inline editor を追加し、`plans.title` を更新する。
6. floating button から timeline list UI を開けるようにする。
7. timeline list の row 表示、current 表示、select、create、Free 上限到達時の disabled 状態を実装する。
8. `isProProvider` に基づき、Free は2件まで、Pro は無制限として作成可否を制御する。
9. existing `PlanPanel` の load 操作が persisted `currentPlanId` と矛盾しないように統合する。
10. Free / Pro / downgrade / restore Pro の状態遷移を targeted test と手動確認で検証する。
11. 実装後、`_docs/reference/medo/persistence_repository_reference.md` と `_docs/guide/medo/timeline_editor.md` を更新する。

## Test Plan

- Repository test
  - current plan id 保存 / 復元
  - Free count 0 / 1 / 2 の create 可否
  - Pro count 2以上での create 可否
  - timeline 作成後の listPlans 反映
  - timeline 切替前後の plan id と state
  - Pro から Free へ縮退しても超過 timeline が削除されないこと
- Widget test
  - Free / Pro ともに floating list button が表示される
  - tap で timeline list が開く
  - list に timeline name、target title、target time、block count が表示される
  - current timeline が区別される
  - list row tap で切り替わる
  - Free で2件未満なら新規作成できる
  - Free で2件到達済みなら新規作成が disabled になる
  - Pro では2件以上でも新規作成できる
  - header inline edit で timeline name が更新される
  - 切替後に edit sheet / inline editor / selected block が残らない
- Manual test
  - Android / iOS 相当の narrow viewport で floating button と list UI が既存 toolbar と重ならない
  - Pro から Free への entitlement 変化後に超過分が削除されない
  - Free から Pro に戻った後に既存の超過 timeline が再び利用できる
  - 直前に block title / duration / target title を編集してすぐ切り替えても、編集内容が失われない

## Deployment / Rollout

- `currentPlanId` 永続化のために schema migration または同等の設定保存追加が必要な場合、debug build で既存 database からの起動確認を行う。
- migration 前の `plans` は削除しない。
- Free の既存ユーザーには、2件まで作成・切替できる機能として表示される。
- 不具合時は list button の表示を feature flag 相当の条件で止め、既存の単一 current plan 利用に戻せるようにする。
