# Backcast

`Backcast` は、目標時刻から逆算して行動の流れを組み立てる Flutter アプリです。  
「何時までに着きたいか / 終えたいか」を先に置き、そこから必要な行動を過去方向へ積み上げていくタイムラインエディタとして実装されています。

現状の実装は、単一画面で完結するプロトタイプ兼基礎実装です。Riverpod で保持しているインメモリ状態を編集しながら、目標時刻・各行動の所要時間・行動ポイントを即時に反映できます。

## 現在の機能

- 目標時刻と目標名の編集
- `action` ブロックの追加、名称変更、所要時間変更
- `actionPoint` ブロックの追加、名称変更
- タイムラインの並び替え
- ドラッグによる所要時間の調整
- 編集シートによる詳細編集
- 総所要時間の自動集計
- 逆算結果に基づく各ブロック開始時刻の自動表示

## 画面の考え方

- タイムライン下端に「目標時刻」アンカーを置きます
- その上側へ向かって、より過去の行動を積み上げます
- `action` は時間を消費する行動です
- `actionPoint` は経由点やチェックポイントで、所要時間は 0 分です
- すべての開始時刻は `targetTime` と後続ブロックの `duration` から再計算されます

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
- 主要 UI は `lib/timeline_screen.dart`、`lib/block_item.dart`、`lib/edit_sheet.dart` に分かれています
- テストは `test/widget_test.dart` にあり、計算ロジックとスモークテストを含みます

## ドキュメント

- 利用ガイド: [`_docs/guide/backcast/timeline_editor.md`](_docs/guide/backcast/timeline_editor.md)
- リファレンス: [`_docs/reference/backcast/timeline_domain_reference.md`](_docs/reference/backcast/timeline_domain_reference.md)
- 設計意図: [`_docs/intent/backcast/reverse_timeline_interaction_model.md`](_docs/intent/backcast/reverse_timeline_interaction_model.md)
- ドキュメント運用ガイド: [`_docs/documentation_guide.md`](_docs/documentation_guide.md)

## 現状の制約

- データ永続化は未実装です。アプリ再起動で状態は初期化されます
- Undo / Redo は未実装です
- `applyStartTimeEdit` は状態層に実装済みですが、現状の UI では直接使用していません
- Web / macOS / Windows / iOS 用のランナー雛形は存在しますが、運用・検証状況は別途確認が必要です

## 検証済みコマンド

2026-04-20 時点で、少なくとも以下は通過済みです。

```bash
/home/penne/sdk/flutter/flutter/bin/flutter analyze
/home/penne/sdk/flutter/flutter/bin/flutter test
```
