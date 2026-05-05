---
title: Flutter Environment Setup
status: active
draft_status: n/a
created_at: "2026-04-16"
updated_at: "2026-04-22"
references:
  - README.md
  - _docs/guide/backcast/timeline_editor.md
  - _docs/reference/backcast/timeline_domain_reference.md
related_issues: []
related_prs: []
---

## Overview

`Medo` の Flutter 開発環境を、`flutter_riverpod` を前提に使い始められる状態へ整えたときのセットアップ内容をまとめる。

## Prerequisites

- Flutter SDK が `/home/penne/sdk/flutter/flutter` に存在すること
- 実行バイナリは `/home/penne/sdk/flutter/flutter/bin/flutter`
- Android もしくは Linux desktop の実行環境が利用できること

## Setup / Usage

まず依存関係を取得する。

```bash
/home/penne/sdk/flutter/flutter/bin/flutter pub get
```

静的解析とテストで初期状態を確認する。

```bash
/home/penne/sdk/flutter/flutter/bin/flutter analyze
/home/penne/sdk/flutter/flutter/bin/flutter test
```

Linux desktop で起動する場合:

```bash
/home/penne/sdk/flutter/flutter/bin/flutter run -d linux
```

Fish シェルでは `~/.config/fish/config.fish` に以下と同等の設定を入れておく。

```fish
if test -d /home/penne/sdk/flutter/flutter/bin
    fish_add_path /home/penne/sdk/flutter/flutter/bin
end
```

## Best Practices

- SDK 呼び出しは、PATH が安定するまでは絶対パスを優先する
- Riverpod のエントリポイントは `lib/main.dart` の `ProviderScope` を起点に保つ
- 初期セットアップ確認では `flutter analyze` と `flutter test` をセットで実行する

## Troubleshooting

- `flutter doctor -v` で PATH 警告が出る場合:
  Fish の設定を再読込するか、新しいシェルを開く
- `flutter run -d chrome` が失敗する場合:
  この環境では Chrome executable が未設定。Web 実行には Chrome の導入または `CHROME_EXECUTABLE` の設定が必要

## References

- `README.md`
- `_docs/guide/backcast/timeline_editor.md`
- `_docs/reference/backcast/timeline_domain_reference.md`
- `lib/main.dart`
