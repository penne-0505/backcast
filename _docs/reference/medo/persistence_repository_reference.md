---
title: Medo Persistence Repository Reference
status: active
draft_status: n/a
created_at: "2026-04-23"
updated_at: "2026-05-15"
references:
  - README.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/intent/medo/drift_persistence_repository.md
  - _docs/plan/Core/flutter-web-drift-minimum.md
related_issues: []
related_prs: []
---

## Overview

本リファレンスは、`Medo` の複数プラン保存・ロード、現在プラン復元、履歴閲覧、テンプレート永続化、Pro cache、利用改善 analytics queue のために追加した永続化 Repository の現状仕様をまとめます。
対象は `lib/persistence/app_database.dart`、`lib/persistence/plan_repository.dart`、`lib/persistence/timeline_template_repository.dart`、`lib/persistence/timeline_template_apply_service.dart`、`lib/persistence/timeline_state_codec.dart`、`lib/analytics/usage_analytics.dart`、`lib/auth/account_deletion_cleanup.dart` です。

アプリ画面は起動時に最後に開いた plan を復元し、編集中の状態を自動保存します。timeline list island modal の切り替え操作は current plan preference を更新します。ヘッダーの export panel は保存・ロードを扱いません。

Flutter Web では `drift_flutter` の Web executor を使い、`web/sqlite3.wasm` と `web/drift_worker.dart.js` を読み込んで browser storage 上に `medo` database を作成します。Web database は browser origin 単位の storage であり、Android / iOS の native database file から自動移行しません。

利用改善 analytics は既定で off です。設定画面で同意した場合のみ、`UsageAnalyticsService` が allowlist event を `analytics_events` queue に保存し、Supabase Edge Function へ background best-effort で batch 送信します。タイムライン本文、タイトル、自由入力、raw time、メールアドレス、Supabase user id は保存・送信しません。

アカウント削除時は `AccountDeletionLocalCleanup` が `plans`、`plan_blocks`、`plan_snapshots`、`timeline_templates`、`timeline_template_blocks`、`app_preferences`、`cached_pro_entitlements`、`analytics_events` を削除します。削除処理は `delete-account` Edge Function 成功後に pending marker を保存してから実行され、途中で失敗した場合は次回起動時に再試行できるよう `app_preferences` の marker を残します。

## API

### `class AppDatabase`

- **Summary**: Drift / SQLite の database 定義
- **Parameters**:
  - `QueryExecutor executor`: テストやカスタム接続で使う Drift executor
- **Returns**: `plans`、`plan_blocks`、`plan_snapshots`、`timeline_templates`、`timeline_template_blocks`、`app_preferences` テーブルを持つ database
- **Errors**: Drift / SQLite の接続・クエリエラーをそのまま返す
- **Examples**:
  - 本番用: `AppDatabase.defaults()`
  - テスト用: `AppDatabase(NativeDatabase.memory())`
- **Notes**:
  - 現行 Drift schema version は 6。version 4 で `plan_blocks.bufferMinutes` と `timeline_template_blocks.bufferMinutes` を追加し、version 5 で `cached_pro_entitlements` を追加し、version 6 で `analytics_events` を追加した
  - Flutter Web では `AppDatabase.defaults()` が `DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.dart.js'))` を渡す

### `plans` table

- **Summary**: プラン単位のメタデータと目標アンカー状態を保持する
- **Parameters**:
  - `id (String)`: プラン ID
  - `title (String)`: プラン一覧に表示する名前
  - `targetTime (int)`: 分単位の目標時刻
  - `targetTimeTitle (String)`: 目標ラベル
  - `createdAt (DateTime)`: 作成日時
  - `updatedAt (DateTime)`: 更新日時
- **Returns**: なし
- **Errors**: `id` 重複や必須列欠落は SQLite エラーになる
- **Examples**:
  - `title = "朝の準備"`, `targetTime = 540`, `targetTimeTitle = "会議開始"`

### `plan_blocks` table

- **Summary**: 現在のプランを構成するブロックを順序付きで保持する
- **Parameters**:
  - `id (String)`: ブロック ID
  - `planId (String)`: 所属プラン ID
  - `type (String)`: `action` または `actionPoint`
  - `title (String)`: ブロック名
  - `duration (int)`: 分単位の raw action 所要時間。`actionPoint` でもブロック復帰用に保持され得る
  - `bufferMinutes (int)`: 分単位の raw desired 余裕時間。`actionPoint` では effective 0 だが、ブロック復帰用に保持され得る。既定値は 0
  - `colorIndex (int)`: ブロック色インデックス
  - `position (int)`: `TimelineState.blocks` 上の順序
- **Returns**: なし
- **Errors**: `planId` が存在しない場合は外部キー制約の対象になる
- **Examples**:
  - `position` 昇順で読み出すと `TimelineState.blocks` と同じ順序になる

### `plan_snapshots` table

- **Summary**: 履歴閲覧・復元用の `TimelineState` JSON snapshot を保持する
- **Parameters**:
  - `id (String)`: snapshot ID
  - `planId (String)`: 対象プラン ID
  - `label (String?)`: 任意ラベル
  - `stateJson (String)`: versioned JSON snapshot
  - `createdAt (DateTime)`: snapshot 作成日時
- **Returns**: なし
- **Errors**: `stateJson` が壊れている場合、Repository の decode 時に `FormatException` になる
- **Examples**:
  - 保存直後: `label = "After edit"`
  - 復元前退避: `label = "Before restore"`

### `timeline_templates` table

- **Summary**: 再利用可能なタイムラインテンプレートのメタデータを保持する
- **Parameters**:
  - `id (String)`: テンプレート ID
  - `title (String)`: テンプレート名
  - `targetTime (int)`: 分単位の目標時刻
  - `targetTimeTitle (String)`: 目標ラベル
  - `createdAt (DateTime)`: 作成日時
  - `updatedAt (DateTime)`: 更新日時
- **Returns**: なし
- **Errors**: `id` 重複や必須列欠落は SQLite エラーになる
- **Examples**:
  - `title = "朝の準備テンプレート"`, `targetTime = 540`, `targetTimeTitle = "会議開始"`

### `timeline_template_blocks` table

- **Summary**: テンプレートを構成するブロックを順序付きで保持する
- **Parameters**:
  - `id (String)`: ブロック ID
  - `templateId (String)`: 所属テンプレート ID
  - `type (String)`: `action` または `actionPoint`
  - `title (String)`: ブロック名
  - `duration (int)`: 分単位の raw action 所要時間。`actionPoint` でもブロック復帰用に保持され得る
  - `bufferMinutes (int)`: 分単位の raw desired 余裕時間。`actionPoint` では effective 0 だが、ブロック復帰用に保持され得る。既定値は 0
  - `colorIndex (int)`: ブロック色インデックス
  - `position (int)`: `TimelineState.blocks` 上の順序
- **Returns**: なし
- **Errors**: `templateId` が存在しない場合は外部キー制約の対象になる
- **Examples**:
  - `position` 昇順で読み出すと `TimelineState.blocks` と同じ順序になる

### `app_preferences` table

- **Summary**: アプリ横断の軽量設定を key-value 形式で保持する
- **Parameters**:
  - `key (String)`: 設定キー
  - `value (String)`: 設定値
  - `updatedAt (DateTime)`: 更新日時
- **Returns**: なし
- **Errors**: `key` 重複時は upsert で置き換える
- **Examples**:
  - `key = "currentPlanId"`, `value = plans.id`
  - `key = "pendingAccountDeletionCleanup"`, `value = "true"`

### `cached_pro_entitlements` table

- **Summary**: Supabase から確認済みの Pro / Free snapshot をユーザー ID ごとに保持する
- **Parameters**:
  - `userId (String)`: Supabase user UUID
  - `isPro (bool)`: Pro access が有効か
  - `status (String)`: server entitlement status
  - `productId (String?)`: 対応する product ID
  - `expiresAt (DateTime?)`: entitlement 期限
  - `lastSyncedAt (DateTime?)`: Supabase からの最終同期時刻
  - `cachedAt (DateTime)`: 端末内 cache 更新時刻
- **Returns**: なし
- **Errors**: `userId` 重複時は upsert で置き換える
- **Examples**:
  - `ProEntitlementCacheRepository.clearAll()` はアカウント削除時に全ユーザー分の entitlement cache を削除する

### `analytics_events` table

- **Summary**: 利用改善 analytics の未送信 queue を保持する
- **Parameters**:
  - `id (String)`: local event UUID
  - `eventName (String)`: allowlist event name
  - `propertiesJson (String)`: sanitizer 通過後の JSON
  - `occurredAt (DateTime)`: event 発生日時
  - `sessionId (String)`: app session UUID
  - `installId (String)`: random install UUID
  - `uploadState (String)`: `pending` / `failed`
  - `attemptCount (int)`: 送信試行回数
  - `lastAttemptAt (DateTime?)`: 最終送信試行日時
  - `createdAt (DateTime)`: row 作成日時
- **Returns**: なし
- **Errors**: `id` 重複や必須列欠落は SQLite エラーになる
- **Examples**:
  - `UsageAnalyticsService.track(UsageAnalyticsEvent.blockAdded, properties: {...})` が consent enabled の場合だけ queue に追加し、upload は background flush に任せる
  - `UsageAnalyticsRepository.clearPendingEvents()` は opt-out とアカウント削除時に未送信 event を削除する

### `UsageAnalyticsService.track`

- **Summary**: allowlist event を sanitizer に通して端末内 queue に保存し、送信可能な場合は background best-effort で flush を試行する
- **Parameters**:
  - `event (UsageAnalyticsEvent)`: 記録対象 event
  - `properties (Map<String, Object?>)`: event ごとの許可済み property 候補
- **Returns**: queue 保存まで完了したら返る。network upload 完了は待たない
- **Errors**: 送信失敗は service 内で failed queue として保持し、呼び出し元 UI には伝播しない
- **Examples**:
  - `block_added` では `block_type` と `block_count_bucket` のみ保存される
  - `title`、`text`、`email`、`user_id` など schema 外 property は破棄される

### `PlanRepository.createPlan`

- **Summary**: 新しいプランを作成し、現在ブロックと必要に応じて初期 snapshot を保存する
- **Parameters**:
  - `state (TimelineState)`: 保存するタイムライン状態
  - `title (String?)`: プラン名。未指定時は `targetTimeTitle` から補完
  - `createInitialSnapshot (bool)`: 初期 snapshot を作るか
- **Returns**: 作成された `TimelinePlan`
- **Errors**: DB 書き込み失敗時は Drift / SQLite エラー
- **Examples**:
  - `repository.createPlan(state: state, title: "朝の準備")`

### `PlanRepository.listPlans`

- **Summary**: 保存済みプランを `updatedAt` 降順で取得する
- **Parameters**: なし
- **Returns**: `List<TimelinePlanSummary>`
- **Errors**: DB 読み込み失敗時は Drift / SQLite エラー
- **Examples**:
  - プラン選択画面の一覧表示に使用する

### `PlanRepository.countPlans`

- **Summary**: 保存済み plan 数を取得する
- **Parameters**: なし
- **Returns**: `int`
- **Errors**: DB 読み込み失敗時は Drift / SQLite エラー
- **Examples**:
  - Free / Pro のタイムライン作成上限判定に使用する

### `PlanRepository.loadCurrentPlanId`

- **Summary**: 最後に開いていた current plan id を読み出す
- **Parameters**: なし
- **Returns**: 保存値が存在し、対応する plan も存在する場合は plan id。未保存または対象 plan が存在しない場合は `null`
- **Errors**: DB 読み込み失敗時は Drift / SQLite エラー
- **Examples**:
  - 起動時に `listPlans()` の先頭へ fallback する前に参照する

### `PlanRepository.saveCurrentPlanId`

- **Summary**: 最後に開いていた current plan id を保存する
- **Parameters**:
  - `planId (String)`: current として保存する plan ID
- **Returns**: なし
- **Errors**: 対象 plan が存在しない場合は `StateError`
- **Examples**:
  - timeline list island modal から plan を切り替えた後に呼ぶ

### `PlanRepository.loadPlan`

- **Summary**: 指定 ID の現在プランを `TimelineState` として読み出す
- **Parameters**:
  - `planId (String)`: 読み込み対象プラン ID
- **Returns**: 存在する場合は `TimelinePlan`、存在しない場合は `null`
- **Errors**: ブロック種別が未知の場合は `FormatException`
- **Examples**:
  - `final plan = await repository.loadPlan(planId);`

### `PlanRepository.savePlan`

- **Summary**: 既存プランの現在状態を置き換え、必要に応じて snapshot を追加する
- **Parameters**:
  - `planId (String)`: 更新対象プラン ID
  - `state (TimelineState)`: 新しい現在状態
  - `title (String?)`: 新しいプラン名
  - `createSnapshot (bool)`: 保存時 snapshot を作るか
  - `snapshotLabel (String?)`: snapshot ラベル
- **Returns**: なし
- **Errors**: 対象プランが存在しない場合は `StateError`
- **Examples**:
  - `repository.savePlan(planId: id, state: state, snapshotLabel: "After edit")`

### `PlanRepository.renamePlan`

- **Summary**: 指定プランの表示名だけを更新する
- **Parameters**:
  - `planId (String)`: 更新対象プラン ID
  - `newTitle (String)`: 新しいプラン名。前後空白は削除され、空文字・空白のみは `無題のタイムライン` に正規化される
- **Returns**: なし
- **Errors**: 対象プランが存在しない場合は `StateError`
- **Examples**:
  - timeline list island modal の row inline rename から呼ぶ

### `PlanRepository.deletePlan`

- **Summary**: 指定プランを削除する
- **Parameters**:
  - `planId (String)`: 削除対象プラン ID
- **Returns**: なし
- **Errors**: DB 削除失敗時は Drift / SQLite エラー
- **Examples**:
  - timeline list island modal の削除確認後に使用する
  - current plan を削除した場合、UI 側で残存 plan または新規空 plan を current として保存する

### `PlanRepository.createSnapshot`

- **Summary**: 指定プランに任意の `TimelineState` snapshot を追加する
- **Parameters**:
  - `planId (String)`: 対象プラン ID
  - `state (TimelineState)`: snapshot として残す状態
  - `label (String?)`: 任意ラベル
- **Returns**: 作成された snapshot ID
- **Errors**: 対象プランが存在しない場合は `StateError`
- **Examples**:
  - `repository.createSnapshot(planId: id, state: state, label: "Before changes")`

### `PlanRepository.listSnapshots`

- **Summary**: 指定プランの snapshot 一覧を `createdAt` 降順で取得する
- **Parameters**:
  - `planId (String)`: 対象プラン ID
- **Returns**: `List<TimelineSnapshotSummary>`
- **Errors**: DB 読み込み失敗時は Drift / SQLite エラー
- **Examples**:
  - 履歴閲覧画面の一覧表示に使用する

### `PlanRepository.loadSnapshot`

- **Summary**: 指定 snapshot を読み込み、`TimelineState` として復元する
- **Parameters**:
  - `snapshotId (String)`: snapshot ID
- **Returns**: 存在する場合は `TimelineSnapshot`、存在しない場合は `null`
- **Errors**: JSON schema version 非対応や破損時は `FormatException`
- **Examples**:
  - `final snapshot = await repository.loadSnapshot(snapshotId);`

### `PlanRepository.restoreSnapshot`

- **Summary**: 指定 snapshot の状態を現在プランへ復元する
- **Parameters**:
  - `snapshotId (String)`: 復元元 snapshot ID
  - `createSnapshotBeforeRestore (bool)`: 復元前の現在状態を退避するか
- **Returns**: なし
- **Errors**: snapshot または plan が存在しない場合は `StateError`
- **Examples**:
  - `repository.restoreSnapshot(snapshotId: snapshotId)`

### `TimelineTemplateRepository.createTemplate`

- **Summary**: 現在の `TimelineState` をテンプレートとして保存する
- **Parameters**:
  - `state (TimelineState)`: 保存するタイムライン状態
  - `title (String?)`: テンプレート名。未指定時は `targetTimeTitle` から補完。空文字・空白のみは `Untitled template` に正規化される
- **Returns**: 作成された `TimelineTemplate`
- **Errors**: DB 書き込み失敗時は Drift / SQLite エラー
- **Examples**:
  - `repository.createTemplate(state: state, title: "朝の準備テンプレート")`

### `TimelineTemplateRepository.listTemplates`

- **Summary**: 保存済みテンプレートを `updatedAt` 降順で取得する
- **Parameters**: なし
- **Returns**: `List<TimelineTemplateSummary>`
- **Errors**: DB 読み込み失敗時は Drift / SQLite エラー
- **Examples**:
  - テンプレート一覧画面の表示に使用する

### `TimelineTemplateRepository.loadTemplate`

- **Summary**: 指定 ID のテンプレートを `TimelineState` として読み出す
- **Parameters**:
  - `templateId (String)`: 読み込み対象テンプレート ID
- **Returns**: 存在する場合は `TimelineTemplate`、存在しない場合は `null`
- **Errors**: ブロック種別が未知の場合は `FormatException`
- **Examples**:
  - `final template = await repository.loadTemplate(templateId);`
- **Notes**:
  - `bufferMinutes` はテンプレートのブロック属性として保存・復元される

### `TimelineTemplateRepository.restoreTemplateState`

- **Summary**: 指定テンプレートから fresh block IDs を持つ `TimelineState` を復元する
- **Parameters**:
  - `templateId (String)`: 復元元テンプレート ID
- **Returns**: 新しい block IDs を持つ `TimelineState`
- **Errors**: 対象テンプレートが存在しない場合は `StateError`
- **Examples**:
  - `final state = await repository.restoreTemplateState(templateId);`
- **Notes**:
  - fresh block IDs を採番しても `duration`、`bufferMinutes`、`colorIndex` はテンプレート内容を保持する

### `TimelineTemplateRepository.renameTemplate`

- **Summary**: 指定テンプレートの名前を変更する
- **Parameters**:
  - `templateId (String)`: 対象テンプレート ID
  - `newTitle (String)`: 新しいテンプレート名。空文字・空白のみは `Untitled template` に正規化される
- **Returns**: なし
- **Errors**: 対象テンプレートが存在しない場合は `StateError`
- **Examples**:
  - `repository.renameTemplate(templateId, "新しい名前")`

### `TimelineTemplateRepository.deleteTemplate`

- **Summary**: 指定テンプレートを削除する
- **Parameters**:
  - `templateId (String)`: 削除対象テンプレート ID
- **Returns**: なし
- **Errors**: DB 削除失敗時は Drift / SQLite エラー
- **Examples**:
  - テンプレート削除 UI から使用する

### `TimelineTemplateApplyService.applyTemplate`

- **Summary**: 保存済みテンプレートを現在のタイムラインへ安全に適用する
- **Parameters**:
  - `templateId (String)`: 適用するテンプレート ID
- **Returns**: なし
- **Errors**: 現在 plan が未ロードの場合は `StateError`、対象テンプレートが存在しない場合は `StateError`
- **Execution Order**:
  1. `TimelineTemplateRepository.restoreTemplateState` で fresh block IDs を持つ `TimelineState` を復元
  2. `PlanRepository.createSnapshot` で現在状態を `'Before template apply'` として退避
  3. `TimelineNotifier.applyTemplateState` で一時 UI 状態をクリアしながら適用
  4. `PlanRepository.savePlan` で即座に永続化（autosave debounce に依存しない）
- **Examples**:
  - `await service.applyTemplate(templateId);`

### `encodeTimelineState` / `decodeTimelineState`

- **Summary**: `TimelineState` を versioned JSON snapshot と相互変換する
- **Parameters**:
  - `TimelineState state`: encode 対象
  - `String source`: decode 対象 JSON 文字列
- **Returns**: JSON 文字列または `TimelineState`
- **Errors**: schema version 非対応、型不一致、未知の `BlockType` では `FormatException`
- **Examples**:
  - `final json = encodeTimelineState(state);`
  - `final state = decodeTimelineState(json);`
- **Notes**:
  - schema version 2 では `Block.bufferMinutes` を含める
  - schema version 1 の snapshot は `bufferMinutes = 0` として読み込む

## Notes

- 保存 schema version は `timelineStatePersistenceSchemaVersion = 2`
- `TimelineState` の一時 UI 状態は snapshot へ含めない
- `plan_blocks.position` は `TimelineState.blocks` の順序を保持するための列
- `timeline_template_blocks.position` も同様に `TimelineState.blocks` の順序を保持する
- `plan_blocks.bufferMinutes` と `timeline_template_blocks.bufferMinutes` は raw desired 値として保存し、読み込み時に `normalizeRawActionBufferMinutes` で 0〜60 分の 5 分刻みへ正規化する。`actionPoint` でも raw 値は保持し、表示・計算時の effective buffer だけを 0 とする
- `restoreTemplateState` は適用先 timeline との block ID 衝突を避けるため、必ず fresh block IDs を採番する
- `TimelineTemplateApplyService.applyTemplate` は snapshot → apply → save の順序を保証し、適用前の状態を復元可能にする
- `TimelineNotifier.applyTemplateState` は `loadState` と異なり、`selectedBlockId` / `preciseDraggingId` / `activeInlineEditorId` を自動的にクリアする
- Drift schema を変更した場合は `dart run build_runner build` で生成コードを更新する
- Flutter Web 配布時は `sqlite3.wasm` が `application/wasm` で配信される必要がある。`flutter run` / `flutter build web` のローカル確認だけでなく、配布先の MIME type も確認する
- Drift Web は browser の対応状況に応じて `opfsShared`、`opfsLocks`、`sharedIndexedDb`、`unsafeIndexedDb`、`inMemory` のいずれかを選ぶ。初期対応では選択結果の警告表示は行わず、console log で確認する
