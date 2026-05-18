---
title: Timeline Interaction Performance Profile
status: active
draft_status: n/a
created_at: "2026-05-19"
updated_at: "2026-05-19"
references:
  - _docs/plan/UI/reorder-overview-scaling.md
  - _docs/intent/medo/reorder_placement_preview.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
  - https://docs.flutter.dev/perf/ui-performance
  - https://docs.flutter.dev/tools/devtools/performance
  - https://docs.flutter.dev/perf/best-practices
related_issues: []
related_prs: []
---

## Background

Pixel 7a 実機で、timeline editor のユーザー視点の操作遅延とカクつきが UX 上許容しづらい水準として観測された。Pixel 7a は検証端末として過度に低スペックではないため、端末性能不足を主因とする前提は置かない。

既存の reorder 改善では、timeline 全体の縮小方式を撤回し、`TimelineScreen` の local overlay として dragged block preview / insertion line を出す方式へ移行した。この変更により見た目と挿入判定の責務は分離できたが、計測上は高頻度 pointer move が `TimelineScreen` 本体を再 build する構造が残っている。

## Objective

- Pixel 7a 実機の profile mode で、どの操作が frame budget を超えているかを切り分ける。
- UI thread / raster thread のどちらが主因かを判定する。
- 長期安定性を優先した改善対象を、根拠付きで plan へ接続する。

## Method

- 実行環境:
  - 端末: Pixel 7a, Android 16 API 36
  - Flutter: `fvm flutter --version` で Flutter 3.41.6 / Dart 3.11.4
  - 実行: `fvm flutter run --profile -d 38231JEHN03177`
  - Rendering backend: Flutter log 上は Impeller / Vulkan
- 計測:
  - VM Service timeline を取得し、UI frame / build / layout / paint / raster draw を集計した。
  - reorder では `ext.flutter.profileWidgetBuilds`, `ext.flutter.profileUserWidgetBuilds`, `ext.flutter.profileRenderObjectLayouts`, `ext.flutter.profileRenderObjectPaints` を有効化した widget build profile も取得した。
  - `dumpsys gfxinfo` は Flutter SurfaceView の frame を十分に拾えなかったため、今回の根拠には使わない。
- 集計しきい値:
  - 90Hz 相当の端末では 1 frame 約 11.1ms、60Hz では約 16.7ms を目安にする。
  - Flutter 公式の推奨に合わせ、debug mode ではなく profile mode の trace を判断材料にする。

## Results

### Reorder hold and small move

`vm-reorder-hold-small-move` では UI thread 側に遅延が集中した。

| Metric | p50 | p90 | max | over 11ms | over 16ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| `uiBeginFrame` | 6.090ms | 10.911ms | 42.937ms | 16 | 8 |
| `BUILD` | 0.032ms | 2.853ms | 26.163ms | 3 | 2 |
| `LAYOUT` | 0.807ms | 1.309ms | 6.729ms | 0 | 0 |
| `PAINT` | 1.555ms | 2.871ms | 9.769ms | 0 | 0 |
| `rasterDraw` | 4.000ms | 6.035ms | 11.177ms | 1 | 0 |

この結果から、reorder 中の主因は raster ではなく UI thread / build 側だと判断する。

### Reorder widget build profile

widget build profile では、reorder 操作中に `TimelineScreen` から `SliverList` と visible `BlockItem` までが巻き込まれていた。

| Event / Widget | Count | Total | Max |
| --- | ---: | ---: | ---: |
| `BUILD` | 39 | 113.451ms | 62.743ms |
| `TimelineScreen` | 5 | 103.465ms | 62.418ms |
| `SliverPadding` | 5 | 80.255ms | 47.393ms |
| `SliverList` | 5 | 80.207ms | 47.366ms |
| `BlockItem` | 37 | 75.766ms | 7.102ms |

現状実装では `_updateReorderPreview` が pointer move ごとに `setState` し、`TimelineScreen.build` が `computedBlocksProvider` を watch しながら `CustomScrollView` / `SliverList` / `BlockItem` を組み立てる。この構造が、reorder preview の高頻度更新を timeline 本体 rebuild へ伝搬させている。

### Scroll one-pass

`vm-scroll-onepass` では reorder より優先度は低いが、scroll 中にも raster / build の外れ値がある。

| Metric | p50 | p90 | max | over 11ms | over 16ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| `uiBeginFrame` | 1.135ms | 7.764ms | 81.024ms | 18 | 6 |
| `BUILD` | 0.076ms | 2.424ms | 55.935ms | 2 | 1 |
| `PAINT` | 0.014ms | 2.344ms | 13.485ms | 2 | 0 |
| `rasterDraw` | 4.815ms | 7.243ms | 18.356ms | 12 | 2 |

scroll は reorder ほど恒常的ではないが、`BlockItem` の visual complexity、`ShaderMask`、shadow、`IntrinsicHeight`、常時生きている編集系 widget の影響を追加調査する価値がある。

### Duration drag

`vm-duration-drag` は今回の座標・手順では重い path を再現しなかった。

| Metric | p50 | p90 | max | over 11ms | over 16ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| `uiBeginFrame` | 0.817ms | 1.559ms | 4.657ms | 0 | 0 |
| `BUILD` | 0.171ms | 0.305ms | 0.753ms | 0 | 0 |
| `rasterDraw` | 4.197ms | 6.669ms | 7.429ms | 0 | 0 |

ただし `TimelineNotifier.applyDurationDrag` は move ごとに `TimelineState` を更新するため、block 数増加やより正確な drag 再現では再評価が必要である。

## Discussion

第一優先の原因推定は、reorder preview の transient state が `TimelineScreen` 本体の `setState` に置かれていること。操作 feedback と timeline renderer が同じ rebuild 境界を共有しているため、pointer move の頻度がそのまま `SliverList` / `BlockItem` build の頻度になる。

第二の原因推定は、挿入候補の geometry 計算が pointer move ごとに visible block の `RenderBox.localToGlobal` と sort を実行していること。現時点では visible item 数が小さいため主因とは断定しないが、block 数増加、比較表示、遠距離 reorder 補助、自動 scroll が追加されるほど効いてくる。

第三の候補は scroll / raster 側の visual cost である。これは UX 全体には効くが、今回の reorder widget profile が示す主因より優先度は下げる。先に rebuild 境界を切り、その後に scroll trace を再取得してから visual cost を削る。

## Recommended Actions

1. reorder preview を `TimelineScreen.setState` から分離し、overlay 専用の controller / listenable で更新する。
2. reorder session 開始時に visible geometry を snapshot し、pointer move では cache と scroll delta から候補を計算する。
3. pointer move は最新位置を保存するだけにし、preview / candidate 更新は最大 1 frame 1 回へ絞る。
4. drop 時だけ `TimelineNotifier.moveBlockByIndex` を呼び、gesture 中に domain state / autosave / analytics を動かさない境界を維持する。
5. reorder 改善後に同じ profile 手順を再実行し、残る scroll / raster spike を別フェーズで扱う。
