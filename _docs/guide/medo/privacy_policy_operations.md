---
title: Medo Privacy Policy Operations Guide
status: active
draft_status: n/a
created_at: "2026-05-09"
updated_at: "2026-05-09"
references:
  - README.md
  - _docs/standards/privacy-policy.md
  - _docs/plan/Core/revenuecat-supabase-entitlement-sync.md
related_issues: []
related_prs: []
---

# Medo Privacy Policy Operations Guide

## Overview

Medo のユーザーデータ、課金状態、アカウント削除、外部サービス連携の扱いを変更する場合は、実装だけで完了扱いにしない。

公開中のプライバシーポリシー、Google Play Data Safety、アプリ内の削除説明、README / guide / reference の記述が同じ事実を説明していることを確認する。

## Source Files

- 原稿: `_docs/standards/privacy-policy.md`
- 公開用 HTML: `public/medo/privacy/index.html`
- 公開予定 URL: `https://otibo.dev/medo/privacy/`

Cloudflare Pages へアップロードする場合は、`public` ディレクトリを deploy 対象にする。

```bash
npx wrangler pages deploy /home/penne/dev/active/backcast/public --project-name medo-privacy-policy
```

## Update Triggers

以下に該当する変更では、プライバシーポリシーの更新要否を必ず確認する。

- 取得するユーザーデータの種類を増やす、減らす、または名称を変える
- タイムライン、テンプレート、履歴、通知、カレンダー登録データの保存先を端末内からクラウドへ変更する
- Supabase に保存する情報、保存期間、削除条件、RLS / service role 境界を変更する
- RevenueCat、Google OAuth、Google Play など、第三者サービスの利用目的や連携範囲を変更する
- アカウント削除時に削除される情報、残る情報、復元可否を変更する
- サブスクリプション、購入検証、Pro 判定、返金・解約案内の説明が変わる
- iOS / Web など、Android 以外の配布プラットフォームを公開対象に加える
- 問い合わせ先、事業者情報、管轄裁判所、公開 URL を変更する

判断に迷う場合は、ユーザーに見える説明が変わるか、外部サービスへ渡る情報が変わるかを基準にする。どちらかが変わるなら更新対象として扱う。

## Update Checklist

1. 実装差分から、取得情報、保存先、利用目的、第三者サービス、削除動作の変更点を洗い出す。
2. `_docs/standards/privacy-policy.md` の本文を先に更新する。
3. 同じ内容を `public/medo/privacy/index.html` に反映する。
4. Google Play Data Safety、account deletion URL、アプリ内説明、README / guide / reference の記述と矛盾しないか確認する。
5. `rg` で古いサービス名、古い保存先、古い削除説明、platform 固有の不要記述が残っていないか確認する。
6. HTML の構文を最低限パースし、公開用ファイルのパスが `public/medo/privacy/index.html` のままか確認する。
7. Cloudflare Pages へ再アップロードし、`https://otibo.dev/medo/privacy/` の表示を確認する。

## Verification Commands

```bash
rg -n "privacy|プライバシー|個人情報|アカウント削除|Data Safety|RevenueCat|Supabase|Google Play|App Store" README.md _docs lib supabase public
python3 - <<'PY'
from html.parser import HTMLParser
from pathlib import Path

path = Path("public/medo/privacy/index.html")
parser = HTMLParser()
parser.feed(path.read_text(encoding="utf-8"))
print("html_parse_ok")
print(path)
PY
```

## Notes

初期 Android 公開では、タイムライン、テンプレート、履歴、ローカル通知、カレンダー登録データは端末内保存として説明している。これらを Supabase や他のクラウドへ同期する場合は、プライバシーポリシーの中核記述が変わるため、必ず先に見直す。

アカウント削除は、Supabase 上のメールアドレス、課金状態、購入検証ログを削除する説明になっている。削除後に保持する識別子や監査ログを追加する場合は、保持理由、保存期間、開示・削除請求への対応を同時に設計する。
