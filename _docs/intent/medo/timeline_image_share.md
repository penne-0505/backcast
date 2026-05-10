---
title: Timeline Image Share
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - README.md
  - _docs/archives/plan/Core/timeline-image-share.md
  - _docs/reference/medo/image_export_reference.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/intent/medo/timeline_text_share.md
related_issues: []
related_prs: []
---

## Context

テキスト共有では等幅表示や改行が共有先アプリに依存します。
計画の視覚構造を保って共有するため、現在画面のスクリーンショットではなく、共有用に再構成した画像カードが必要でした。

## Decision

- `buildTimelineImageExportViewModel` で画像共有用 view model を作る
- `TimelineImageShareCard` を PNG 描画対象の専用 widget とする
- 編集 UI、スクロール位置、端末サイズ、選択状態には依存しない
- 日付なし / 日付あり mode を text export と揃える
- 画像共有は Pro 機能として gate する
- buffer は action 内の別セグメントとして表示し、有効所要時間に含める

## Alternatives

- 画面スクリーンショットを共有する案は、編集 UI や端末サイズに引きずられるため不採用
- text export だけで済ませる案は、共有先で視覚構造が崩れる問題を解決しないため不採用

## Rationale

画像共有の価値は、編集可能性ではなく、見せやすさと崩れにくさです。
専用 view model と card widget に分けることで、共有物の品質を UI の現在状態から切り離せます。

## Consequences / Impact

- PNG 生成と delivery は platform / rendering 条件に依存する
- 画像共有は Pro gate の対象になる
- text export と同じ time / buffer semantics を維持する必要がある

## Rollback / Follow-ups

- 画像生成が失敗した場合はエラー表示し、text export へ暗黙 fallback しない
- 将来のテーマ切替やブランド調整は share card 側に閉じて行う
