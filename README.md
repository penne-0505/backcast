# Backcast

Flutter と `flutter_riverpod` を使う前提で初期化したアプリです。

## Environment

- Flutter SDK: `/home/penne/sdk/flutter/flutter/bin/flutter`
- Riverpod package: `flutter_riverpod`
- 確認済みターゲット: Android / Linux desktop

## Setup

PATH を通していない場合は、以下のように絶対パスで実行できます。

```bash
/home/penne/sdk/flutter/flutter/bin/flutter pub get
/home/penne/sdk/flutter/flutter/bin/flutter analyze
/home/penne/sdk/flutter/flutter/bin/flutter test
/home/penne/sdk/flutter/flutter/bin/flutter run -d linux
```

Fish を使う場合は `~/.config/fish/config.fish` に Flutter SDK の `bin` を追加済みです。

## Project Notes

- `lib/main.dart` で `ProviderScope` を起点に Riverpod を有効化しています。
- 初期画面は「Flutter + Riverpod environment is ready.」を表示します。
- Web は Chrome 未導入のため、このマシンでは追加設定なしでは `flutter run -d chrome` を使えません。
