---
title: Medo Timeline Domain Reference
status: active
draft_status: n/a
created_at: "2026-04-20"
updated_at: "2026-05-02"
references:
  - README.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/intent/medo/reverse_timeline_interaction_model.md
  - _docs/intent/medo/calendar_export_ics.md
  - _docs/intent/medo/local_reminder_notifications.md
  - _docs/reference/medo/calendar_export_reference.md
  - _docs/reference/medo/reminder_notification_reference.md
  - _docs/reference/medo/persistence_repository_reference.md
related_issues: []
related_prs: []
---

## Overview

本リファレンスは、`Medo` の逆算タイムラインを構成するモデル、定数、状態管理 API の現状仕様をまとめたものです。
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

### `enum TimelineViewMode`

- **Summary**: タイムライン画面の表示モードを表す列挙型
- **Parameters**: なし
- **Returns**: `TimelineViewMode.edit` または `TimelineViewMode.compact`
- **Errors**: なし
- **Examples**:
  - `edit`: 時間比例の編集ビュー。ドラッグ並び替え、所要時間調整、インライン編集が可能
  - `compact`: 固定高さ行の俯瞰ビュー。一覧性と並び替えに特化し、直接編集は行わない

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
  - `activeInlineEditorId (String?)`: フォーカス中のインラインエディタ ID
  - `viewMode (TimelineViewMode)`: 表示モード。初期値は `TimelineViewMode.edit`
  - `searchQuery (String)`: 現在の検索クエリ。空文字がデフォルト
  - `searchMatches (List<String>)`: 検索一致したブロック ID のリスト。タイムライン順（過去→目標）
  - `activeSearchMatchIndex (int)`: 現在フォーカスしている一致結果のインデックス。`-1` は不一致
  - `searchHighlightedBlockId (String?)`: 一時ハイライト中のブロック ID
  - `searchHighlightExpiresAt (DateTime?)`: ハイライト自動解除時刻
- **Returns**: `copyWith` で新状態を生成
- **Errors**: なし
- **Examples**:
  - 選択中の目標アンカーは `selectedBlockId == kTargetTimeId`
  - インライン編集中は `activeInlineEditorId != null` になる
  - Compact Overview 表示中は `viewMode == TimelineViewMode.compact` になる
  - 検索 UI state は plan persistence に保存されない

### `class TimelineNotifier`

- **Summary**: `TimelineState` を操作する Riverpod `Notifier`
- **Parameters**: なし
- **Returns**: `build()` で初期状態を返す
- **Errors**: 不正 ID や範囲外操作は例外化せず無視するメソッドが多い
- **Examples**:
  - 初期状態では `移動` という 30 分の `action` が 1 件入る

### `TimelineNotifier.setViewMode(TimelineViewMode mode)`

- **Summary**: 表示モードを切り替える
- **Parameters**:
  - `mode (TimelineViewMode)`: `TimelineViewMode.edit` または `TimelineViewMode.compact`
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - ヘッダーの切り替えボタンから呼ばれる
- **Notes**:
  - Compact Overview から編集ビューに戻る際に `selectBlock` と同時に使われることがある
  - `viewMode` 自体は永続化対象に含めない

### `TimelineNotifier.setSearchQuery(String query)`

- **Summary**: 検索クエリを設定し、`Block.title` の部分一致で結果を更新する
- **Parameters**:
  - `query (String)`: 検索文字列。前後空白は除去され、大文字小文字は無視される
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - 空文字を渡すと一致結果は 0 件になり、active index は `-1` になる
  - 一致結果は `blocks` のタイムライン順（過去→目標）で並ぶ
- **Notes**:
  - 空 query 時はすべての検索 state がクリアされる
  - query 変更時、現在の result index が範囲外になった場合は先頭（`0`）へ戻す

### `TimelineNotifier.clearSearch()`

- **Summary**: 検索状態を完全にクリアする
- **Parameters**: なし
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - 検索バーを閉じる際に呼ばれる

### `TimelineNotifier.nextSearchMatch()` / `prevSearchMatch()`

- **Summary**: 検索一致結果を前後に移動する
- **Parameters**: なし
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - 末尾を超えると先頭へ、先頭より前へ移動すると末尾へ wrap around する

### `TimelineNotifier.highlightSearchBlock(String? blockId)`

- **Summary**: 指定ブロックを一時ハイライト状態にする
- **Parameters**:
  - `blockId (String?)`: ハイライト対象ブロック ID。`null` で解除
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - 検索ジャンプ後に 3 秒間のハイライトを設定する
- **Notes**:
  - `selectedBlockId` とは別の state として管理され、詳細編集シートは自動表示されない
  - `searchHighlightExpiresAt` に 3 秒後の時刻が設定される

### `TimelineNotifier.expireSearchHighlightIfNeeded()`

- **Summary**: ハイライト期限が切れていれば自動解除する
- **Parameters**: なし
- **Returns**: なし
- **Errors**: なし
- **Notes**:
  - UI 側のタイマーまたは `addPostFrameCallback` で呼ばれる想定

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
  - パレット順は `#7898B4`, `#B48268`, `#B4A260`, `#987CA8`, `#68A294`
  - 編集ビュー左の timeline rail ダブルタップからも呼ばれる。UI 側では `displayIndex` から `blocks` 上の `sourceIndex` を逆算し、タップ位置の上半分/下半分で `insertIndex` を決定してから本メソッドを呼ぶ

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
- **Notes**:
  - UI では長さ調整ハンドルへの `pointer down` から約 400ms 静止した時点で precise モードへ入る

### `TimelineNotifier.setActiveInlineEditor(String? id)`

- **Summary**: フォーカス中のインラインエディタを記録または解除する
- **Parameters**:
  - `id (String?)`: フォーカス中のインラインエディタ ID。解除時は `null`
- **Returns**: なし
- **Errors**: なし
- **Examples**:
  - タイトル `TextField` にフォーカスが入ると `block-title:<blockId>` や `target-title` を保持する
- **Notes**:
  - UI 側ではこの値を見て、次タップを編集シート表示ではなくフォーカス解除に使う

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
- Drift / SQLite の永続化 Repository は `lib/persistence/` に実装済みだが、`TimelineNotifier` 自体は現時点では自動保存・起動時復元を行わない
- カレンダー書き出し API は `lib/calendar_export.dart` に分離されており、詳細は `_docs/reference/medo/calendar_export_reference.md` を参照
- ローカル通知リマインダー API は `lib/notifications/reminder_notifications.dart` に分離されており、詳細は `_docs/reference/medo/reminder_notification_reference.md` を参照
- `firstOrNull` は Dart SDK の拡張メソッドを利用している
- `test/widget_test.dart` では `computeBlocks`、`formatTime`、画面スモークテストを実施している
- `test/persistence/plan_repository_test.dart` では Repository の保存・ロード・履歴操作を検証している
