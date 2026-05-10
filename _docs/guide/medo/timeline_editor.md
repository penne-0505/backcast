---
title: Medo Timeline Editor Guide
status: active
draft_status: n/a
created_at: "2026-04-20"
updated_at: "2026-05-10"

references:
  - README.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/reference/medo/persistence_repository_reference.md
  - _docs/intent/medo/reverse_timeline_interaction_model.md
  - _docs/intent/medo/drift_persistence_repository.md
related_issues: []
related_prs: []
---

## Overview

`Medo` のタイムラインエディタを使って、目標時刻から逆算した行動計画を組み立てるためのガイドです。
現状のアプリは 1 画面構成で、タイムラインの編集、詳細編集シート、timeline list island modal を行き来しながら状態を更新します。
編集ビューに加え、固定高さ行でタイムライン全体を一覧する **Compact Overview** ビューが利用できます。
Drift / SQLite ベースの永続化 Repository は画面に接続済みで、現在の plan は自動保存され、アプリ起動時には最後に開いた plan が復元されます。

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
6. ブロック本体をタップして編集シートを開き、詳細を調整する。Pro では行動ブロック本体の下側をダブルタップすると余裕時間を 5 分ずつ追加できる
7. 行動ブロックまたは行動ピンを右へスワイプすると、その block を削除できる
8. 長押し気味に並び替えると、より過去・未来の位置へ順序変更できる
9. ヘッダーの切り替えボタンで **Compact Overview** ビューに移動し、全体構成を一覧する
10. Compact Overview で行をタップして選択し、上下ボタンで並び替える
11. 選択中の行をダブルタップ、または下部の「編集ビューへ」ボタンで編集ビューに戻る
12. 編集ビュー左の timeline rail（48px の左側領域）をダブルタップすると、最も近い block 境界に新しい `action` block を挿入できる
13. ヘッダーの検索アイコン（🔍）をタップして、block タイトル検索を開く
14. 検索バーにキーワードを入力すると、現在の plan 内の `Block.title` が部分一致で検索される
15. `1/3` のような件数表示を確認し、↑↓ ボタンまたはキーボードの検索ボタンで前後の一致結果へ移動できる
16. 検索ジャンプ後、対象 block の始点が上部に少し余白を持って見える位置へ自動スクロールし、3 秒間一時ハイライトされる
17. 検索バーの ✕ ボタン、またはフォーカスを外して閉じると検索状態がクリアされる
18. ヘッダーのエクスポートアイコンをタップして、カレンダー登録、テキスト共有、画像共有を開く
19. ヘッダーのテンプレートアイコン（🗂️）をタップして、テンプレート管理シートを開く
20. 「現在のタイムラインを保存」ボタンで、現在の目標時刻と行動一覧をテンプレートとして保存する
21. 保存済みテンプレートは名前、目標ラベル、目標時刻、ブロック数、更新日時とともに一覧表示される
22. 適用アイコン（↩️）をタップすると、現在のタイムラインをテンプレート内容で置き換える（確認ダイアログが表示される）
23. テンプレート名をタップするとインライン編集モードになり、名前を変更できる
24. ゴミ箱アイコンでテンプレートを削除できる
25. 編集ビュー下部左の stack アイコンをタップすると、画面下部に浮く timeline list island modal が開く
26. timeline list island modal で保存済みタイムラインを選ぶと、現在の編集内容を保存してから選択したタイムラインへ切り替わる
27. `新しいタイムライン` をタップすると modal 上部に作成フォームが開き、名前を入力して作成できる。空欄で作成した場合は `無題のタイムライン` になる
28. timeline row の編集アイコンで名前をインライン変更できる。空欄で確定した場合は `無題のタイムライン` になる
29. timeline row のゴミ箱アイコンで削除確認ダイアログを開き、確認後に削除できる。現在の timeline を削除した場合は残っている timeline、なければ新しい空 timeline へ切り替わる
30. Free は2件まで、Pro は無制限にタイムラインを作成できる。Free で2件保存済みの場合、新規作成ボタンは無効になる

操作の意味は次のとおりです。

- `action`: 時間を消費する行動。`duration` が 5 分以上で保持され、Pro では `bufferMinutes` を別枠で設定できます
- `actionPoint`: 時間を消費しない節目。`duration` は 0 分です
- `action` の余裕時間: 実作業の `duration` とは別に 0〜60 分、5 分刻みで保持します。編集シートの「余裕時間」ステッパーまたはブロック本体下部のダブルタップで増減できます
- 総所要時間: すべてのブロックの有効所要時間（`action` は `duration + bufferMinutes`、`actionPoint` は 0 分）の合計をヘッダーに表示します
- 開始時刻ラベル: 目標時刻から逆算した各ブロックの開始時刻です
- 目標時刻: アンカー左側の時刻ラベル、または編集シートの「目標時刻」フィールドをタップすると、プラットフォーム標準の time picker で指定できます
- インライン編集中の次タップ: まずカーソルを外して編集を確定し、その次のタップで編集シート表示や追加操作に進みます
- rail double tap insert: 左 timeline rail をダブルタップすると、タップした block の上半分では過去側境界、下半分では未来側境界に `action` を挿入する。`actionPoint` でも同様に上/下で前後の境界へ挿入できる。target anchor の rail をダブルタップすると target 直前に挿入される
- swipe delete: 編集ビューの `action` / `actionPoint` を右へスワイプすると、その block が timeline から削除される。インライン編集中、詳細編集シート表示中、所要時間の precise drag 中は誤操作防止のため削除しない
- ヘッダーのエクスポート: タイムライン保存・読み込みは扱わず、カレンダー登録、テキスト共有、画像共有だけを開く
- timeline list island modal: 下端に接地しない浮遊モーダルとして表示され、背景 scrim のタップまたは ✕ ボタンで閉じられる。上部の作成フォームで新規 timeline を命名でき、既存 row では rename / delete を扱う。表示中は block 追加 toolbar、詳細編集シート、テンプレートシートと同時表示しない

## Best Practices

- 目的地到着や会議開始など、動かしたくない時刻をまず「目標時刻」に置く
- 所要時間があるものは `action`、節目だけ示したいものは `actionPoint` で分ける
- 遅延しやすい移動や準備は、実作業の `duration` を膨らませるのではなく余裕時間として分けると、どこが実時間でどこがバッファかを後から読み返しやすい
- 大きな工程の間に `actionPoint` を挟むと、逆算結果の読みやすさが上がる
- 数分単位で粗く詰めたあと、長押しドラッグで 1 分刻みの微調整に入る
- 複数案を比較したいときは、timeline list island modal から新しいタイムラインを作り、既存案を残したまま切り替える
- 微調整に入るときは、長さ調整ハンドルを止めたまま約 400ms 長押ししてから上下へ動かす
- 14〜16時間程度の長い計画を組むときは、Compact Overview ビューに切り替えると一覧性が高まる
- Compact Overview では所要時間に比例した高さではなく、すべての行が固定高さで表示される

## Troubleshooting

- 目標時刻 picker が開かない:
  目標名のインライン編集中は、先にフォーカスを外してから時刻ラベルまたは編集シートの時刻フィールドをタップする
- 所要時間を短くしすぎた:
  `action` の最小所要時間は 5 分に丸められる
- 余裕時間を編集できない:
  余裕時間の新規編集は Pro 機能です。Free では既存の余裕時間は表示・逆算・共有に反映されます。ブロック本体のダブルタップでは短い SnackBar だけを表示し、詳細編集シートのロック表示をタップした場合だけ Paywall に遷移します
- 行動ブロックをダブルタップしても余裕時間が増えない:
  ダブルタップ対象はタイトル入力欄ではなく、行動ブロック本体の下側です。インライン編集中、詳細編集シート表示中、所要時間の precise drag 中は無効化されます
- アプリ再起動後に期待したタイムラインが開かない:
  最後に開いた plan が削除済み、または current plan preference が未保存の場合は、更新日時が最も新しい plan が開かれる
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
- timeline list island modal の新規作成が押せない:
  Free 状態で保存済みタイムラインが2件に達している。Pro に戻ると保持済みの超過タイムラインも再び利用できる
- timeline 削除後に別の timeline が開いた:
  削除対象が現在の timeline だった場合、削除済み ID を current plan として残さないため、残存 timeline または新しい空 timeline へ自動的に切り替える

## References

- `README.md`
- `_docs/guide/flutter/environment_setup.md`
- `_docs/reference/medo/timeline_domain_reference.md`
- `_docs/reference/medo/persistence_repository_reference.md`
- `_docs/intent/medo/reverse_timeline_interaction_model.md`
- `_docs/intent/medo/drift_persistence_repository.md`
- `lib/main.dart`
- `lib/timeline_screen.dart`
- `lib/block_item.dart`
- `lib/edit_sheet.dart`
