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

### Implementation pass: UI-Perf-59

2026-05-19 の実装 pass では、reorder の transient interaction state を `TimelineScreen.setState` から分離した。

- `_ReorderInteractionController` を追加し、drag preview と insertion line を `ValueNotifier` で個別更新する。
- session 開始/終了だけ `TimelineScreen` を rebuild し、pointer move は overlay controller の更新に閉じる。
- session 開始後の frame で visible item geometry を snapshot し、pointer move 中は cache と reverse scroll offset delta から insertion candidate を推定する。
- pointer move は `SchedulerBinding.scheduleFrameCallback` で最大 1 frame 1 update に coalesce し、insertion candidate / line が変わらない場合は insertion overlay へ通知しない。
- block 構造、view mode、density、duration / buffer 由来の visual height が変わった場合は reorder session を cancel する。

ローカル検証では `test/widget_test.dart` に、pointer move 後も visible `BlockItem` widget instance が差し替わらないこと、同一 insertion candidate の horizontal move で insertion line が rebuild されないこと、構造変化で preview が残留しないことを追加した。

### After trace: UI-Perf-59

2026-05-19 20:33 JST に Pixel 7a 実機で after trace を取得した。実行は `fvm flutter run --profile -d 38231JEHN03177`、入力は visible reorder handle 上の水平 small move として `/home/penne/Android/Sdk/platform-tools/adb -s 38231JEHN03177 shell input touchscreen swipe 940 1058 960 1058 30000` を使った。

VM Service の ring buffer は高密度 pointer trace では約 3 秒分に切れるため、after trace は Timeline stream を購読して集計した。生 trace では DevTools 表示上の `uiBeginFrame` に相当する UI thread frame boundary を `Animator::BeginFrame` として集計している。widget build profiling は通常 trace では無効にし、構造確認用の別 trace でのみ有効化した。

通常 profile trace では、reorder 中の UI frame と build cost は大きく下がった。

| Metric | count | p50 | p90 | max | over 11ms | over 16ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `Animator::BeginFrame` | 2689 | 1.970ms | 2.863ms | 29.791ms | 3 | 3 |
| `BUILD` | 5399 | 0.145ms | 0.303ms | 15.229ms | 2 | 0 |
| `LAYOUT` | 2689 | 0.267ms | 0.444ms | 5.830ms | 0 | 0 |
| `PAINT` | 2689 | 0.931ms | 1.265ms | 6.097ms | 0 | 0 |
| `GPURasterizer::Draw` | 2689 | 4.079ms | 5.430ms | 8.134ms | 0 | 0 |

before の `uiBeginFrame` p90 10.911ms に対して after の UI frame p90 は 2.863ms で、目標の 8ms 未満を満たした。`BUILD` p90 も 2.853ms から 0.303ms へ下がり、build の 16ms 超えは 2 件から 0 件になった。16ms 超え UI frame は 8 件から 3 件へ減ったが、目標の 1 件以下にはまだ届いていない。

widget build profile では、pointer move の主更新先は drag preview overlay に寄っており、`TimelineScreen` / `SliverList` / visible `BlockItem` の連続 rebuild は残っていない。

| Event / Widget | Count | Total | Max |
| --- | ---: | ---: | ---: |
| `BUILD` | 1771 | 662.733ms | 72.081ms |
| `TimelineScreen` | 2 | 95.314ms | 71.817ms |
| `SliverPadding` | 2 | 74.441ms | 54.845ms |
| `SliverList` | 2 | 74.418ms | 54.828ms |
| `BlockItem` | 14 | 69.912ms | 13.648ms |
| `_ReorderDragPreviewOverlay` | 878 | 54.278ms | 0.504ms |
| `_ReorderInsertionOverlay` | 1 | 0.025ms | 0.025ms |

構造上の主因だった pointer move から main timeline list への rebuild 伝搬は解消している。残った 16ms 超えは通常 trace の top event では `Animator::BeginFrame` / `VsyncProcessCallback` 側の散発 spike で、raster は max 8.134ms、`BUILD` も max 15.229ms に収まっている。推論として、次に扱うなら連続的な list rebuild ではなく、まれな UI thread spike と GC / scheduler 周辺の切り分けが対象になる。

Raw artifacts:

- `/tmp/backcast-perf-20260519/after-reorder-hold-small-move-normal-stream.timeline.json`
- `/tmp/backcast-perf-20260519/after-reorder-hold-small-move-normal-stream.summary.json`
- `/tmp/backcast-perf-20260519/after-reorder-widget-build-stream.timeline.json`
- `/tmp/backcast-perf-20260519/after-reorder-widget-build-stream.summary.json`

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
