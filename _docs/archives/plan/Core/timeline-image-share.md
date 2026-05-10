---
title: Timeline Image Share
status: proposed
draft_status: n/a
created_at: "2026-05-02"
updated_at: "2026-05-02"
references:
  - README.md
  - TODO.md
  - _docs/archives/plan/Core/timeline-text-share.md
  - _docs/reference/medo/timeline_domain_reference.md
  - https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary-class.html
  - https://pub.dev/packages/share_plus
  - https://pub.dev/packages/screenshot
related_issues: []
related_prs: []
---

## Overview

`Medo` の現在の逆算タイムラインを、共有用に整えた画像カードとして生成し、OS の共有シートで外部共有できるようにする。

本機能は現在画面のスクリーンショットではなく、共有のために再構成した `TimelineImageShareCard` を PNG として描き出す。これにより、編集 UI、スクロール位置、端末サイズ、操作中の状態に引っ張られず、相手が開いた瞬間に計画の全体像を見られる出力を作る。

## Product Value

- 共有先アプリでテキストの等幅表示が崩れても、計画の視覚構造を維持できる
- LINE / Discord / Slack / X などで、添付画像としてタイムラインの全体像を即座に見せられる
- Medo の配色、余白、縦タイムライン構造を含めて共有できる
- 「この予定で動く」という宣言や確認依頼に向いている
- Medo を使っていない相手にも、計画カードとして意図を伝えられる

画像共有の対価は、編集可能性ではなく、見せやすさ、伝わりやすさ、崩れにくさにある。

## Approach

### Chosen Approach

共有専用の Widget を作り、それを PNG としてレンダリングして共有する。

- `TimelineImageShareCard` のような表示専用 Widget を定義する
- 既存の編集画面そのものは撮影しない
- `RepaintBoundary` / `RenderRepaintBoundary.toImage()` を主手段として検討する
- 生成した PNG bytes を `share_plus` の file sharing で共有する
- 画像生成と共有 delivery は分離する

### Alternatives

- 現画面のスクリーンショット:
  実装は単純だが、スクロール位置、編集 UI、画面サイズ、ヘッダー、ボタンなどが混ざり、画像共有ならではの価値が薄い。そのため不採用。
- `screenshot` package:
  Widget capture の既存解として有力。特に画面外 Widget や長い Widget を扱う場合は実装コストを下げられる。初回実装では `RenderRepaintBoundary` を第一候補とし、offscreen capture が煩雑になる場合だけ採用を検討する。
- `CustomPainter` / Canvas 直描き:
  もっとも決定的な画像生成ができるが、初回実装としてはコストが高い。将来、画像サイズ、分割、印刷品質、長尺出力を厳密に制御したくなった段階で再検討する。

## Scope

- 現在の `TimelineState` から画像共有用の view model を作る
- 共有専用の `TimelineImageShareCard` を追加する
- Medo の既存パレットを使い、編集 UI とは独立したカードレイアウトにする
- 日付なし、単日、日跨ぎの情報を画像上でも表現する
- `action`, `actionPoint`, target anchor を視覚的に区別する
- PNG bytes を生成する image renderer / capture service を追加する
- `share_plus` で画像を共有する delivery 層を追加する
- 共有前に軽量プレビューを表示する

## Non-Goals

- 現在画面のスクリーンショット共有は行わない
- 画像のピクセル寸法、完全な typography、余白、装飾をこの計画段階で固定しない
- 複数枚分割、PDF、印刷向け高解像度、SNS 個別サイズ最適化は扱わない
- 画像上の情報を再 import する機能は扱わない
- テキスト共有の仕様変更は行わない
- Free / Pro gate との接続は初回スコープに含めない。ただし既存の Pro/Free gate 計画で画像エクスポートが対象になっているため、後続で接続できる境界は残す

## Visual Direction

この段階では厳密な visual spec ではなく、次の方向性だけを固定する。

- 出力は「小さな計画カード」として見えること
- 上部に `Medo // <target title>` 相当の見出しを置く
- 日付または date range と total duration を見える位置に置く
- 中央に縦方向の timeline を置く
- `action` は時間幅を持つ行動として、`actionPoint` は一点の節目として、target anchor は終点として区別する
- 操作用 UI、保存/ロード/エクスポートボタン、スクロールバー、編集中のカーソルは画像に含めない
- 背景、文字色、ブロック色は既存の Medo palette と大きく乖離させない

## Requirements

- **Functional**: 現在のタイムラインを共有専用画像カードへ変換できる
- **Functional**: 生成画像を native share sheet で共有できる
- **Functional**: 共有前に画像プレビューを表示できる
- **Functional**: 日付なし、単日、日跨ぎの各状態を画像内で判別できる
- **Functional**: `action`, `actionPoint`, target anchor が視覚的に区別される
- **Functional**: 0 分要素は 0 分の節目として扱い、所要時間を持つ行動に見せない
- **Non-Functional**: 画像生成は現在画面の表示状態に依存しない
- **Non-Functional**: renderer / capture service は共有 delivery から分離する
- **Non-Functional**: 出力 PNG は端末 pixel ratio を考慮し、低解像度でぼやけないようにする
- **Non-Functional**: 長いタイムラインでメモリや画像サイズが破綻しないよう、初回実装時に上限または警告方針を決める
- **Non-Functional**: テキスト共有の view model / date handling と可能な範囲で情報設計を共有する

## Tasks

1. `timeline-text-share` の実装または plan を参照し、画像共有で使う共通の timeline export view model を定義する
2. `TimelineImageShareCard` を追加し、編集画面とは別の共有専用 UI として構成する
3. `RepaintBoundary` / `RenderRepaintBoundary.toImage()` を使った PNG capture service を実装する
4. offscreen capture が複雑化する場合のみ、`screenshot` package の採用を検討し、採用理由を reference または intent に残す
5. `share_plus` を使った image share delivery を追加する。テキスト共有で導入済みなら同じ delivery 境界を拡張する
6. 共有前プレビュー UI を追加し、生成中、成功、失敗、共有キャンセルを扱う
7. 長いタイムラインの扱いを初回実装で決める。候補は、単一長尺 PNG、上限超過時の警告、後続分割対応のいずれかとする
8. 実装後、画像共有 reference と README の export 説明を更新する

## Test Plan

- view model の unit test で、日付なし、単日、日跨ぎ、0 分要素、空 blocks を検証する
- widget test で `TimelineImageShareCard` が target title、total duration、block titles、anchor を描画することを確認する
- PNG capture smoke test で、生成 bytes が空ではなく PNG として扱えることを確認する
- 可能なら固定 seed / 固定 input で画像寸法または主要構成の snapshot 的検証を行う
- Android / iOS で share sheet に PNG が渡ることを手動確認する
- 高 DPI 端末で画像が極端にぼやけないことを確認する
- 長いタイムラインで上限や警告が意図どおり動作することを確認する

## Deployment / Rollout

- 初回は単一 PNG 共有として出す
- SNS 個別比率、複数枚分割、保存先選択は後続機能に回す
- 画像共有が不安定な場合は、共有導線だけ無効化し、画像カード Widget と renderer は残して検証を続ける
- Pro / Free gate を後から接続する場合、生成ロジックではなく UI entrypoint 側で gate する

## Review Checklist

- 現画面スクショになっていない
- 共有画像に操作 UI が混ざっていない
- Medo palette と timeline 構造を保っている
- `actionPoint` と target anchor が 0 分の節目として表現されている
- 画像生成、共有 delivery、UI entrypoint が分離されている
- 長いタイムラインの扱いが未定義のまま実装されていない
- `share_plus` で画像共有する場合、file name / MIME type / iPad share origin の扱いが確認されている
- 後続の Pro / Free gate 接続を妨げない
