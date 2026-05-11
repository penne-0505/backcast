---
title: Two Step Timeline Density
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - TODO.md
  - _docs/intent/medo/timeline_compact_overview.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
related_issues: []
related_prs: []
---

## Overview

タイムラインの拡大縮小を、連続 slider ではなく「詳細編集」と「俯瞰」の二段階切り替えに整理する。

ユーザーが実際に必要としている状態は、中間倍率の細かな調整ではなく、細部を触る編集状態と、全体の順序・時間配分を読む俯瞰状態である。
そのため、現在の zoom popover / pinch zoom を主導線から外し、既存の compact view toggle を下部到達しやすい位置へ移す。

通常の詳細編集は現状の `0.9x` 相当をデフォルト密度とし、俯瞰は現在の完全 compact overview を置き換える形で、編集画面と連続した低密度表示として扱う。

## Scope

- タイムライン表示密度を「詳細編集」と「俯瞰」の二段階にする。
- 詳細編集のデフォルト密度を現行最大値の `0.9x` 相当へ下げる。
- 俯瞰切り替えボタンを、左下のタイムライン切り替えボタンの上に配置する。
- ヘッダーの zoom / view mode 関連導線を整理し、よく使う表示切り替えを下部導線へ寄せる。
- 既存の完全 compact overview は、二段階 density の俯瞰状態へ置き換える。
- 検索、現在時刻インジケーター、block 選択、edit sheet、timeline list island、template popover と重ならない表示条件を整理する。
- 実装後に guide / reference / intent を実装結果へ同期する。

## Non-Goals

- 三段階以上の density preset を追加しない。
- 連続 slider を主要 UI として残さない。
- 俯瞰状態で block の直接編集、duration drag、reorder、inline edit を新規に追加しない。
- timeline list island の管理機能やデータモデルは変更しない。
- `plans` persistence schema は変更しない。
- 比較 view や alternative comparison とは統合しない。

## Requirements

- **Functional**: 初期状態の詳細編集密度は、現行 `kPixelsPerMinute` の `0.9x` 相当になる。
- **Functional**: ユーザーは左下のタイムライン切り替えボタンの上にある表示切り替えボタンから、詳細編集と俯瞰を切り替えられる。
- **Functional**: 詳細編集では既存の block 選択、edit sheet、duration drag、追加、削除、検索ジャンプが引き続き動作する。
- **Functional**: 俯瞰では全体の順序、時刻、所要時間、節目を読みやすくする。
- **Functional**: 俯瞰から詳細編集へ戻ったとき、同じ timeline の編集状態へ自然に戻れる。
- **Functional**: ヘッダーに拡大縮小の主操作を残さない。
- **Non-Functional**: 左下の timeline list button と表示切り替えボタンは、narrow viewport でも押下領域が重ならない。
- **Non-Functional**: gesture 競合を増やさない。pinch zoom は残す場合でも補助扱いとし、主導線にはしない。
- **Non-Functional**: density は plan persistence へ保存しない方針を維持する。

## UI Model

下部左側に二つの独立した浮遊ボタンを縦に配置する。

- 下: 既存のタイムライン切り替えボタン。
- 上: 詳細編集 / 俯瞰を切り替える表示ボタン。

表示切り替えボタンは、現在の状態を icon と active background で示す。
詳細編集時は overview を開く icon、俯瞰時は detailed list / edit view に戻る icon を使う。
推論だが、timeline list と表示切り替えを近接させると、ユーザーは左下を「今見ている timeline の文脈を切り替える場所」として学習しやすい。

俯瞰は、固定高さ row の完全別 view ではなく、通常 timeline と同じ構造を低密度で読む状態に寄せる。
ただし俯瞰中に細部編集の handle を出すと操作密度が上がりすぎるため、初期実装では詳細編集への復帰を前提に、読むことを優先する。

## Implementation Notes

1. `kPixelsPerMinute` または初期 `TimelineState.pixelsPerMinute` を見直し、詳細編集の初期値を現行最大値の `0.9x` 相当にする。
2. 二段階 density 用の定数を導入する。例: detailed density と overview density。
3. `TimelineNotifier.setPixelsPerMinute` は必要に応じて clamp 上限を新しい detailed density に合わせる。
4. `_ZoomDensityPopover` と `_zoomPopoverVisible` の主導線を削除または非表示化する。
5. `_PlanHeader` から zoom action を外し、ヘッダー幅の圧迫を減らす。
6. `_FloatingToolbar` 周辺ではなく、左下の `_TimelineListButton` の上へ表示切り替えボタンを配置する。
7. 既存 `TimelineViewMode.compact` の扱いを見直し、完全 `CompactOverviewView` への分岐を廃止するか、二段階 density の俯瞰状態として置き換える。
8. 俯瞰状態で不要な edit sheet / inline editor / precise drag state が残らないよう、切り替え時に transient UI を閉じる。
9. 検索ジャンプの scroll offset 計算が新しい density でも破綻しないことを確認する。
10. guide / reference / compact overview intent を実装結果に合わせて更新する。

## Test Plan

- Unit / notifier:
  - 初期 `TimelineState.pixelsPerMinute` が詳細編集の `0.9x` 相当である。
  - 表示切り替えで詳細編集 density と俯瞰 density が切り替わる。
  - density が保存対象の plan state として不要に永続化されないことを確認する。
- Widget:
  - ヘッダーに zoom action が表示されない。
  - 左下の timeline list button の上に表示切り替えボタンが表示される。
  - 表示切り替えボタンを押すと詳細編集と俯瞰が切り替わる。
  - narrow viewport で左下の二つの浮遊ボタンが overlap しない。
  - 俯瞰中に timeline list island を開いても表示切り替えボタンと競合しない。
- Interaction / regression:
  - 詳細編集で block tap、edit sheet、duration drag、reorder、右スワイプ削除が既存通り動作する。
  - 検索中に表示切り替えしても、検索 popover と highlight が破綻しない。
  - 俯瞰から詳細編集へ戻った後、block 編集へ入れる。
- Manual QA:
  - Android narrow viewport と標準 viewport で、左下二段ボタン、下部 toolbar、timeline list island、template popover の重なりを確認する。

## Deployment / Rollout

- schema migration は不要。
- 既存 compact overview の実装を残す場合でも、主導線からは外す。
- UI の収まりに問題が出た場合は、表示切り替えボタンを一時的にヘッダーへ戻すのではなく、左下のボタン間隔と toolbar 幅を調整して対応する。
- 実装完了後、`_docs/intent/medo/timeline_compact_overview.md` は「固定高さ compact overview」から「二段階 density」への判断変更として更新する。
