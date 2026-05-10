---
title: Timeline Text Share
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - README.md
  - _docs/archives/plan/Core/timeline-text-share.md
  - _docs/reference/medo/text_export_reference.md
  - _docs/reference/medo/timeline_domain_reference.md
related_issues: []
related_prs: []
---

## Context

現在の逆算 timeline を、相手が Medo を使っていなくても読める形で共有する必要がありました。
画像共有より先に、情報設計の基準になる plain text 表現を確定させる必要があります。

## Decision

- `TimelineTextExportRequest` と `generateTimelineText` に text export の純粋ロジックを集約する
- 日付なし / 日付ありの 2 mode を持つ
- 日付ありでは `baseDate` と `targetTime - totalDuration` から日跨ぎを判定する
- `action`、`actionPoint`、target anchor は異なる記号で表現する
- 共有 sheet と clipboard fallback を UI から提供する
- buffer がある action は実作業時間と余裕時間を分けて表示する

## Alternatives

- 現在画面の文字列をそのままコピーする案は、編集 UI の状態に引きずられるため不採用
- 機械可読な import/export と兼ねる案は、人間が読む共有文として冗長になるため不採用

## Rationale

text export は共有の最小単位です。
純粋関数で生成すると、日跨ぎ、0 分 event、buffer 表示を test で固定でき、画像共有とも情報設計を揃えられます。

## Consequences / Impact

- title の改行は共有文内で半角スペースへ正規化される
- `actionPoint` と anchor は 0 分のまま扱い、1 分には丸めない
- buffer は total duration と action time range に含まれる

## Rollback / Follow-ups

- 共有 sheet が使えない platform では clipboard を fallback とする
- Markdown 形式や machine-readable export は別機能として扱う
