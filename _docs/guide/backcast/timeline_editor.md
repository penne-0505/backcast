---
title: Backcast Timeline Editor Guide
status: active
draft_status: n/a
created_at: 2026-04-20
updated_at: 2026-04-20
references:
  - README.md
  - _docs/reference/backcast/timeline_domain_reference.md
  - _docs/intent/backcast/reverse_timeline_interaction_model.md
related_issues: []
related_prs: []
---

## Overview

`Backcast` のタイムラインエディタを使って、目標時刻から逆算した行動計画を組み立てるためのガイドです。
現状のアプリは 1 画面構成で、タイムラインの編集と詳細編集シートを行き来しながら状態を更新します。

## Prerequisites

- Flutter 開発環境が利用できること
- 依存パッケージが取得済みであること
- Linux desktop など、Flutter アプリを起動できるターゲットがあること

## Setup / Usage

まず依存関係を取得し、アプリを起動します。

```bash
/home/penne/sdk/flutter/flutter/bin/flutter pub get
/home/penne/sdk/flutter/flutter/bin/flutter run -d linux
```

起動後の基本操作は以下のとおりです。

1. タイムライン下端の「目標時刻」カードを編集する
2. 画面上部の追加ボタンで、目標より前に置く行動を追加する
3. `action` では行動名と所要時間を編集する
4. `actionPoint` では通過点やチェックポイント名を編集する
5. 行動ブロック上端のドラッグハンドルで所要時間を調整する
6. ブロック本体をタップして編集シートを開き、詳細を調整する
7. 長押し気味に並び替えると、より過去・未来の位置へ順序変更できる

操作の意味は次のとおりです。

- `action`: 時間を消費する行動。`duration` が 5 分以上で保持されます
- `actionPoint`: 時間を消費しない節目。`duration` は 0 分です
- 総所要時間: すべての `action` / `actionPoint` の `duration` 合計をヘッダーに表示します
- 開始時刻ラベル: 目標時刻から逆算した各ブロックの開始時刻です

## Best Practices

- 目的地到着や会議開始など、動かしたくない時刻をまず「目標時刻」に置く
- 所要時間があるものは `action`、節目だけ示したいものは `actionPoint` で分ける
- 大きな工程の間に `actionPoint` を挟むと、逆算結果の読みやすさが上がる
- 数分単位で粗く詰めたあと、長押しドラッグで 1 分刻みの微調整に入る
- 再起動で状態が消えるため、検討中の内容は別途メモへ残す

## Troubleshooting

- 目標時刻を入力しても反映されない:
  `HH:mm` 形式で、時は `0-23`、分は `0-59` の範囲で入力する
- 所要時間を短くしすぎた:
  `action` の最小所要時間は 5 分に丸められる
- アプリ再起動後に内容が消えた:
  永続化は未実装のため、現状では仕様どおり
- 並び替えの開始タイミングがわかりづらい:
  通常の長押しより短い 200ms で並び替え開始する実装になっている
- ドラッグ中に細かく合わせにくい:
  ハンドルを少し長めに押すと precise モードへ入り、1 分単位で調整できる

## References

- `README.md`
- `_docs/guide/flutter/environment_setup.md`
- `_docs/reference/backcast/timeline_domain_reference.md`
- `_docs/intent/backcast/reverse_timeline_interaction_model.md`
- `lib/main.dart`
- `lib/timeline_screen.dart`
- `lib/block_item.dart`
- `lib/edit_sheet.dart`
