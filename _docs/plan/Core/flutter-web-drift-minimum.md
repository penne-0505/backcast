---
title: Flutter Web Drift Minimum Support Plan
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - _docs/intent/medo/drift_persistence_repository.md
  - _docs/reference/medo/persistence_repository_reference.md
  - https://drift.simonbinder.eu/platforms/web/
  - https://pub.dev/documentation/drift_flutter/latest/drift_flutter/driftDatabase.html
related_issues: []
related_prs: []
---

## Overview

Medo を Flutter Web で最低限起動できる状態にし、ローカル永続化が Drift / SQLite on Web で動くことを最初の到達点にする。

操作感の完全再現、Web 向けの課金導線、共有導線、通知導線、レスポンシブ最適化は本 plan の主目的ではない。まず `AppDatabase.defaults()` が Web でも有効な `QueryExecutor` を返し、plan / block / template / preference / entitlement cache の既存 Drift schema を Web storage 上で作成・読み書きできるようにする。

現状実装では `lib/persistence/app_database.dart` が `drift_flutter` の `driftDatabase(name: 'medo')` を使っているが、Web 用の `DriftWebOptions` と `web/` 配下の `sqlite3.wasm` / `drift_worker.dart.js` が未配置である。また、Web compile を阻害し得る `dart:io` import が `lib/auth/auth_providers.dart`、`lib/settings/settings_screen.dart`、`lib/image_export_delivery.dart` に残っている。

## Scope

- `drift` / `drift_flutter` 2.32 系の公式 Web setup に従い、Web 用 SQLite wasm と drift worker を `web/` に配置する。
- `AppDatabase.defaults()` に Web 用 `DriftWebOptions` を渡し、native 既存挙動を維持する。
- Web build を阻害する `dart:io` 直接 import を、条件分岐または platform abstraction で最小限隔離する。
- Web では RevenueCat SDK を使わない既存方針を維持し、Free / cached entitlement の読み取り失敗がアプリ全体を落とさないことを確認する。
- `flutter run -d chrome` または `flutter build web` で、起動、plan 作成、再読み込み後の復元を確認する。
- 実装完了後に persistence reference と timeline editor guide を、Web での永続化制約に合わせて更新する。

## Non-Goals

- Android / iOS と同等の操作感、ジェスチャー、レイアウト密度を Web で完全再現しない。
- RevenueCat の Web Billing 対応、Web checkout、subscription management の Web 導線は実装しない。
- push / local notification の Web 対応は実装しない。
- calendar native MethodChannel の Web 代替実装は作らない。
- 画像共有の Web ダウンロード導線や Web Share API 対応は、compile blocker 解消に必要な範囲を超えて実装しない。
- 既存 native database から Web database への移行は扱わない。Web は origin 単位の新規 storage として扱う。

## Requirements

- **Functional**: Web で `AppDatabase.defaults()` が database を開ける。
- **Functional**: 初回起動時に Drift schema version 5 の全 table が作成される。
- **Functional**: plan の作成・編集・current plan preference 保存・template 保存が Web reload 後も維持される。
- **Functional**: Web 非対応機能を触った場合は、未対応メッセージまたは no-op fallback でアプリ全体を落とさない。
- **Non-Functional**: Android の既存 database path と schema migration 挙動を変えない。
- **Non-Functional**: Web の永続化は Drift が選ぶ storage implementation に従う。`unsafeIndexedDb` / `inMemory` fallback は初期対応では警告表示の検討対象に留める。
- **Non-Functional**: `sqlite3.wasm` は `application/wasm` として配信される必要がある。`flutter run` では通常満たされるが、配布先では確認する。
- **Non-Functional**: COOP / COEP header は初期必須にしない。設定すると Origin-Private FileSystem 系の実装が使いやすくなる一方、OAuth popup 系と衝突し得るため、別途検証してから導入する。

## Implementation Notes

### Drift Web assets

公式 Drift Web docs に従い、`web/` 配下へ次を置く。

- `web/sqlite3.wasm`
- `web/drift_worker.dart.js`

バージョンは `pubspec.lock` の `sqlite3: 3.3.1` と `drift: 2.32.1` に合わせる。取得元は drift / sqlite3.dart の release artifact か、必要に応じて worker を `dart compile js -O4` で生成する。

### Database executor

候補実装は次のいずれか。

1. `driftDatabase(name: 'medo', web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.dart.js')))` を `AppDatabase.defaults()` に渡す。
2. より詳細な検知や warning が必要になったら、`WasmDatabase.open` と conditional export へ移す。

今回の最小目標では 1 を優先する。理由は、現状の database file が `drift_flutter` に閉じており、native 側の path 変更を避けられるため。

### Compile blockers

Web compile の直接 blocker になり得る箇所は、Drift 対応と同じ task 内で最小修正する。

- `lib/auth/auth_providers.dart`: `Platform.isIOS` / `Platform.isMacOS` を `kIsWeb` / `defaultTargetPlatform` ベースの helper に置き換える。
- `lib/settings/settings_screen.dart`: Apple subscription management 表示条件を `dart:io` に依存しない platform helper へ置き換える。
- `lib/image_export_delivery.dart`: `dart:io` / `path_provider` 前提の share path を native 実装に閉じる。Web は明示的に unsupported とするか、後続 task で download 化する。

### Web unsupported behavior

既存の `RevenueCatConfig.supportsCurrentPlatform` は `kIsWeb` で false を返すため、RevenueCat configure / login / logout は回避できる。ただし billing provider が offerings / restore などで SDK を呼ぶ導線が残るため、Web では paywall 操作を未対応として止めるか、provider 側で unsupported state にする。

## Tasks

1. Web asset の取得方法を決め、`sqlite3.wasm` と `drift_worker.dart.js` を `pubspec.lock` のバージョンに合わせて `web/` に配置する。
2. `AppDatabase.defaults()` に `DriftWebOptions` を追加し、native 既存挙動を変えずに Web executor を開けるようにする。
3. `dart:io` 直接 import 箇所を洗い出し、Web compile を阻害しない platform helper / conditional implementation に分離する。
4. Web 非対応の課金・共有・通知・calendar native 導線が、押下時にアプリ全体を落とさないことを確認する。
5. `flutter analyze` と Web build / run を実行し、起動・plan 保存・reload 復元を確認する。
6. `_docs/reference/medo/persistence_repository_reference.md` と必要な guide に、Web Drift の storage 制約と未対応範囲を追記する。

## Test Plan

- `flutter analyze`
- `flutter test test/persistence/plan_repository_test.dart test/persistence/timeline_template_repository_test.dart test/billing/pro_entitlement_cache_repository_test.dart`
- `flutter build web`
- `flutter run -d chrome` で次を手動確認する。
  - 初回起動で database 作成エラーが出ない。
  - plan を作成・編集できる。
  - browser reload 後に current plan が復元される。
  - template 保存・適用が動く。
  - Web 非対応の share / calendar / purchase 導線が、クラッシュではなく未対応状態として扱われる。

## Deployment / Rollout

- 初期 rollout は開発用 Web build のみとし、公開配布は `flutter build web` の artifact と wasm MIME type を確認してから行う。
- 配布先で `sqlite3.wasm` が `Content-Type: application/wasm` で返ることを確認する。
- COOP / COEP header は初期 rollout では必須化しない。将来、Drift の storage implementation と OAuth popup への影響を見て、必要なら別 plan で扱う。
- rollback は Web 配布 artifact を前版へ戻す。native 側は database schema を変更しないため、Android / iOS の rollback 手順は不要。

## Implementation Result

- `AppDatabase.defaults()` は Web で `sqlite3.wasm` と `drift_worker.dart.js` を使う `DriftWebOptions` を渡す。
- `web/sqlite3.wasm` は sqlite3 `3.3.1` release artifact を配置した。SHA-256 は `3c616bf0d51380daaed7871b3110a634a17c703c22d82cba7a2a73216769e680`。
- `web/drift_worker.dart.js` は drift `2.32.1` の `WasmDatabase.workerMainForOpen()` entrypoint から生成した。再生成用に `web/drift_worker.dart` を残す。
- `dart:io` 直接 import は Web build 対象から外し、画像共有は native 実装と Web fallback に分離した。
- Headless browser 検証では `sharedIndexedDb` が選択され、IndexedDB に `medo` database が作成された。UI から `新しい行動` を追加し、reload 後も追加済み block が復元されることを確認した。
