# Medo

`Medo` は、目標時刻から逆算して行動の流れを組み立てる Flutter アプリです。
「何時までに着きたいか / 終えたいか」を先に置き、そこから必要な行動を過去方向へ積み上げていくタイムラインエディタとして実装されています。

現状の実装は、単一画面で完結するプロトタイプ兼基礎実装です。Riverpod で保持しているインメモリ状態を編集しながら、目標時刻・各行動の所要時間・行動ポイントを即時に反映できます。

## 現在の機能

- 目標時刻と目標名の編集
- `action` ブロックの追加、名称変更、所要時間変更、並び替え
- `actionPoint` ブロックの追加、名称変更、並び替え
- 逆算結果に基づく各ブロック開始時刻と総所要時間の表示
- 保存済みプランの作成と読み込み
- Android / iOS でのカレンダー登録
- 記号レイアウト形式のテキスト共有とクリップボードコピー
- タイムラインの画像カードとしての PNG 共有

## 画面の考え方

- タイムライン下端に「目標時刻」アンカーを置きます
- その上側へ向かって、より過去の行動を積み上げます
- `action` は時間を消費する行動です
- `actionPoint` は経由点やチェックポイントで、所要時間は 0 分です
- すべての開始時刻は `targetTime` と後続ブロックの `duration` から再計算されます

## カラーパレット

- Base / Canvas: `#F6F5F2`
- Soft Gray: `#DDD9D0`
- Ink: `#26241F`
- Muted Ink: `#6F6A61`
- Accent / Olive: `#8A9864`
- Dark Surface: `#1F211C`

## セットアップ

Flutter SDK を PATH に通していない前提では、以下の絶対パスを使って実行できます。

```bash
/home/penne/sdk/flutter/flutter/bin/flutter pub get
/home/penne/sdk/flutter/flutter/bin/flutter analyze
/home/penne/sdk/flutter/flutter/bin/flutter test
/home/penne/sdk/flutter/flutter/bin/flutter run -d linux
```

環境セットアップの補足は [`_docs/guide/flutter/environment_setup.md`](_docs/guide/flutter/environment_setup.md) を参照してください。

## 開発メモ

- エントリポイントは `lib/main.dart` です
- 状態管理は `lib/state.dart` の `TimelineNotifier` と `timelineProvider` に集約しています
- 時刻計算の純粋関数は `lib/models.dart` にあります
- カレンダー書き出しの純粋関数は `lib/calendar_export.dart` にあります
- カレンダー登録の request 組み立てとプレビューは `lib/calendar_export_request_builder.dart` にあります
- カレンダー登録の native delivery は `lib/calendar_export_delivery.dart` にあります
- テキスト共有の純粋関数は `lib/timeline_text_export.dart` にあります
- 画像共有の純粋関数と Widget、delivery は `lib/timeline_image_export.dart`、`lib/timeline_image_share_card.dart`、`lib/image_export_delivery.dart` にあります
- ローカル通知リマインダーのサービス層は `lib/notifications/` にあります
- 永続化 Repository は `lib/persistence/` にあります
- 主要 UI は `lib/timeline_screen.dart`、`lib/block_item.dart`、`lib/edit_sheet.dart` に分かれています
- テストは `test/widget_test.dart` と `test/persistence/` にあり、計算ロジック、スモークテスト、Repository の保存・履歴操作を含みます

## ドキュメント

- 利用ガイド: [`_docs/guide/medo/timeline_editor.md`](_docs/guide/medo/timeline_editor.md)
- リファレンス: [`_docs/reference/medo/timeline_domain_reference.md`](_docs/reference/medo/timeline_domain_reference.md)
- カレンダー書き出しリファレンス: [`_docs/reference/medo/calendar_export_reference.md`](_docs/reference/medo/calendar_export_reference.md)
- テキスト共有リファレンス: [`_docs/reference/medo/text_export_reference.md`](_docs/reference/medo/text_export_reference.md)
- 画像共有リファレンス: [`_docs/reference/medo/image_export_reference.md`](_docs/reference/medo/image_export_reference.md)
- ローカル通知リファレンス: [`_docs/reference/medo/reminder_notification_reference.md`](_docs/reference/medo/reminder_notification_reference.md)
- 永続化リファレンス: [`_docs/reference/medo/persistence_repository_reference.md`](_docs/reference/medo/persistence_repository_reference.md)
- 設計意図: [`_docs/intent/medo/reverse_timeline_interaction_model.md`](_docs/intent/medo/reverse_timeline_interaction_model.md)
- カレンダー書き出し設計意図: [`_docs/intent/medo/calendar_export_ics.md`](_docs/intent/medo/calendar_export_ics.md)
- ローカル通知設計意図: [`_docs/intent/medo/local_reminder_notifications.md`](_docs/intent/medo/local_reminder_notifications.md)
- 永続化設計意図: [`_docs/intent/medo/drift_persistence_repository.md`](_docs/intent/medo/drift_persistence_repository.md)
- ドキュメント運用ガイド: [`_docs/documentation_guide.md`](_docs/documentation_guide.md)

## 現状の制約

- Drift / SQLite の永続化 Repository は実装済みですが、アプリ画面への起動時復元・自動保存接続は未実装です。現状の画面は再起動で初期状態から始まります
- カレンダー書き出しは `.ics` 文字列生成に加えて、Android / iOS ではネイティブ API でカレンダーへ直接登録します。登録前に開始日時、アンカー日時、件数、日跨ぎ状態をプレビューで確認できます
- Android / iOS のカレンダー登録では、権限拒否・書き込み可能カレンダーなし・ペイロード不正・保存失敗を domain error として区別します。iOS 17+ では write-only access を優先し、それ以前の OS では full access にフォールバックします
- カレンダー登録時の書き込み先カレンダー選択 UI は未実装です。現状は未指定時に OS の既定カレンダーへ自動的に書き込みます
- ローカル通知は予約サービスのみ実装済みで、権限要求や予約操作を行う UI は未実装です
- Undo / Redo は未実装です
- `applyStartTimeEdit` は状態層に実装済みですが、現状の UI では直接使用していません
- Web / macOS / Windows / iOS 用のランナー雛形は存在しますが、運用・検証状況は別途確認が必要です

## 検証済みコマンド

2026-04-20 時点で、少なくとも以下は通過済みです。

```bash
/home/penne/sdk/flutter/flutter/bin/flutter analyze
/home/penne/sdk/flutter/flutter/bin/flutter test
```
