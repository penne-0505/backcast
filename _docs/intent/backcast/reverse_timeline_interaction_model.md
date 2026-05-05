---
title: Reverse Timeline Interaction Model
status: active
draft_status: n/a
created_at: "2026-04-20"
updated_at: "2026-04-23"
references:
  - README.md
  - _docs/guide/backcast/timeline_editor.md
  - _docs/reference/backcast/timeline_domain_reference.md
  - _docs/reference/backcast/persistence_repository_reference.md
  - _docs/intent/backcast/drift_persistence_repository.md
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
- 所要時間調整はドラッグ主体にしつつ、長押しで precise モードへ入り 1 分単位調整を可能にする
- 並び替えは Flutter 標準の `SliverReorderableList` を使い、開始遅延を 200ms に短縮する

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

## Rationale

- 目標時刻アンカーを UI 上の基準点に固定すると、すべての計算が「その直前に何を置くか」に統一される
- `computeBlocks` を純粋関数として切り出すことで、表示と計算の整合性をテストで担保しやすい
- `actionPoint` を 0 分ブロックとして扱うと、通過点を増やしても逆算アルゴリズム自体を複雑化せずに済む
- インライン編集は試行錯誤を速くし、編集シートは値を落ち着いて調整したい場面を支える
- フォーカス中の次タップを解除専用にすると、意図せず編集シートを開いて文脈が切り替わる事故を減らせる
- precise ドラッグは、荒い調整と細かい調整を 1 つのジェスチャで両立できる

## Consequences / Impact

- 現在の画面はまだ Repository へ接続されていないため、アプリ再起動後の自動復元は後続実装が必要
- 逆算表示は軽量で、`blocks` と `targetTime` さえあれば一貫した再計算が可能
- UI の多くがジェスチャ依存であるため、将来的にはアクセシビリティやキーボード操作の補強が必要
- `applyStartTimeEdit` のような拡張点を用意しているため、開始時刻直接編集機能を比較的追加しやすい
- モデルが簡潔なぶん、現時点では固定開始イベントや複数日スケジュールの表現力は持たない

## Rollback / Follow-ups

- もし逆向き UI が利用者にとって理解しづらい場合は、前向き表示モードの併設を検討する
- Drift Repository を `TimelineNotifier` へ接続し、起動時復元・自動保存・プラン選択 UI を追加する
- `deleteBlock`、`moveBlock`、`applyStartTimeEdit` を使う追加 UI を設ける場合は、ガイドとリファレンスも同期更新する
- 端末入力方式の差異に備え、将来的にはタッチ以外の編集導線も追加する
