---
title: Timeline Alternative Comparison
status: proposed
draft_status: n/a
created_at: "2026-05-10"
updated_at: "2026-05-10"
references:
  - TODO.md
  - _docs/archives/plan/UI/timeline-slot-toggle.md
  - _docs/archives/plan/Core/action-buffer-time.md
  - _docs/archives/plan/Core/pro-free-gate.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/persistence_repository_reference.md
  - _docs/reference/medo/timeline_domain_reference.md
related_issues: []
related_prs: []
---

## Overview

Medo に、同じ予定に対する複数の候補案を作り、2列で見比べて採用・編集できる比較モードを追加する。

既存の timeline list island modal は「別々の予定を保存して切り替える棚」である。一方、本機能は「同じ目的に対して、どの案で進めるかを決めるための比較」であり、単なる保存済み timeline の切り替えとは別概念として扱う。

比較ビューは編集不可の read-only 表示とする。各列は時間に応じた block 長を維持し、左右で同じ time scale を共有する。ユーザーは列ごとの `採用` / `編集` から、比較した案を本命にするか、単独編集画面で調整する。

## Decisions

- 比較機能は Pro 機能として扱う。
- 比較対象は「同じ予定の候補案」であり、単なる保存済み timeline 一覧ではない。
- 初期実装の比較ビューは 2 列表示に限定する。
- 比較ビューでは直接編集しない。
- 各列に `採用` と `編集` の action を置く。
- `採用` は、その案を比較セットの本命として扱い、current plan として開ける状態にする。
- `編集` は、その案を通常の単独 timeline editor で開く。
- block 長は `duration + bufferMinutes` に基づく時間比例を維持する。
- 左右の `pixelsPerMinute` は共有する。
- target anchor は左右で揃える。
- action buffer の合計と内訳を比較指標として使うため、`Core-Feat-37` の action-level buffer time を前提にする。
- timeline list island modal の中で単なる「別の timeline」として比較を完結させない。入口文言は `この予定の別案を作る` / `比較する` のように、同一予定の候補であることを明示する。

## Scope

- 現在の timeline から比較案を作る導線を追加する。
- 現在の timeline を複製して、fresh block IDs を持つ別案 plan を作成する。
- 既存 `plans` を各案の実体として使い、比較セット / 比較案 membership を追加する。
- 比較セット内の2案を read-only で2列表示する comparison view を追加する。
- 各案の開始時刻、目標時刻、行動時間、buffer 合計、逆算消費時間、block 数を summary として表示する。
- 各案に `採用` / `編集` action を置く。
- 比較ビューで左右の time scale と target anchor を揃える。
- 比較ビューで action buffer のバッファセグメント表示を維持する。
- Pro / Free の gate と downgrade 時のデータ保持方針を実装する。
- 実装後、timeline editor guide と persistence reference を更新する。

## Non-Goals

- 比較ビュー内での block 編集。
- 比較ビュー内での drag / reorder / duration edit / buffer edit。
- 3列以上の同時比較。
- 自動で最適案を判定する AI / heuristic。
- 交通手段や外部経路検索との連携。
- 複数端末同期やクラウド保存。
- 比較案をカレンダーへ直接一括登録する導線。
- 既存 timeline list island modal の置き換え。
- Free への縮退時に比較案 data を削除する処理。

## Concept Boundaries

### Timeline List

timeline list は、複数の独立した予定を保存・切り替え・命名・削除するための場所である。

例:

- 朝の準備
- 通勤
- 病院に行く
- 旅行出発

ユーザーの目的は「保存済み timeline から今使うものを開く」ことである。

### Alternative Comparison

comparison は、同じ予定に対する候補案を比べるための場所である。

例:

- 電車案 / 車案
- 最短案 / 余裕あり案
- 8:30到着案 / 9:00到着案

ユーザーの目的は「どの案で進めるか決める」ことである。

この境界を崩すと、比較機能は timeline list の焼き直しになる。UI 文言、入口、データモデル、画面構成のすべてで「同一予定の候補案」を明示する。

## Data Model

既存の `plans` は各比較案の実体として再利用する。比較機能用には、plan 同士を「同じ予定の候補」として結びつける membership を追加する。

推奨 schema:

- `timeline_comparison_sets`
  - `id`
  - `title`
  - `primary_plan_id`
  - `created_at`
  - `updated_at`
- `timeline_comparison_variants`
  - `id`
  - `comparison_set_id`
  - `plan_id`
  - `label`
  - `position`
  - `created_at`
  - `updated_at`

`plans` には引き続き timeline の実体を持たせる。comparison set は、同じ予定として比較するための grouping metadata とする。

初期 UI は2案比較に限定するが、schema は将来の3案以上や pair picker に耐えられる形にしてよい。ただし初期 scope では、同時表示は2列までに制限する。

### Fork / Clone

`この予定の別案を作る` は、現在 plan を複製して新しい plan を作る。

- block IDs は fresh にする。
- snapshot / current UI transient state はコピーしない。
- bufferMinutes はコピーする。
- plan title / target title / target time / blocks はコピーする。
- comparison set がなければ作成し、現在 plan と複製 plan を variants として登録する。
- comparison set が既にある場合は、現在 plan と複製 plan の membership を追加または更新する。

## Interaction Model

### Entry Points

初期導線は、現在 timeline の文脈から入る。

- `この予定の別案を作る`
- `比較する`

timeline list island modal へ単に項目を足す場合でも、文言は `新しいタイムライン` ではなく `この予定の別案を作る` とし、既存の保存・切替導線と混同させない。

### Create Alternative

1. ユーザーが現在の timeline から `この予定の別案を作る` を実行する。
2. 現在 plan を保存 flush する。
3. 現在 plan を複製して、別案 plan を作成する。
4. comparison set に現在 plan と別案 plan を登録する。
5. 初期案名を `案A` / `案B`、または `最短案` / `余裕あり案` のような編集可能 label として表示する。
6. 作成後は、別案を単独 editor で開くか、comparison view へ遷移する。初期実装では、ユーザーが差分を作りやすいよう別案を単独 editor で開くことを推奨する。

### Comparison View

comparison view は2列の read-only 表示とする。

- 左右に比較対象の variant を表示する。
- 各列上部に summary を置く。
- target anchor は左右で同じ垂直位置に揃える。
- time scale は左右で共有する。
- block height は `duration + bufferMinutes` に比例する。
- バッファセグメントは `Core-Feat-37` の visual model に従い、block 内に表示する。
- 長い timeline では縦スクロールを許容し、左右の scroll offset を同期する。
- 横幅が狭い場合は block 内 text を最小限にし、詳細は `編集` から単独 editor で確認する。

summary には少なくとも以下を表示する。

- 案名
- 開始時刻
- 目標時刻
- 行動時間合計
- buffer 合計
- 逆算消費時間合計
- block 数

### Adopt / Edit

各列には `採用` と `編集` を置く。

- `採用`
  - 対象 variant を comparison set の `primary_plan_id` にする。
  - 対象 plan を current plan として保存する。
  - comparison view から通常 editor へ戻るか、採用済み状態を表示する。
  - 他の variant は削除しない。
- `編集`
  - 対象 plan を current plan として開き、通常 editor へ遷移する。
  - comparison view 内では編集しない。

`採用` は「この案を本命にする」という意味を持つ。単なる「開く」と見える文言は避ける。

## Visual Model

2列表示は、通常 editor の縮小版ではなく comparison 専用 view とする。

- 操作対象を減らし、読むことと採用判断に集中する。
- duration handle、reorder handle、inline editor は表示しない。
- block title は短く省略できる。
- 時刻、duration、buffer は比較に必要な最小限を表示する。
- actionPoint は時間を消費しない marker として軽く表示する。
- target anchor は左右で揃え、逆算開始時刻の差が見えるようにする。

UI の優先順位は以下とする。

1. 開始時刻と目標時刻の差が分かること
2. buffer 合計と配置が分かること
3. 長い action の重さが分かること
4. `採用` / `編集` が迷わず押せること
5. 詳細編集は通常 editor に逃がすこと

## Pro / Free Behavior

- Pro は比較セット作成、別案作成、comparison view 表示、採用、編集遷移を利用できる。
- Free は新しい比較セットや別案を作成できない。
- Pro 中に作成した comparison set / variants は Free に戻っても削除しない。
- Free では既存 comparison view を開けない、または read-only preview に制限する。初期実装では Paywall へ誘導する方針を推奨する。
- Free に戻っても、variant の実体である plan は通常の timeline data として保持する。
- Free の timeline 2件制限と競合する場合は、既存 timeline list の縮退方針に従い、データは削除しない。

比較機能は Pro 機能だが、解約によりユーザーの作成済み plan が消えることは避ける。

## Requirements

- **Functional**: 現在 plan から別案 plan を作成できる。
- **Functional**: 別案作成時、block IDs は fresh になる。
- **Functional**: 別案作成時、bufferMinutes は保持される。
- **Functional**: comparison set は同じ予定の候補案として複数 plan を束ねられる。
- **Functional**: comparison view は2案を read-only で並べて表示できる。
- **Functional**: 左右の time scale は共有される。
- **Functional**: target anchor は左右で揃う。
- **Functional**: block height は `duration + bufferMinutes` に比例する。
- **Functional**: 各案の summary に開始時刻、目標時刻、行動時間合計、buffer 合計、逆算消費時間合計、block 数を表示する。
- **Functional**: 各列から `採用` できる。
- **Functional**: 各列から通常 editor へ `編集` に入れる。
- **Functional**: 採用しても他の variant は削除されない。
- **Functional**: Free では comparison の新規作成・利用が gate される。
- **Non-Functional**: comparison view では既存 editor の gesture を持ち込まない。
- **Non-Functional**: timeline list island modal と比較機能の役割が UI 文言で区別される。
- **Non-Functional**: migration は既存 `plans` / `plan_blocks` / `plan_snapshots` を破壊しない。
- **Non-Functional**: 比較機能は `Core-Feat-37` の buffer model を前提にする。

## Tasks

1. comparison set / variant の repository と persistence schema を追加する。
2. 現在 plan を fresh IDs で複製する helper を追加する。
3. `この予定の別案を作る` 導線を追加し、comparison set 作成と別案 plan 作成へ接続する。
4. comparison view の route / screen を追加する。
5. 2列 read-only timeline renderer を作り、左右で time scale と target anchor を共有する。
6. action buffer を含む summary 計算を実装する。
7. `採用` / `編集` action を実装する。
8. Pro / Free gate と downgrade 時のデータ保持方針を実装する。
9. repository / widget / gesture / downgrade tests を追加する。
10. timeline editor guide と persistence reference を更新する。

## Test Plan

- Repository
  - current plan から別案 plan を作成できる。
  - 複製後の block IDs が元 plan と重複しない。
  - bufferMinutes が複製される。
  - comparison set が variants を束ねる。
  - primary variant を更新できる。
  - plan 削除時の comparison membership が破綻しない。

- Summary / calculation
  - action duration 合計、buffer 合計、effective duration 合計が正しい。
  - 開始時刻が target time と effective duration から正しく出る。
  - 左右で同じ `pixelsPerMinute` が使われる。

- Widget
  - comparison view が2列で表示される。
  - target anchor が左右で揃って見える。
  - `採用` で primary / current plan が更新される。
  - `編集` で対象 plan が通常 editor に開かれる。
  - comparison view では block edit / reorder / duration drag ができない。
  - narrow viewport で summary と action buttons が破綻しない。

- Pro / Free
  - Pro では別案作成と comparison view 表示ができる。
  - Free では別案作成が Paywall に誘導される。
  - Pro から Free に戻っても comparison set / plans は削除されない。

## Deployment / Rollout

- schema migration があるため、既存 database からの起動確認を行う。
- 初期 rollout では比較ビューを2案に限定し、3案以上の比較は後続計画に回す。
- UI が狭い端末で破綻する場合は、comparison view を card summary 優先に縮退し、2列 timeline renderer を feature flag 相当で無効化できるようにする。
- 比較機能はローカル保存の範囲で実装する。クラウド送信範囲は変えないが、後続で同期や共有リンクを追加する場合は `_docs/guide/medo/privacy_policy_operations.md` に従い privacy policy 更新要否を確認する。
