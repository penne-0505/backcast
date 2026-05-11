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

- `Block.bufferMinutes` を `action` 専用の desired buffer 属性として持たせる
- 逆算、総所要時間、テンプレート、共有、カレンダー登録では `duration + normalizedBufferMinutes` を有効所要時間として扱う
- `normalizedBufferMinutes` は表示・計算に使う effective buffer とし、5 分刻み、60 分以下、かつ `duration - 5` 分以下に正規化する
- duration を短くして desired buffer が effective 上限を超えても desired 値は保持し、duration を伸ばしたときに再び反映する
- 編集シートの stepper、直接入力、ブロック本体のダブルタップで buffer を手動編集した場合は、その時点の effective 値を新しい desired 値として保存し、復元予約を破棄する
- `actionPoint` の buffer は常に 0 に正規化する
- Pro ユーザーだけが buffer を追加・編集できる
- Free ユーザーでも既存 buffer は保持し、計算と表示には反映する

## Alternatives

- buffer を独立 block として扱う案は、並び替え時に実作業から切り離されるため不採用
- Free で buffer を削除または無視する案は、ユーザーデータを壊し、Pro 解約時の縮退として強すぎるため不採用

## Rationale

buffer は行動の性質を補強する属性であり、独立した予定ではありません。
そのため block 内部に保持すると、編集 UI、逆算、テンプレート、export のすべてで同じ意味を保てます。
ただし、ユーザーが設定した「余裕を置きたい」という意図と、現在の行動時間で表示・計算に使える余裕時間は分けて扱います。
これにより、行動時間を一時的に短くしただけで余裕時間の意図が失われることを避けつつ、表示上は行動本体より大きいバッファセグメントを作らない制約を保てます。

## Consequences / Impact

- Drift schema と snapshot codec は desired buffer を含む形式へ更新された
- 共有出力とカレンダー登録は実作業時間ではなく effective buffer を含む有効所要時間を使う
- Pro gate は UI 表示だけでなく、編集 action の境界でも確認する必要がある

## Rollback / Follow-ups

- buffer 編集を一時停止する場合は、編集入口だけを Pro gate または feature flag 相当で閉じる
- 既存データの `bufferMinutes` は削除せず、読み込み時に desired 値として保持し、表示・計算時に effective 値へ正規化する
