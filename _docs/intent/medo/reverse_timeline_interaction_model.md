---
title: Reverse Timeline Interaction Model
status: active
draft_status: n/a
created_at: "2026-04-20"
updated_at: "2026-05-12"
references:
  - README.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/plan/UI/template-toolbar-popover.md
  - _docs/standards/ui_layering.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/reference/medo/persistence_repository_reference.md
  - _docs/intent/medo/drift_persistence_repository.md
related_issues: []
related_prs: []
---

## Context

`Medo` は「いまから何を積むか」ではなく、「この時刻に間に合わせるには何が必要か」を先に考えるユースケースを扱います。
そのため、一般的な前向きスケジューラよりも、目標時刻を固定して過去方向へ必要工程を並べる UI のほうが、思考順序と一致しやすい状況があります。

また、現段階では仕様探索と操作感検証の比重が大きく、永続化や複雑なデータモデルより、即時に触って調整できる編集体験を優先したい事情があります。

## Decision

- タイムラインは目標時刻アンカーを下端に置き、上方向へ過去の行動を積み上げる
- ドメインモデルは `action` と `actionPoint` の 2 種類に絞る
- 逆算ロジックは `computeBlocks` に集約し、UI 表示時に毎回派生計算する
- 画面上の編集中状態は `TimelineNotifier` に集約し、永続化層とは Repository 経由で分離する
- 編集 UI はインライン編集と下部シート編集を併用する
- インライン編集中は次のタップをフォーカス解除に優先利用し、別アクションは次回タップに回す
- ポップアップ、popover、overlay、panel、modal などの一時 UI が開いている間に、その UI の外側がタップされた場合は、その 1 タップを閉じるためだけに消費し、背面や別ヘッダー action の本来操作は発火させない
- 所要時間調整はドラッグ主体にしつつ、長押しで precise モードへ入り 1 分単位調整を可能にする
- 並び替えは Flutter 標準の `SliverReorderableList` を使い、開始遅延を 200ms に短縮する
- 画面ボトムの追加 toolbar は一体型の板ではなく、各 action が独立した浮遊オブジェクトに見える形状で構成する
- ボトム toolbar に新しい action を追加する場合は、Liquid Glass 的な透明素材表現ではなく、circle / capsule / pill 系の形状、明確な余白、個別の shadow によって「それぞれが浮いている」関係を保つ
- テンプレートのような補助 action は、ヘッダーではなく編集ビュー下部ツールバーの独立ボタンから popover / island として開く
- 新しい非モーダル overlay / popover を追加する場合は、`AppShadows.quickOverlay` と Quick Overlay surface token を基準にする

## Alternatives

- 通常の上から下へ流れる前向きタイムライン:
  一般的ではあるが、「締切から逆算する」思考に対して毎回脳内変換が必要になるため不採用
- ブロック種別を増やし、固定時刻イベントやバッファなどを個別モデル化する:
  柔軟性は上がるが、現段階では複雑化のコストが大きいため不採用
- 全編集をモーダルシートに集約する:
  実装は単純になるが、軽い名称変更まで遠回りになるため不採用
- 画面ローカル `StatefulWidget` だけで状態を持つ:
  小規模でも成立するが、計算ロジックと UI の責務分離が弱くなるため不採用
- key-value store に単一 JSON を保存する:
  初期の単一タイムライン復元には十分だが、複数プラン保存・ロードと履歴閲覧が確実になったため不採用
- ボトム toolbar をひとつの長い container と区切り線でまとめる:
  action が同格の独立操作ではなく、同一バー内の分割領域に見えるため不採用。今後 item が増えるほど、主操作と補助操作の階層が曖昧になる
- テンプレート入口をヘッダーに残す:
  テンプレート適用は現在 timeline の編集内容を置き換える操作であり、検索・表示密度・export・設定と同じグローバル/画面補助 action に見えるため不採用

## Rationale

- 目標時刻アンカーを UI 上の基準点に固定すると、すべての計算が「その直前に何を置くか」に統一される
- `computeBlocks` を純粋関数として切り出すことで、表示と計算の整合性をテストで担保しやすい
- `actionPoint` を 0 分ブロックとして扱うと、通過点を増やしても逆算アルゴリズム自体を複雑化せずに済む
- インライン編集は試行錯誤を速くし、編集シートは値を落ち着いて調整したい場面を支える
- フォーカス中の次タップを解除専用にすると、意図せず編集シートを開いて文脈が切り替わる事故を減らせる
- 一時 UI の外側タップを閉じる専用の 1 ターンとして扱うと、ユーザーが「閉じたい」と思って触れた場所で、追加・選択・画面遷移まで同時に起きる事故を避けられる。この方針はインライン編集のフォーカス解除と同じ安全側の操作モデルとして扱う
- precise ドラッグは、荒い調整と細かい調整を 1 つのジェスチャで両立できる
- ボトム toolbar の各 action を独立した形状にすると、主要 action と補助 action の役割差を、色や説明文を増やさずに空間構成だけで伝えられる
- circle / capsule / pill は指で狙いやすい hit area を保ちつつ、画面下端に接地した system bar ではなく、編集キャンバス上に浮く操作群として認識させやすい
- ここで参照する Apple 的な要素は、透明・屈折・反射などの material ではなく、近年の toolbar / command 群に見られる「個別の self-contained な形状」の考え方に限定する
- ツールバー直上に popover として出すと、テンプレート管理が画面全体のモード変更ではなく、現在の編集作業へ差し込む補助操作として理解されやすい
- overlay surface は `AppColors.canvas` または `AppColors.cardBackground`、`AppRadius.xl`、`AppColors.softGray.withValues(alpha: 0.55)` 程度の border、`AppShadows.quickOverlay` を標準とする
- 非モーダル overlay は背景 scrim / blur を置かず、透明な吸収レイヤーで外側タップを閉じるための 1 ターンとして扱う。別 action が押された場合も、まず overlay を閉じ、その action の実行は次のタップに回す

## Consequences / Impact

- 現在の画面はまだ Repository へ接続されていないため、アプリ再起動後の自動復元は後続実装が必要
- 逆算表示は軽量で、`blocks` と `targetTime` さえあれば一貫した再計算が可能
- UI の多くがジェスチャ依存であるため、将来的にはアクセシビリティやキーボード操作の補強が必要
- `applyStartTimeEdit` のような拡張点を用意しているため、開始時刻直接編集機能を比較的追加しやすい
- モデルが簡潔なぶん、現時点では固定開始イベントや複数日スケジュールの表現力は持たない
- ボトム toolbar に action を追加する場合、既存の横幅へ無理に詰め込むのではなく、独立した item としての余白、最小 hit area、primary action の視認性を先に確認する必要がある
- toolbar item が増えて階層が曖昧になる場合は、全 item を横並びに増やすのではなく、主要 action の維持、補助 action の別面化、または別入口への分離を検討する
- テンプレート action を表示する Pro 状態では、narrow viewport で「前の行動を追加」の text label を省略して hit area を優先する場合がある
- overlay surface 値を増やす場合は、個別 UI で似た shadow / border を増殖させず、`AppShadows.quickOverlay` と `_docs/standards/ui_layering.md` の Quick Overlay Surface に集約する
- 新しい一時 UI を追加する場合は、閉じるための吸収レイヤー、または同等の gesture 消費を用意し、外側タップが背面操作へ貫通しないことを widget test で確認する

## Rollback / Follow-ups

- もし逆向き UI が利用者にとって理解しづらい場合は、前向き表示モードの併設を検討する
- Drift Repository を `TimelineNotifier` へ接続し、起動時復元・自動保存・プラン選択 UI を追加する
- `deleteBlock`、`moveBlock`、`applyStartTimeEdit` を使う追加 UI を設ける場合は、ガイドとリファレンスも同期更新する
- 端末入力方式の差異に備え、将来的にはタッチ以外の編集導線も追加する
- ボトム toolbar に 3 つ以上の action を置く場合は、追加前に mobile 幅で text overflow、tap target、primary action の優先度低下が起きないことを確認する
