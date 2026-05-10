---
title: Action Buffer Time
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - README.md
  - _docs/archives/plan/Core/action-buffer-time.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
  - _docs/reference/medo/persistence_repository_reference.md
  - _docs/reference/medo/calendar_export_reference.md
  - _docs/reference/medo/text_export_reference.md
  - _docs/reference/medo/image_export_reference.md
related_issues: []
related_prs: []
---

## Context

`action` block には、実作業時間とは別に「遅れを吸収する余裕」を持たせる必要がありました。
通常 block として buffer を追加すると、並び替え対象や共有表現で実作業と余裕の境界が曖昧になります。

## Decision

- `Block.bufferMinutes` を `action` 専用の属性として持たせる
- 逆算、総所要時間、保存、テンプレート、共有、カレンダー登録では `duration + bufferMinutes` を有効所要時間として扱う
- `actionPoint` の buffer は常に 0 に正規化する
- Pro ユーザーだけが buffer を追加・編集できる
- Free ユーザーでも既存 buffer は保持し、計算と表示には反映する

## Alternatives

- buffer を独立 block として扱う案は、並び替え時に実作業から切り離されるため不採用
- Free で buffer を削除または無視する案は、ユーザーデータを壊し、Pro 解約時の縮退として強すぎるため不採用

## Rationale

buffer は行動の性質を補強する属性であり、独立した予定ではありません。
そのため block 内部に保持すると、編集 UI、逆算、テンプレート、export のすべてで同じ意味を保てます。

## Consequences / Impact

- Drift schema と snapshot codec は buffer を含む形式へ更新された
- 共有出力とカレンダー登録は実作業時間ではなく有効所要時間を使う
- Pro gate は UI 表示だけでなく、編集 action の境界でも確認する必要がある

## Rollback / Follow-ups

- buffer 編集を一時停止する場合は、編集入口だけを Pro gate または feature flag 相当で閉じる
- 既存データの `bufferMinutes` は削除せず、読み込み時に正規化して保持する
