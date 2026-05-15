---
title: Block Pin Type Toggle
status: proposed
draft_status: n/a
created_at: "2026-05-15"
updated_at: "2026-05-15"
references:
  - TODO.md
  - _docs/intent/medo/reverse_timeline_interaction_model.md
  - _docs/intent/medo/action_buffer_time.md
  - _docs/intent/medo/calendar_export_ics.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/reference/medo/persistence_repository_reference.md
related_issues: []
related_prs: []
---

## Overview

edit sheet から、選択中の行動を「ブロック」と「ピン」の間で切り替えられるようにする。

この変更の中心は UI ではなく、`Block` が持つ raw action 設定値と、逆算・表示・export に使う effective 値の分離である。ピン化した行動は timeline 上では 0 分の節目として振る舞うが、ブロックへ戻したときに、ユーザーが以前設定した所要時間と余裕時間を復元できるようにする。

## Scope

- `BlockType.action` と `BlockType.actionPoint` の切り替え API を追加する。
- `actionPoint` でも `duration` / `bufferMinutes` の raw 値を保持できるよう、`Block` の意味を整理する。
- edit sheet に、選択中 block の type を切り替える操作を追加する。
- plan / template / snapshot の永続化では raw 値を保持し、計算・表示・export では effective 値を使う境界を確認する。
- `actionPoint` は引き続き timeline 上の 0 分イベントとして扱う。

## Non-Goals

- `Pin` という新しい独立モデルは追加しない。
- Drift schema migration は行わない。既存の `duration` / `buffer_minutes` カラムを使う。
- ブロックをピン化したときに、前後 block の duration を自動補正して総所要時間を維持する機能は扱わない。
- ピンに余裕時間 UI を表示したり、ピン状態で buffer を編集したりしない。
- Pro / Free の buffer gate は既存仕様を維持する。

## Domain Model

現状の `Block` コメントは `duration // 0 for actionPoint`、`bufferMinutes // action only` と読めるが、この機能では次の意味へ更新する。

- `duration`: action として振る舞うときの raw 所要時間設定。
- `bufferMinutes`: action として振る舞うときの raw desired buffer 設定。
- `normalizedBufferMinutes`: 現在の type と duration に対して、表示・計算に使える effective buffer。
- `effectiveDuration`: timeline 逆算で消費する時間。`action` は `duration + normalizedBufferMinutes`、`actionPoint` は常に `0`。

`actionPoint` の raw `duration` / `bufferMinutes` は復元用設定として保持され得る。これは「ピンが時間を消費する」という意味ではない。

## State API

`TimelineNotifier` に type 切替専用 API を追加する。

- `setBlockType(String id, BlockType type)` または同等の明示的 API とする。
- `action -> actionPoint` では `duration` / `bufferMinutes` を破棄しない。
- `actionPoint -> action` では保持済み `duration` が 5 分未満または 0 の場合だけ、既定値 15 分へ補正する。
- `bufferMinutes` は raw desired value として保持する。ただし `action` 復帰時の effective buffer は既存の `normalizeActionBufferMinutesForDuration` に従う。
- title / colorIndex / id / order は切り替えで変えない。

## Edit Sheet UI

edit sheet の block 編集状態に、ブロック / ピンを切り替える segmented control 相当の導線を追加する。

- 対象は `selected != null` の block のみ。target anchor には表示しない。
- 現在 type を視覚的に示す。
- ピン化すると、所要時間と余裕時間の editor は非表示になる。
- ブロックへ戻すと、保持していた所要時間と余裕時間が editor に復元される。
- UI 文言は、ピンが「時間を消費しない節目」であることを示す。ただし長い説明文で sheet を圧迫しない。

## Persistence and Export Boundaries

既存 schema は `type`, `duration`, `buffer_minutes` を保存しているため、schema migration は不要とする。

- plan / template / snapshot は raw `duration` / `bufferMinutes` を保存する。
- `computeBlocks()`、総所要時間、timeline 表示、text/image/calendar export は `effectiveDuration` / `normalizedBufferMinutes` を使う。
- `actionPoint` の calendar export は 0 分イベントのまま維持する。
- template restore 時に fresh block id を付与しても、raw 設定値は保持する。

## Requirements

- **Functional**: edit sheet から action / actionPoint を切り替えられる。
- **Functional**: action から actionPoint へ切り替えても raw duration / bufferMinutes は失われない。
- **Functional**: actionPoint から action へ戻すと、以前の所要時間と余裕時間が復元される。
- **Functional**: actionPoint の `effectiveDuration` は常に 0 のまま。
- **Functional**: actionPoint は export 上も 0 分イベントのまま。
- **Non-Functional**: Drift migration を増やさない。
- **Non-Functional**: existing plan / template / snapshot の読み込み互換を保つ。
- **Non-Functional**: buffer の Pro gate と desired/effective 分離を壊さない。

## Test Plan

- Unit: `Block.copyWith(type: BlockType.actionPoint)` 相当の type 切替で raw `duration` / `bufferMinutes` が保持され、`effectiveDuration` と `normalizedBufferMinutes` は 0 になる。
- Unit: actionPoint から action へ戻したとき、保持済み duration / buffer が effective 値として復元される。
- Unit: duration が 0 の古い actionPoint を action に戻す場合、duration は 15 分へ補正される。
- Unit: `computeBlocks()` で actionPoint は raw duration を持っていても timeline 時間を消費しない。
- Persistence: plan / template / snapshot が actionPoint の raw `duration` / `bufferMinutes` を round-trip できる。
- Widget: edit sheet の切替 UI で所要時間 / 余裕時間 editor の表示が type に応じて切り替わる。
- Export: calendar/text/image export が actionPoint を 0 分として扱い続ける。

## Documentation

実装後に次を同期する。

- `_docs/intent/medo/action_buffer_time.md`: `actionPoint` の buffer は「effective 0」だが raw desired value は復元用に保持され得る、という表現へ更新する。
- `_docs/intent/medo/reverse_timeline_interaction_model.md`: domain model は引き続き 2 type だが、raw action settings と effective timeline behavior を区別する。
- `_docs/guide/medo/timeline_editor.md`: edit sheet からのブロック / ピン切替を追記する。
- `_docs/reference/medo/timeline_domain_reference.md`: `Block` 各フィールドの意味を更新する。
- `_docs/reference/medo/persistence_repository_reference.md`: persistence は raw settings を保持することを明記する。

## Rollback

問題が出た場合は edit sheet の切替 UI と `TimelineNotifier` の type 切替 API 呼び出しを外す。raw 値保持の model 整理は既存データを破壊しないため、保持しても既存挙動への影響は小さい。
