---
title: Medo Timeline Editor Guide
status: active
draft_status: n/a
created_at: "2026-04-20"
updated_at: "2026-05-23"

references:
  - README.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/reference/medo/persistence_repository_reference.md
  - _docs/intent/medo/reverse_timeline_interaction_model.md
  - _docs/intent/medo/drift_persistence_repository.md
  - _docs/intent/medo/reorder_placement_preview.md
related_issues: []
related_prs: []
---

## Overview

`Medo` のタイムラインエディタを使って、目標時刻から逆算した行動計画を組み立てるためのガイドです。
現状のアプリは 1 画面構成で、タイムラインの編集、詳細編集シート、timeline list island modal を行き来しながら状態を更新します。
編集ビューに加え、同じタイムラインを低密度で読む **俯瞰** 表示が利用できます。
Drift / SQLite ベースの永続化 Repository は画面に接続済みで、現在の plan は自動保存され、アプリ起動時には最後に開いた plan が復元されます。Flutter Web では browser storage 上の Drift database を使うため、同一 origin 内では reload 後も plan が維持されます。

現行 UI の配色は、`Canvas #F6F5F2` を基調に、`Soft Gray #DDD9D0`、`Ink #26241F`、補助テキスト用の `Muted Ink #6F6A61`、`Accent / Olive #8A9864`、`Dark Surface #1F211C` を使う固定パレットです。ブロック色は `#7898B4`, `#B48268`, `#B4A260`, `#987CA8`, `#68A294` の順で循環します。

## Prerequisites

- Flutter 開発環境が利用できること
- 依存パッケージが取得済みであること
- Linux desktop や Chrome など、Flutter アプリを起動できるターゲットがあること

## Setup / Usage

まず依存関係を取得し、アプリを起動します。

```bash
/home/penne/sdk/flutter/flutter/bin/flutter pub get
/home/penne/sdk/flutter/flutter/bin/flutter run -d linux
```

Flutter Web の最低限の起動確認は次のコマンドで行います。

```bash
/home/penne/sdk/flutter/flutter/bin/flutter build web
/home/penne/sdk/flutter/flutter/bin/flutter run -d chrome
```

起動後の基本操作は以下のとおりです。

1. タイムライン下端の「目標時刻」カードを編集する
2. 画面上部の追加ボタンで、目標より前に置く行動を追加する
3. `action` では行動名と所要時間を編集する
4. `actionPoint` では通過点やチェックポイント名を編集する
5. 行動ブロック上端のドラッグハンドルで所要時間を調整する
6. ブロック本体をタップして編集シートを開き、詳細を調整する。編集シートでは行動ブロックと行動ピンを切り替えられる。Pro では行動ブロック本体の下側をダブルタップすると余裕時間を 5 分ずつ追加できる
7. 行動ブロックまたは行動ピンを右へスワイプすると、その block を削除できる。削除直後はヘッダー下に通知が出て、`元に戻す` で削除前の位置へ復元できる
8. 移動ハンドルを長押し気味に並び替えると、押下位置近くに影付きの小さい preview が出て、元 block は通常リストから消える。timeline 上の挿入線で移動先を確認しながら順序変更でき、画面上端/下端へ近づけると自動スクロールする
9. 左下の timeline list button の上にある表示切り替えボタンで **俯瞰** に移動し、全体構成を一覧する
10. 俯瞰では同じ timeline renderer を低密度で表示し、細部編集や並び替えは行わない
11. 同じ表示切り替えボタンで詳細編集へ戻る
12. 編集ビュー左の timeline rail（48px の左側領域）をダブルタップすると、最も近い block 境界に新しい `action` block を挿入できる
13. ヘッダーの検索アイコン（🔍）をタップして、block タイトル検索を開く
14. 検索バーにキーワードを入力すると、現在の plan 内の `Block.title` が部分一致で検索される
15. `1/3` のような件数表示を確認し、↑↓ ボタンまたはキーボードの検索ボタンで前後の一致結果へ移動できる
16. 検索ジャンプ後、対象 block の始点が上部に少し余白を持って見える位置へ自動スクロールし、3 秒間一時ハイライトされる
17. 検索バーの ✕ ボタン、フォーカス外し、または他のタイムライン操作で閉じると検索状態がクリアされる
18. 表示密度は詳細編集と俯瞰の二段階で切り替える。連続 slider は主導線として使わない
19. ヘッダーのエクスポートアイコンをタップして、カレンダー登録、テキスト共有、画像共有を開く
   - カレンダー登録は、同じタイムラインを同じ対象日に登録済みの場合、Medo が前回作成した event group を削除してから現在の内容を再登録する
1. Pro では編集ビュー下部ツールバーのテンプレートアイコンをタップして、テンプレート popover を開く。Free ではこのボタンは表示されない
2. 「現在のタイムラインを保存」ボタンで保存フォームを開き、テンプレート名を入力して保存する。保存前に現在の timeline は確定保存され、空欄で保存した場合は `無題のテンプレート` になる
3. 保存済みテンプレートは名前、目標ラベル、目標時刻、ブロック数、更新日時とともに一覧表示される
4. 適用アイコン（↩️）をタップすると、現在のタイムラインをテンプレート内容で置き換える（確認ダイアログが表示される）
5. テンプレート名をタップするとインライン編集モードになり、名前を変更できる
6. ゴミ箱アイコンでテンプレートを削除できる
7. 編集ビュー下部左の stack アイコンをタップすると、画面下部に浮く timeline list island modal が開く
8. timeline list island modal で保存済みタイムラインを選ぶと、現在の編集内容を保存してから選択したタイムラインへ切り替わる
9. `新しいタイムライン` をタップすると modal 上部に作成フォームが開き、名前を入力して作成できる。空欄で作成した場合は `無題のタイムライン` になる
10. timeline row の編集アイコンで名前をインライン変更できる。空欄で確定した場合は `無題のタイムライン` になる
11. timeline row のゴミ箱アイコンで削除確認ダイアログを開き、確認後に削除できる。現在の timeline を削除した場合は残っている timeline、なければ新しい空 timeline へ切り替わる
12. Free は2件まで、Pro は無制限にタイムラインを作成できる。Free で2件保存済みの場合、新規作成ボタンは無効になる

操作の意味は次のとおりです。

- `action`: 時間を消費する行動。`duration` が 5 分以上で保持され、Pro では `bufferMinutes` をバッファセグメントとして設定できます
- `actionPoint`: 時間を消費しない節目。ブロックからピンへ切り替えた場合、ブロックへ戻すための所要時間と余裕時間は内部に保持されます
- `action` の余裕時間: 実作業の `duration` とは別に 5 分刻みで保持します。表示・計算上の上限は 60 分、かつ行動本体より 5 分以上短い値です。行動時間を一時的に短くして上限に収まらない場合でも元の余裕時間は保持され、行動時間を伸ばすと再び反映されます。編集シートの「余裕時間」ステッパーまたはブロック本体下部のダブルタップで余裕時間を手動編集すると、その時点の値が新しい意図として保存されます
- 総所要時間: すべてのブロックの有効所要時間（`action` は `duration + bufferMinutes`、`actionPoint` は 0 分）の合計をヘッダーに表示します
- 開始時刻ラベル: 目標時刻から逆算した各ブロックの開始時刻です
- 現在時刻 marker: 編集ビューでは、現在時刻がタイムライン範囲内にある場合だけ左 timeline rail 上に `now` / `HH:mm` label / dot / 短い marker を表示します。カード本文を横断する線は使わず、現在進行中の `action` block は precise drag の影響範囲表示と同じ `accentOlive` outline で補助表示します。現在時刻が行動間の境界に一致する場合は、時間的に前の `action` block だけを現在対象として扱います
- 目標時刻: アンカー左側の時刻ラベル、または編集シートの「目標時刻」フィールドをタップすると、プラットフォーム標準の time picker で指定できます
- 表示密度: 詳細編集は `kPixelsPerMinute`、俯瞰は `kOverviewPixelsPerMinute` を使う二段階の一時 UI 状態です。詳細編集は細部操作、俯瞰は全体の順序・時刻・所要時間の読み取りに使います。移動ハンドルの長押しによる並び替え中も timeline 本体の密度は変えず、持っている block は影付きの小さい preview、移動先は moving block を除いた timeline 上の挿入線で示します。viewport 上端/下端付近で指を保つと、preview と挿入線を維持したまま上下へ自動スクロールします
- インライン編集中の次タップ: まずカーソルを外して編集を確定し、その次のタップで編集シート表示や追加操作に進みます
- 詳細編集シート: 背景 scrim を伴う Work Surface として表示されます。上部のハンドルを下へドラッグするか、背景 scrim / ✕ ボタンで閉じられます。選択中の行動は「ブロック / ピン」で種類を切り替えられ、ピン状態では所要時間と余裕時間の editor は非表示になります。標準表現は scrim のみで、背景 blur は使いません
- 一時 UI 表示中の外側タップ: ポップアップ、popover、overlay、panel、modal の外側をタップした場合、その 1 タップは閉じるためだけに使います。背面の追加、選択、画面遷移、別ヘッダー action は同時には発火せず、必要なら次のタップで実行します
- rail double tap insert: 左 timeline rail をダブルタップすると、タップした block の上半分では過去側境界、下半分では未来側境界に `action` を挿入する。`actionPoint` でも同様に上/下で前後の境界へ挿入できる。target anchor の rail をダブルタップすると target 直前に挿入される
- swipe delete: 編集ビューの `action` / `actionPoint` を右へスワイプすると、その block が timeline から削除され、ヘッダー下に上部 SnackBar が表示される。`元に戻す` を押すと、削除前の index へ同じ block data を復元する。連続削除時は最新の削除だけが復元対象になる。インライン編集中、詳細編集シート表示中、所要時間の precise drag 中は誤操作防止のため削除しない
- ヘッダーのエクスポート: タイムライン保存・読み込みは扱わず、カレンダー登録、テキスト共有、画像共有だけを開く。Quick Overlay として背景 scrim / blur は置かず、透明な吸収レイヤーと surface の shadow / border で読み分ける。表示中に別のヘッダー action を押した場合は、まずエクスポートパネルだけを閉じ、その action は次のタップで実行する
- template popover: Pro の編集ビュー下部ツールバーから開く浮遊 UI。画面下端から全幅で立ち上がる sheet ではなく、ツールバー直上の island として表示される。背景 scrim は置かず、ツールバーや timeline の別 action を押すと、まず popover だけを閉じ、その action は次のタップで実行する
- timeline list island modal: 下端に接地しない浮遊モーダルとして表示され、背景 scrim のタップまたは ✕ ボタンで閉じられる。上部の作成フォームで新規 timeline を命名でき、既存 row では rename / delete を扱う。表示中は block 追加 toolbar、詳細編集シート、テンプレート popover と同時表示しない
- template popover: Pro の編集ビュー下部ツールバーから開く。保存入口を押すと上部にテンプレート名フォームが表示され、現在 timeline title を既定名として使う。保存時は current plan の pending autosave を flush してから現在状態をテンプレート化する

SnackBar を短時間の一時通知として使う場合、`SnackBarAction` を付けると Flutter の標準挙動により `duration` だけでは自動で閉じないことがある。`元に戻す` のような action 付き通知を timeout させる仕様では、`persist: false` の明示に加え、画面側で同一通知かどうかを確認する timer cleanup と widget test を置き、timeout 後に action が無効化されることまで検証する。

## Best Practices

- 目的地到着や会議開始など、動かしたくない時刻をまず「目標時刻」に置く
- 所要時間があるものは `action`、節目だけ示したいものは `actionPoint` で分ける
- 遅延しやすい移動や準備は、実作業の `duration` を膨らませるのではなく余裕時間として分けると、どこが実時間でどこがバッファかを後から読み返しやすい
- 大きな工程の間に `actionPoint` を挟むと、逆算結果の読みやすさが上がる
- 数分単位で粗く詰めたあと、長押しドラッグで 1 分刻みの微調整に入る
- 複数案を比較したいときは、timeline list island modal から新しいタイムラインを作り、既存案を残したまま切り替える
- 微調整に入るときは、長さ調整ハンドルを止めたまま約 400ms 長押ししてから上下へ動かす
- 14〜16時間程度の長い計画を組むときは、左下の表示切り替えボタンで俯瞰に切り替えると一覧性が高まる
- 俯瞰では通常の timeline renderer を低密度で表示し、編集操作は詳細編集へ戻して行う
- 遠い位置へ block を移動するときは、移動ハンドルを押さえたまま preview と挿入線を見ながら、画面上端/下端付近で自動スクロールさせる。全体の構成を先に読みたい場合は、左下の表示切り替えで俯瞰に入ってから詳細編集へ戻す

## Troubleshooting

- 目標時刻 picker が開かない:
  目標名のインライン編集中は、先にフォーカスを外してから時刻ラベルまたは編集シートの時刻フィールドをタップする
- 所要時間を短くしすぎた:
  `action` の最小所要時間は 5 分に丸められる
- 右スワイプで消した行動を戻したい:
  削除直後にヘッダー下へ出る `元に戻す` を押す。通知が消えた後や、連続削除で次の削除通知に差し替わった後は、その削除は復元対象外になる
- 余裕時間を編集できない:
  余裕時間の新規編集は Pro 機能です。Free では既存の余裕時間は表示・逆算・共有に反映されます。ブロック本体のダブルタップでは短い SnackBar だけを表示し、詳細編集シートのロック表示をタップした場合だけ Paywall に遷移します
- 行動ブロックをダブルタップしても余裕時間が増えない:
  ダブルタップ対象はタイトル入力欄ではなく、行動ブロック本体の下側です。インライン編集中、詳細編集シート表示中、所要時間の precise drag 中は無効化されます
- アプリ再起動後に期待したタイムラインが開かない:
  最後に開いた plan が削除済み、または current plan preference が未保存の場合は、更新日時が最も新しい plan が開かれる
- Flutter Web で reload 後にタイムラインが復元されない:
  配信元 origin が変わると別 database として扱われる。`localhost` と `127.0.0.1`、port 違い、本番 domain はそれぞれ別 storage になる
- Flutter Web で database 初期化に失敗する:
  `web/sqlite3.wasm` と `web/drift_worker.dart.js` が配信されていること、特に `sqlite3.wasm` が `application/wasm` で返ることを確認する
- Flutter Web で画像共有、カレンダー登録、購入復元が期待通りに動かない:
  初期 Web 対応では Drift 永続化を最小目標としており、native 共有、native calendar、RevenueCat SDK に依存する導線は完全対応の対象外です
- 並び替えの開始タイミングがわかりづらい:
  移動ハンドルに触れた瞬間ではなく、短い hold が成立した時点で小さい preview と挿入線が出る。timeline 本体は縮小しないため、表示密度が変わることを開始合図にはしない
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
- テンプレートボタンが見つからない:
  テンプレート入口は Pro の編集ビュー下部ツールバーだけに表示される。Free 状態では保存済みテンプレートデータを削除せず、入口だけ非表示になる
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
