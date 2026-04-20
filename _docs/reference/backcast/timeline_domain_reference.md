---
title: Backcast Timeline Domain Reference
status: active
draft_status: n/a
created_at: 2026-04-20
updated_at: 2026-04-20
references:
  - README.md
  - _docs/guide/backcast/timeline_editor.md
  - _docs/intent/backcast/reverse_timeline_interaction_model.md
related_issues: []
related_prs: []
---

## Overview

本リファレンスは、`Backcast` の逆算タイムラインを構成するモデル、定数、状態管理 API の現状仕様をまとめたものです。
対象は主に `lib/models.dart` と `lib/state.dart` で、UI 側から参照されるドメインルールを中心に記述します。

## API

### Constants in `lib/models.dart`

- **Summary**: タイムライン表示と編集に使う定数群
- **Parameters**: なし
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - `kPixelsPerMinute = 6.0`: 1 分あたり 6px としてブロック高さを計算
  - `kSnapMinutes = 5`: 通常ドラッグ時のスナップ粒度
  - `kTargetTimeId = 'target-time'`: 目標アンカーの選択状態識別子

### `enum BlockType`

- **Summary**: ブロック種別を表す列挙型
- **Parameters**: なし
- **Returns**: `BlockType.action` または `BlockType.actionPoint`
- **Errors**: なし
- **Examples**:
  - `action`: 所要時間を持つ行動
  - `actionPoint`: 所要時間 0 分の通過点

### `class Block`

- **Summary**: タイムライン上の 1 要素を表す不変モデル
- **Parameters**:
  - `id (String)`: ブロック識別子
  - `type (BlockType)`: 行動か行動ポイントか
  - `title (String)`: 表示名
  - `duration (int)`: 分単位の所要時間。`actionPoint` では 0 を想定
  - `colorIndex (int)`: `AppColors.blockColors` を参照するためのインデックス
- **Returns**: `copyWith` で差分更新済みの新しい `Block`
- **Errors**: モデル自体はバリデーション例外を投げない
- **Examples**:
  - `Block(id: '1', type: BlockType.action, title: '移動', duration: 30, colorIndex: 0)`

### `class ComputedBlock`

- **Summary**: `Block` に対して逆算結果の `startTime` / `endTime` を付与した派生モデル
- **Parameters**:
  - `block (Block)`: 元ブロック
  - `startTime (int)`: 当該ブロックの開始時刻
  - `endTime (int)`: 当該ブロックの終了時刻
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - 30 分の `action` が 13:00 の直前にある場合、`startTime = 12:30`, `endTime = 13:00`

### `List<ComputedBlock> computeBlocks(List<Block> blocks, int targetTime)`

- **Summary**: 目標時刻から逆向きに各ブロックの開始・終了時刻を計算する純粋関数
- **Parameters**:
  - `blocks (List<Block>)`: 過去から未来方向に並んだブロック列
  - `targetTime (int)`: 分単位の目標時刻
- **Returns**: `blocks` と同順で並ぶ `ComputedBlock` の配列
- **Errors**: 例外は投げない。負の時刻も内部的には保持し、表示時に `formatTime` 側で 24 時間に正規化する
- **Examples**:
  - `targetTime = 13:00`, `30 分` と `20 分` の 2 ブロックなら、先頭ブロックは `12:10` 開始になる

### `String formatTime(int minutes)`

- **Summary**: 分単位の時刻を `HH:mm` 形式へ整形する
- **Parameters**:
  - `minutes (int)`: 0 未満や 24 時間超も許容
- **Returns**: 24 時間表記に正規化された文字列
- **Errors**: なし
- **Examples**:
  - `formatTime(780) -> "13:00"`
  - `formatTime(-60) -> "23:00"`
  - `formatTime(25 * 60) -> "01:00"`

### `class TimelineState`

- **Summary**: 逆算タイムライン全体の UI 状態
- **Parameters**:
  - `targetTime (int)`: 目標時刻。初期値は `13 * 60`
  - `targetTimeTitle (String)`: 目標ラベル。初期値は `目標時刻`
  - `blocks (List<Block>)`: タイムライン本体
  - `selectedBlockId (String?)`: `null | kTargetTimeId | block.id`
  - `preciseDraggingId (String?)`: precise ドラッグ中のブロック ID
- **Returns**: `copyWith` で新状態を生成
- **Errors**: なし
- **Examples**:
  - 選択中の目標アンカーは `selectedBlockId == kTargetTimeId`

### `class TimelineNotifier`

- **Summary**: `TimelineState` を操作する Riverpod `Notifier`
- **Parameters**: なし
- **Returns**: `build()` で初期状態を返す
- **Errors**: 不正 ID や範囲外操作は例外化せず無視するメソッドが多い
- **Examples**:
  - 初期状態では `移動` という 30 分の `action` が 1 件入る

### `TimelineNotifier.setTargetTime(int minutes)`

- **Summary**: 目標時刻を更新する
- **Parameters**:
  - `minutes (int)`: 分単位の新しい目標時刻
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - `13:30` は `810`

### `TimelineNotifier.setTargetTimeTitle(String title)`

- **Summary**: 目標ラベルを更新する
- **Parameters**:
  - `title (String)`: 新しい表示名
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - `出発時刻`, `会議開始` など任意文字列を設定できる

### `TimelineNotifier.addBlock(int index, BlockType type)`

- **Summary**: 指定位置へ新しいブロックを挿入する
- **Parameters**:
  - `index (int)`: `state.blocks` 上の挿入位置
  - `type (BlockType)`: `action` または `actionPoint`
- **Returns**: なし
- **Errors**: インデックス異常系の明示例外はない
- **Examples**:
  - `action` は初期タイトル `新しい行動`, 初期所要時間 15 分
  - `actionPoint` は初期タイトル `新しい行動ポイント`, 所要時間 0 分
- **Notes**:
  - 色は近傍ブロックと同色が続きにくいようランダム選択する

### `TimelineNotifier.updateBlock(String id, Block Function(Block) updater)`

- **Summary**: 該当 ID のブロックを関数型アップデータで置き換える
- **Parameters**:
  - `id (String)`: 更新対象ブロック ID
  - `updater (Block Function(Block))`: 差分更新関数
- **Returns**: なし
- **Errors**: ID 不一致時は実質的に無変更
- **Examples**:
  - タイトル変更、所要時間変更、色変更などに利用可能

### `TimelineNotifier.deleteBlock(String id)`

- **Summary**: ブロックを削除し、選択状態を解除する
- **Parameters**:
  - `id (String)`: 削除対象
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - 将来 UI から削除操作を接続する前提の内部 API
- **Notes**:
  - 現状 UI からは呼ばれていない

### `TimelineNotifier.moveBlock(String id, BlockMoveDirection direction)`

- **Summary**: 1 つ前後へブロックを移動する簡易 API
- **Parameters**:
  - `id (String)`: 対象ブロック ID
  - `direction (BlockMoveDirection)`: `toPast` または `toFuture`
- **Returns**: なし
- **Errors**: 範囲外移動は無視
- **Examples**:
  - キーボード移動やボタン移動のような将来 UI と相性がよい
- **Notes**:
  - 現状の UI では主に `moveBlockByIndex` が使用される

### `TimelineNotifier.moveBlockByIndex(int fromIndex, int toIndex)`

- **Summary**: インデックスベースでブロック順を入れ替える
- **Parameters**:
  - `fromIndex (int)`: 移動元
  - `toIndex (int)`: 移動先
- **Returns**: なし
- **Errors**: `fromIndex` 範囲外は無視
- **Examples**:
  - `SliverReorderableList` の `onReorder` から呼ばれる

### `TimelineNotifier.reorderBlock(String id, int insertBefore)`

- **Summary**: 指定 ID のブロックを `insertBefore` 位置へ差し込む補助 API
- **Parameters**:
  - `id (String)`: 移動対象
  - `insertBefore (int)`: 差し込み先
- **Returns**: なし
- **Errors**: ID 不一致は無視
- **Examples**:
  - DnD 実装差し替え時にも使いやすい構造
- **Notes**:
  - 現状の UI では未使用

### `TimelineNotifier.setPreciseDragging(String? id)`

- **Summary**: precise ドラッグ中のブロックを記録する
- **Parameters**:
  - `id (String?)`: precise モード中はブロック ID、解除時は `null`
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - 影響を受けるブロックの枠線を強調するために使う

### `TimelineNotifier.applyDurationDrag(String id, double deltaY, int startDuration, bool isPrecise)`

- **Summary**: ドラッグ量から所要時間を再計算する
- **Parameters**:
  - `id (String)`: 更新対象ブロック
  - `deltaY (double)`: ドラッグ開始位置からの Y 差分
  - `startDuration (int)`: ドラッグ開始時の所要時間
  - `isPrecise (bool)`: `true` のとき 1 分刻み、それ以外は 5 分刻み
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - 上方向ドラッグで所要時間が増え、下方向で減る
- **Notes**:
  - 最小値は 5 分に丸められる

### `TimelineNotifier.applyStartTimeEdit(String id, int newStartTimeMinutes)`

- **Summary**: 任意ブロックの開始時刻を直接編集したときに、該当ブロックまたは次ブロックを調整する内部 API
- **Parameters**:
  - `id (String)`: 編集対象ブロック
  - `newStartTimeMinutes (int)`: 新しい開始時刻
- **Returns**: なし
- **Errors**: ID 不一致は無視
- **Examples**:
  - `action` では自身の `duration` を調整する
  - `actionPoint` では末尾なら `targetTime`、途中なら次ブロックの `duration` を調整する
- **Notes**:
  - 現状 UI からは未接続だが、開始時刻直接編集機能を追加する際の中核ロジック

### Providers

- **Summary**: UI から利用する Riverpod Provider 群
- **Parameters**: なし
- **Returns**:
  - `timelineProvider`: `NotifierProvider<TimelineNotifier, TimelineState>`
  - `computedBlocksProvider`: `Provider<List<ComputedBlock>>`
- **Errors**: なし
- **Examples**:
  - 画面は `timelineProvider` で状態を読み、`computedBlocksProvider` で表示用時刻を得る

## Notes

- 現状の状態は永続化されず、プロセス存続中のみ保持される
- `firstOrNull` は Dart SDK の拡張メソッドを利用している
- `test/widget_test.dart` では `computeBlocks`、`formatTime`、画面スモークテストを実施している
