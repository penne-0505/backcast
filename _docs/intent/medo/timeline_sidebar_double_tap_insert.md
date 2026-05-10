---
title: Timeline Sidebar Double Tap Insert
status: active
draft_status: n/a
created_at: "2026-05-11"
updated_at: "2026-05-11"
references:
  - README.md
  - _docs/archives/plan/UI/timeline-sidebar-double-tap-insert.md
  - _docs/guide/medo/timeline_editor.md
  - _docs/reference/medo/timeline_domain_reference.md
related_issues: []
related_prs: []
---

## Context

逆算タイムラインでは、既存 block の境界へ素早く action を差し込む操作が必要です。
画面左の rail は時刻と流れの基準として認識されるため、境界挿入の入力面として自然です。

## Decision

- block の sidebar / target anchor sidebar の double tap で `action` を挿入する
- block sidebar では tap 位置の上下から挿入 index を決める
- inline editor が active の場合は、挿入より先に focus 解除を優先する
- 挿入後は `computeBlocks()` により target anchor 固定のまま開始/終了時刻を再計算する

## Alternatives

- 画面下部の追加ボタンだけにする案は、境界への差し込みが遠回りになるため不採用
- 任意時刻指定で新規作成する案は、逆算モデルの block 順序編集から外れるため不採用

## Rationale

rail は timeline の構造を示す領域であり、境界への挿入意図と一致します。
時刻を直接指定するより、block の順序を変え、その結果として時刻を再計算する方が現行モデルに合います。

## Consequences / Impact

- sidebar は見た目だけでなく hit target としても扱う
- reorder、duration drag、inline edit との gesture 競合に注意する必要がある

## Rollback / Follow-ups

- 誤操作が多い場合は hit area や gesture 条件を調整する
- キーボードや accessibility 用の挿入導線は別途補強する
