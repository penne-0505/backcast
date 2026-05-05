---
title: Medo Timeline Editor Guide
status: active
draft_status: n/a
created_at: "2026-04-20"
updated_at: "2026-05-04"

references:
  - README.md
  - _docs/reference/backcast/timeline_domain_reference.md
  - _docs/reference/backcast/persistence_repository_reference.md
  - _docs/intent/backcast/reverse_timeline_interaction_model.md
  - _docs/intent/backcast/drift_persistence_repository.md
related_issues: []
related_prs: []
---

## Overview

`Medo` のタイムラインエディタを使って、目標時刻から逆算した行動計画を組み立てるためのガイドです。
現状のアプリは 1 画面構成で、タイムラインの編集と詳細編集シートを行き来しながら状態を更新します。
編集ビューに加え、固定高さ行でタイムライン全体を一覧する **Compact Overview** ビューが利用できます。
Drift / SQLite ベースの永続化 Repository は実装済みですが、画面からの自動保存・起動時復元・プラン選択 UI はまだ接続していません。

現行 UI の配色は、`Canvas #F6F5F2` を基調に、`Soft Gray #DDD9D0`、`Ink #26241F`、補助テキスト用の `Muted Ink #6F6A61`、`Accent / Olive #8A9864`、`Dark Surface #1F211C` を使う固定パレットです。ブロック色は `#7898B4`, `#B48268`, `#B4A260`, `#987CA8`, `#68A294` の順で循環します。

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
8. ヘッダーの切り替えボタンで **Compact Overview** ビューに移動し、全体構成を一覧する
9. Compact Overview で行をタップして選択し、上下ボタンで並び替える
10. 選択中の行をダブルタップ、または下部の「編集ビューへ」ボタンで編集ビューに戻る
11. 編集ビュー左の timeline rail（48px の左側領域）をダブルタップすると、最も近い block 境界に新しい `action` block を挿入できる
12. ヘッダーの検索アイコン（🔍）をタップして、block タイトル検索を開く
13. 検索バーにキーワードを入力すると、現在の plan 内の `Block.title` が部分一致で検索される
14. `1/3` のような件数表示を確認し、↑↓ ボタンまたはキーボードの検索ボタンで前後の一致結果へ移動できる
15. 検索ジャンプ後、対象 block の始点が上部に少し余白を持って見える位置へ自動スクロールし、3 秒間一時ハイライトされる
16. 検索バーの ✕ ボタン、またはフォーカスを外して閉じると検索状態がクリアされる
17. ヘッダーのテンプレートアイコン（🗂️）をタップして、テンプレート管理シートを開く
18. 「現在のタイムラインを保存」ボタンで、現在の目標時刻と行動一覧をテンプレートとして保存する
19. 保存済みテンプレートは名前、目標ラベル、目標時刻、ブロック数、更新日時とともに一覧表示される
20. 適用アイコン（↩️）をタップすると、現在のタイムラインをテンプレート内容で置き換える（確認ダイアログが表示される）
21. テンプレート名をタップするとインライン編集モードになり、名前を変更できる
22. ゴミ箱アイコンでテンプレートを削除できる

操作の意味は次のとおりです。

- `action`: 時間を消費する行動。`duration` が 5 分以上で保持されます
- `actionPoint`: 時間を消費しない節目。`duration` は 0 分です
- 総所要時間: すべての `action` / `actionPoint` の `duration` 合計をヘッダーに表示します
- 開始時刻ラベル: 目標時刻から逆算した各ブロックの開始時刻です
- 目標時刻: アンカー左側の時刻ラベル、または編集シートの「目標時刻」フィールドをタップすると、プラットフォーム標準の time picker で指定できます
- インライン編集中の次タップ: まずカーソルを外して編集を確定し、その次のタップで編集シート表示や追加操作に進みます
- rail double tap insert: 左 timeline rail をダブルタップすると、タップした block の上半分では過去側境界、下半分では未来側境界に `action` を挿入する。`actionPoint` でも同様に上/下で前後の境界へ挿入できる。target anchor の rail をダブルタップすると target 直前に挿入される

## Best Practices

- 目的地到着や会議開始など、動かしたくない時刻をまず「目標時刻」に置く
- 所要時間があるものは `action`、節目だけ示したいものは `actionPoint` で分ける
- 大きな工程の間に `actionPoint` を挟むと、逆算結果の読みやすさが上がる
- 数分単位で粗く詰めたあと、長押しドラッグで 1 分刻みの微調整に入る
- 現在の画面は Repository へ未接続のため、再起動で状態が消える。検討中の内容は UI 接続が完了するまで別途メモへ残す
- 微調整に入るときは、長さ調整ハンドルを止めたまま約 400ms 長押ししてから上下へ動かす
- 14〜16時間程度の長い計画を組むときは、Compact Overview ビューに切り替えると一覧性が高まる
- Compact Overview では所要時間に比例した高さではなく、すべての行が固定高さで表示される

## Troubleshooting

- 目標時刻 picker が開かない:
  目標名のインライン編集中は、先にフォーカスを外してから時刻ラベルまたは編集シートの時刻フィールドをタップする
- 所要時間を短くしすぎた:
  `action` の最小所要時間は 5 分に丸められる
- アプリ再起動後に内容が消えた:
  永続化 Repository は実装済みですが、現状の画面には未接続のため仕様どおり
- 並び替えの開始タイミングがわかりづらい:
  通常の長押しより短い 200ms で並び替え開始する実装になっている
- ドラッグ中に細かく合わせにくい:
  ハンドルに触れて約 400ms 静止すると precise モードへ入り、1 分単位で調整できる
- インライン編集中に詳細シートがすぐ開いてしまう:
  現在は次の 1 タップをフォーカス解除に使うため、続けて同じ場所をタップすると編集シートや追加操作に進める
- rail のダブルタップで挿入位置が意図と違う:
  double tap insert は「タップ位置の正確な時刻」ではなく「最も近い block 境界」へ挿入する。既存 block を分割したり、タップ位置の時刻に固定したりしない
- rail double tap が効かない:
  インライン編集中や詳細編集シート表示中は無効化されている。フォーカスまたはシートを閉じてから再試行する
- 検索で一致しない:
  検索対象は現在の plan 内の `Block.title` のみ。空タイトル、説明文、メモ、時刻は検索対象外
- 検索ジャンプ後に詳細編集シートが開かない:
  検索ハイライトは選択状態と分離しているため、詳細編集シートは自動表示されない。編集したい場合は block をタップして選択する
- 検索中にインライン編集やシートが閉じる:
  検索開始時に既存のフォーカス、詳細編集シート、plan panel は自動的に閉じられる。ジャンプ先が UI で隠れないようにするための挙動

## References

- `README.md`
- `_docs/guide/flutter/environment_setup.md`
- `_docs/reference/backcast/timeline_domain_reference.md`
- `_docs/reference/backcast/persistence_repository_reference.md`
- `_docs/intent/backcast/reverse_timeline_interaction_model.md`
- `_docs/intent/backcast/drift_persistence_repository.md`
- `lib/main.dart`
- `lib/timeline_screen.dart`
- `lib/block_item.dart`
- `lib/edit_sheet.dart`
