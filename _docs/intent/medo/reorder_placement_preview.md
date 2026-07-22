---
title: Reorder Placement Preview
status: active
draft_status: n/a
created_at: "2026-05-16"
updated_at: "2026-05-23"
references:
  - _docs/plan/UI/reorder-overview-scaling.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/intent/medo/timeline_compact_overview.md
related_issues: []
related_prs: []
---

## Context

詳細編集ビューでは、移動ハンドルから素早く並び替えを始められる一方、長時間 block を動かすと、元 block の大きさや placeholder が挿入先の前後関係を読み取りにくくします。

当初は並び替え中だけ timeline 全体を `kOverviewPixelsPerMinute` 相当へ縮小する案を検討しました。しかしこの案は、見た目の縮小、drag gap、dragged proxy、挿入判定を Flutter の reorder internals と同期させる必要があり、実装の安定性に対して得られる効果が小さい状態でした。

## Decision

- 並び替え中も timeline 本体の `pixelsPerMinute` は変更しない
- 持っている block は `TimelineScreen` の local overlay に小さい dragged block preview として表示する
- dragged block preview には shadow を付け、通常リストから外れた一時 surface として読めるようにする
- 挿入先は visible item の `RenderBox` 境界から推定し、timeline 上の insertion line として表示する
- `_QuickReorderListener` は 200ms の `LongPressGestureRecognizer` が成立した後だけ preview 開始を通知し、その後の pointer position を親へ渡す
- 移動中の source block は通常リストでは `Offstage` にし、挿入位置の geometry 判定からも除外する
- pointer が timeline viewport の上端/下端へ近づいた場合は、`TimelineScreen` が端部自動スクロールを所有し、preview と insertion line を維持したまま未表示位置へ移動できるようにする
- pointer up で candidate insert index を `TimelineNotifier.moveBlockByIndex` に渡し、pointer cancel では state を変更せず preview だけ解除する

## Alternatives

- 並び替え中だけ overview density へ縮小する案は、長時間 block の視野は広がるが、Flutter reorder internals との同期負荷が高いため不採用
- 俯瞰表示を直接 reorder 可能にする案は、読む状態と触る状態の境界を曖昧にするため不採用
- dragged proxy だけを小型化する案は、Flutter 側の placeholder / hit testing と視覚表現の差が大きくなりやすいため、主表示を独自 preview へ分離した

## Rationale

この変更の目的は「timeline 全体を広く見せること」ではなく、「何を持っていて、どこに入るのかを見失わないこと」です。
そのため、block 本体を変形させるより、持っている対象と挿入先を別レイヤーの feedback として分ける方が、既存の時間比例 renderer と reorder model を壊しにくくなります。

## Consequences / Impact

- `TimelineState.viewMode` と保存対象の `pixelsPerMinute` は並び替え中も変わらない
- preview / pointer position / insertion line は `TimelineScreen` の transient UI state に閉じる
- 挿入線は moving block を除いた visible item の実測境界に基づく推定 feedback であり、pointer up 時の `moveBlockByIndex` が最終順序を決める
- 移動ハンドル以外の duration drag、swipe delete、inline edit は preview を発火させない
- preview が出ている間は long press gesture が成立済みであるため、移動ハンドル上の上下移動は通常スクロールとしては処理されない。ただし viewport 端部では `TimelineScreen` の reorder 専用 auto-scroll が scroll offset を更新する
- 端部自動スクロールでも不足する遠距離移動の読み取りは、別の navigation / reorder 補助として扱う

## Rollback / Follow-ups

- 問題が出た場合は overlay preview と insertion line を外し、通常リストの表示だけに戻せる
- 線だけでは挿入意図が弱い場合は、line 横に小さい補助 pill を追加する
- 端部自動スクロールの速度や遠距離移動の読み取りが不足する場合は、preview 本体ではなく reorder navigation の別 task として扱う
