---
title: Action Buffer Time
status: proposed
draft_status: n/a
created_at: "2026-05-10"
updated_at: "2026-05-10"
references:
  - TODO.md
  - _docs/plan/Core/pro-free-gate.md
  - _docs/plan/Core/calendar-registration-enhancement.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/reference/medo/persistence_repository_reference.md
  - _docs/reference/medo/calendar_export_reference.md
  - _docs/reference/medo/text_export_reference.md
  - _docs/reference/medo/image_export_reference.md
related_issues: []
related_prs: []
---

## Overview

Medo の `action` block に、実所要時間とは別の「バッファ時間」を持たせる。

バッファは独立した通常 block ではなく、各 action の不確実性・遅れ吸収のための余裕として扱う。逆算計算では `duration + bufferMinutes` を消費時間として使い、UI では action 本体とバッファ部分を同一 block 内で視覚的に分離して表示する。

この機能は Pro 価値として扱う。Free でも既存 buffer は削除せず、計算にも反映するが、新規追加・編集はできない。時間管理が苦手なユーザーが日常的に行う「余裕を積む」操作を、詳細設定ではなく第一級の編集操作として扱う。

## Decisions

- buffer は `action` block のみが持てる。`actionPoint` は常に `bufferMinutes = 0` 相当として扱う。
- buffer は通常の `action` と同列の並び替え対象にはしない。
- block 本体のダブルタップで、対象 action の buffer を 5 分増やす。
- ダブルタップは action body のみを対象とし、duration handle、reorder handle、timeline rail、actionPoint には適用しない。
- 選択時にだけ出る mini control は採用しない。スマホ UI と相性が悪く、既存 gesture と衝突しやすいため。
- 詳細編集シートには、冗長かつ正確な buffer 編集 UI を置く。
- buffer の step は 5 分単位、action 1件あたりの上限は 60 分とする。
- block 高さと逆算計算には `duration + bufferMinutes` を使う。
- UI では buffer 部分を action 本体より少し横幅を減らした別枠として描画し、通常の行動時間と見分けられるようにする。
- カレンダー登録では buffer を予定時間に含める。
- テキスト共有・画像共有では buffer を明示する。
- テンプレート保存・適用では buffer を保持する。
- 比較案ビューは本計画の対象外とし、後続計画から buffer の合計・内訳を参照する。

## Scope

- `Block` model に `bufferMinutes` を追加する。
- `TimelineState` の encode / decode と snapshot schema を更新する。
- Drift schema に `plan_blocks.buffer_minutes` と `timeline_template_blocks.buffer_minutes` を追加する。
- 既存データ migration では buffer を 0 分で補完する。
- `computeBlocks()` 相当の逆算計算で、action の消費時間を `duration + bufferMinutes` にする。
- action block の表示で、通常時間部分と buffer 部分を区別する。
- action block 本体のダブルタップで buffer を 5 分増やす。
- 詳細編集シートで buffer を 5 分単位で編集できるようにする。
- Free / Pro gate を action 境界で実装する。
- テンプレート、カレンダー登録、テキスト共有、画像共有で buffer を保持・表示・反映する。
- 関連する guide / reference / README を実装結果に合わせて更新する。

## Non-Goals

- 全体バッファ。
- actionPoint への buffer 付与。
- block ごとの割合バッファや自動バッファ提案。
- AI による buffer 推定。
- 選択時に表示する inline mini control。
- buffer 専用 drag handle。
- カレンダー登録時に buffer を別イベントとして登録する設定。
- 比較案ビュー、二列比較 UI、採用 / 編集ボタン。
- クラウド同期や Supabase schema の変更。
- Pro から Free へ戻った時の既存 buffer データ削除。

## Data Model

### `Block`

- `duration`: 行動そのものに必要な実所要時間。
- `bufferMinutes`: 行動に付ける余裕時間。既定値は 0。
- `effectiveDuration`: 逆算計算で使う時間。`action` では `duration + bufferMinutes`、`actionPoint` では 0。

`bufferMinutes` は 5 分単位で保存し、0 以上 60 以下に丸める。既存 action は migration / decode 時に `bufferMinutes = 0` として扱う。

### Persistence

- `plan_blocks.buffer_minutes integer not null default 0`
- `timeline_template_blocks.buffer_minutes integer not null default 0`

`TimelineState` snapshot JSON は後方互換を維持する。古い snapshot に `bufferMinutes` が存在しない場合は 0 として decode する。

## Interaction Model

### Direct Editing

action block 本体をダブルタップすると、buffer を 5 分増やす。

- Pro かつ `bufferMinutes < 60` の場合: `bufferMinutes += 5`
- Pro かつ `bufferMinutes = 60` の場合: 変更せず、必要なら上限到達を軽く示す
- Free の場合: buffer は変更せず、block 本体ダブルタップでは短い SnackBar で未解放の操作であることだけを示す。Paywall への遷移は詳細編集シートのロック表示など、明示的な UI からだけ行う
- actionPoint の場合: 何もしない
- inline title edit、duration drag、reorder、swipe delete、rail double tap insert の最中は実行しない

ダブルタップとシングルタップの競合に注意する。ダブルタップ時に詳細編集シートが先に開かないよう、GestureDetector の tap / double tap 境界を明示する。

### Detail Sheet

詳細編集シートには、所要時間の近くに buffer 編集 UI を置く。

- 表示例: `余裕時間 +10分`
- 5 分単位の stepper または同等の compact control を使う。
- 0 分に戻せる。
- 60 分を超えない。
- Free では編集不可とし、タップ時は Pro 説明 / paywall へ誘導する。

詳細編集シートは、減らす操作、大きな変更、正確な確認のための冗長導線として扱う。主要な追加操作は block 本体のダブルタップで行う。

## Visual Model

action block は `duration + bufferMinutes` に応じた高さで描画する。

buffer が 0 分の場合は現状に近い表示を維持する。buffer がある場合は、同一 block 内に buffer 用の別枠を表示する。

- action 本体部分: 現在の block 表現を主に維持する。
- buffer 部分: action 本体より少し横幅を減らし、薄い背景、点線、補助ラベルなどで別枠として示す。
- 表示文言例: `余裕 +10分`
- buffer 部分は操作 handle として扱わない。

横幅を少し減らす理由は、buffer が通常の行動そのものではなく、行動に付いた余裕であることを視覚的に区別するためである。色だけで区別すると視認性やアクセシビリティが弱くなるため、形状差も使う。

## Pro / Free Behavior

- Pro は buffer を追加・編集できる。
- Free は buffer を追加・編集できない。
- Pro 中に設定された buffer は、Free に戻っても削除しない。
- Free に戻っても既存 buffer は逆算計算・表示・共有・カレンダー登録に反映する。
- billing loading / error 中は Free 相当として扱い、新規 buffer 追加・編集はできない。

Free への縮退で計算から buffer を外すと、開始時刻が急に変わるため避ける。ユーザーデータの破壊だけでなく、予定の安全性も損なうため、既存 buffer は read-only の計画情報として保持する。

## Export / Sharing

### Calendar

カレンダー登録では buffer を予定時間に含める。

例: `移動 duration=25, buffer=10` の場合、カレンダー上のイベント duration は 35 分とする。説明欄または title 補助に `25分 + 余裕10分` 相当を含めるかは実装時に UI / payload の読みやすさで決める。

### Text Share

テキスト共有では、buffer がある action だけ余裕を明示する。

例: `08:15 移動 25分 + 余裕10分`

### Image Share

画像共有では、編集画面と同じく buffer 部分を別枠として描画する。画像内でも行動時間と余裕時間が混ざって見えないようにする。

### Templates

テンプレート保存では `bufferMinutes` を保持する。テンプレート適用時も、action の buffer を復元する。これにより、よく使う予定の「どこに余裕を置くか」まで再利用できる。

## Requirements

- **Functional**: action block は `bufferMinutes` を持てる。
- **Functional**: actionPoint は buffer を持たない。
- **Functional**: 逆算計算は action の `duration + bufferMinutes` を使う。
- **Functional**: block 本体のダブルタップで buffer が 5 分増える。
- **Functional**: 詳細編集シートで buffer を 5 分単位で編集できる。
- **Functional**: buffer は 0 分から 60 分の範囲に収まる。
- **Functional**: Free では新規 buffer 追加・編集ができない。
- **Functional**: Free へ戻っても既存 buffer は削除されず、計算に反映される。
- **Functional**: テンプレート保存・適用で buffer が保持される。
- **Functional**: カレンダー登録は buffer を予定時間に含める。
- **Functional**: テキスト共有・画像共有は buffer を明示する。
- **Non-Functional**: 既存の duration drag、reorder、swipe delete、rail double tap insert、inline title edit と gesture が衝突しない。
- **Non-Functional**: buffer が 0 分の既存タイムラインでは、見た目と挙動の変化を最小化する。
- **Non-Functional**: migration は既存 plan / template / snapshot を破壊しない。
- **Non-Functional**: Pro / Free 判定は `effectiveIsProProvider` を source of truth とする。

## Tasks

1. `Block` model と codec に `bufferMinutes` を追加し、古い JSON を 0 分で decode できるようにする。
2. Drift schema version を更新し、`plan_blocks` と `timeline_template_blocks` に `buffer_minutes` を追加する migration を実装する。
3. `computeBlocks()` と関連する総所要時間表示を `duration + bufferMinutes` 対応にする。
4. `TimelineNotifier` に action buffer を 5 分単位で増減・設定する API を追加する。
5. action block 本体の double tap から buffer +5 分を実行する。
6. 詳細編集シートに buffer 編集 UI を追加する。
7. block 表示で buffer 部分を横幅の少し狭い別枠として描画する。
8. Free / Pro gate を double tap と詳細編集 action 境界に追加する。
9. テンプレート repository / apply service に buffer を接続する。
10. カレンダー登録、テキスト共有、画像共有に buffer を反映する。
11. unit / widget / repository / export tests を追加・更新する。
12. README、timeline editor guide、domain / persistence / export references を更新する。

## Test Plan

- Model / calculation
  - 古い JSON snapshot を decode すると `bufferMinutes = 0` になる。
  - action の `effectiveDuration` が `duration + bufferMinutes` になる。
  - actionPoint は buffer を持たず、逆算消費時間が 0 のままである。
  - buffer 0 / 5 / 60 の開始時刻計算が正しい。

- Persistence
  - migration 後、既存 `plan_blocks` は `buffer_minutes = 0` になる。
  - plan 保存 / 読み込みで buffer が保持される。
  - template 保存 / 適用で buffer が保持される。
  - snapshot restore で buffer が復元される。

- UI / gesture
  - Pro で action body を double tap すると buffer が 5 分増える。
  - actionPoint double tap では buffer が増えない。
  - Free で action body を double tap すると buffer は変わらず、Paywall ではなく短い SnackBar が表示される。
  - duration handle、reorder handle、timeline rail の操作と double tap buffer が競合しない。
  - double tap で詳細編集シートが誤って開かない。
  - 詳細編集シートで buffer を 0 分へ戻せる。
  - buffer が 60 分を超えない。

- Export / sharing
  - カレンダー登録 request の action duration に buffer が含まれる。
  - テキスト共有に `余裕` が明示される。
  - 画像共有で buffer 部分が別枠として表示される。

- Pro / Free downgrade
  - Pro 中に設定した buffer は Free に戻っても保持される。
  - Free 中の既存 buffer は計算に反映される。
  - Free 中は既存 buffer を編集できない。

## Deployment / Rollout

- schema migration があるため、debug build で既存 database からの起動と plan 読み込みを確認する。
- release 前に Android で gesture conflict を実機確認する。
- 不具合時は double tap 導線を一時的に無効化しても、既存 buffer の表示・計算・詳細シート編集を残せるようにする。
- この機能はローカル保存データの形を変えるが、クラウド送信範囲は変えない。ユーザーデータの扱いを変更する後続実装がある場合は `_docs/guide/medo/privacy_policy_operations.md` に従い privacy policy 更新要否を確認する。
