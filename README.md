# Medo

## このアプリは現在アプリストアで公開されています。このリポジトリには(おそらく)無料版の範囲までが存在します。ぜひストアリリースをご覧ください

`Medo` は、目標時刻から逆算して行動の流れを組み立てる Flutter アプリです。
「何時までに着きたいか / 終えたいか」を先に置き、そこから必要な行動を過去方向へ積み上げていくタイムラインエディタとして実装されています。

現状の実装は、単一画面で完結するプロトタイプ兼基礎実装です。Riverpod で保持している状態を編集しながら、目標時刻・各行動の所要時間・行動ポイントを即時に反映できます。編集中のタイムラインは自動保存され、起動時には最後に開いたタイムラインを復元します。

## 現在の機能

- 目標時刻と目標名の編集
- `action` ブロックの追加、名称変更、所要時間変更、並び替え
- `actionPoint` ブロックの追加、名称変更、並び替え
- 逆算結果に基づく各ブロック開始時刻と総所要時間の表示
- timeline list island modal からのタイムライン作成と切り替え
- Android / iOS でのカレンダー登録
- 記号レイアウト形式のテキスト共有とクリップボードコピー
- タイムラインの画像カードとしての PNG 共有

## 画面の考え方

- タイムライン下端に「目標時刻」アンカーを置きます
- その上側へ向かって、より過去の行動を積み上げます
- `action` は時間を消費する行動です
- `actionPoint` は経由点やチェックポイントで、所要時間は 0 分です
- すべての開始時刻は `targetTime` と後続ブロックの `duration` から再計算されます

## カラーパレット

- Base / Canvas: `#F6F5F2`
- Soft Gray: `#DDD9D0`
- Ink: `#26241F`
- Muted Ink: `#6F6A61`
- Accent / Olive: `#8A9864`
- Dark Surface: `#1F211C`

## セットアップ

Flutter SDK を PATH に通していない前提では、以下の絶対パスを使って実行できます。

```bash
/home/penne/sdk/flutter/flutter/bin/flutter pub get
/home/penne/sdk/flutter/flutter/bin/flutter analyze
/home/penne/sdk/flutter/flutter/bin/flutter test
/home/penne/sdk/flutter/flutter/bin/flutter run -d linux
```

環境セットアップの補足は [`_docs/guide/flutter/environment_setup.md`](_docs/guide/flutter/environment_setup.md) を参照してください。

## 開発メモ

- エントリポイントは `lib/main.dart` です
- 状態管理は `lib/state.dart` の `TimelineNotifier` と `timelineProvider` に集約しています
- 時刻計算の純粋関数は `lib/models.dart` にあります
- カレンダー書き出しの純粋関数は `lib/calendar_export.dart` にあります
- カレンダー登録の request 組み立てとプレビューは `lib/calendar_export_request_builder.dart` にあります
- カレンダー登録の native delivery は `lib/calendar_export_delivery.dart` にあります
- テキスト共有の純粋関数は `lib/timeline_text_export.dart` にあります
- 画像共有の純粋関数と Widget、delivery は `lib/timeline_image_export.dart`、`lib/timeline_image_share_card.dart`、`lib/image_export_delivery.dart` にあります
- ローカル通知リマインダーのサービス層は `lib/notifications/` にあります
- 永続化 Repository は `lib/persistence/` にあります
- Pro 判定の現在状態は `lib/billing/pro_entitlement_repository.dart` と `lib/billing/pro_entitlement_providers.dart` で Supabase の `user_pro_entitlements` から read-only 取得します
- 主要 UI は `lib/timeline_screen.dart`、`lib/block_item.dart`、`lib/edit_sheet.dart` に分かれています
- テストは `test/widget_test.dart` と `test/persistence/` にあり、計算ロジック、スモークテスト、Repository の保存・履歴操作を含みます

### Supabase / RevenueCat 課金状態同期

Flutter アプリは `anon` / publishable key のみを使い、`user_pro_entitlements` を select します。`pro_entitlement_events` は RevenueCat webhook 由来の service-only log で、Flutter code からは参照しません。

Paywall は RevenueCat の `current` offering から Pro package を取得し、価格・期間を表示して `Purchases.purchasePackage(...)` で Google Play / App Store の購入フローを開始します。購入成功後は RevenueCat `CustomerInfo` と Supabase の `currentProEntitlementProvider` を再読込します。RevenueCat webhook から Supabase へ反映されるまで短い遅延があり得るため、購入直後は「確認中」として扱い、最終的な Pro 判定は引き続き Supabase の `user_pro_entitlements` を source of truth にします。

Web / Linux / Windows など RevenueCat SDK を使わない実行環境では、アプリ起動時に `Purchases.configure(...)`、`logIn`、`logOut`、offering 取得、restore を呼ばず、billing state は Free 相当に倒します。Paywall は Pro package なしとして表示され、ストア購入フローは Android / iOS / macOS の対応環境だけで有効になります。

closed testing で課金導線を確認する場合は、Play Store の opt-in 経由でインストールし、Supabase login 後に Paywall から sandbox purchase を開始します。その後、RevenueCat dashboard の customer / entitlement、Supabase `user_pro_entitlements.is_pro`、アプリ内の Pro gate 解放を順に確認します。購入済み状態の再同期には Paywall または設定画面の「購入を復元」を使用します。

Supabase 側のローカル成果物は以下です。

- SQL migration: `supabase/migrations/20260509081731_revenuecat_supabase_entitlement_sync.sql`
- RevenueCat webhook: `supabase/functions/revenuecat-webhook/index.ts`
- account deletion function: `supabase/functions/delete-account/index.ts`

Edge Function secrets は、Supabase hosted defaults の `SUPABASE_URL`、`SUPABASE_PUBLISHABLE_KEYS`、`SUPABASE_SECRET_KEYS` を優先します。互換用に `SUPABASE_ANON_KEY` と `SUPABASE_SERVICE_ROLE_KEY` も読みます。追加で以下が必要です。

- `REVENUECAT_WEBHOOK_AUTHORIZATION`: RevenueCat dashboard 側にも設定する webhook 認証ヘッダー値
- `REVENUECAT_SECRET_API_KEY`: RevenueCat subscriber API 用の secret API key
- `REVENUECAT_PRO_ENTITLEMENT_ID`: Pro entitlement identifier

Supabase CLI が PATH にない環境では `npx supabase ...` で実行できます。

```bash
npx supabase db push
npx supabase functions deploy revenuecat-webhook
npx supabase functions deploy delete-account
```

## ドキュメント

- 利用ガイド: [`_docs/guide/medo/timeline_editor.md`](_docs/guide/medo/timeline_editor.md)
- リファレンス: [`_docs/reference/medo/timeline_domain_reference.md`](_docs/reference/medo/timeline_domain_reference.md)
- カレンダー書き出しリファレンス: [`_docs/reference/medo/calendar_export_reference.md`](_docs/reference/medo/calendar_export_reference.md)
- テキスト共有リファレンス: [`_docs/reference/medo/text_export_reference.md`](_docs/reference/medo/text_export_reference.md)
- 画像共有リファレンス: [`_docs/reference/medo/image_export_reference.md`](_docs/reference/medo/image_export_reference.md)
- ローカル通知リファレンス: [`_docs/reference/medo/reminder_notification_reference.md`](_docs/reference/medo/reminder_notification_reference.md)
- 永続化リファレンス: [`_docs/reference/medo/persistence_repository_reference.md`](_docs/reference/medo/persistence_repository_reference.md)
- プライバシーポリシー運用ガイド: [`_docs/guide/medo/privacy_policy_operations.md`](_docs/guide/medo/privacy_policy_operations.md)
- 設計意図: [`_docs/intent/medo/reverse_timeline_interaction_model.md`](_docs/intent/medo/reverse_timeline_interaction_model.md)
- カレンダー書き出し設計意図: [`_docs/intent/medo/calendar_export_ics.md`](_docs/intent/medo/calendar_export_ics.md)
- ローカル通知設計意図: [`_docs/intent/medo/local_reminder_notifications.md`](_docs/intent/medo/local_reminder_notifications.md)
- 永続化設計意図: [`_docs/intent/medo/drift_persistence_repository.md`](_docs/intent/medo/drift_persistence_repository.md)
- ドキュメント運用ガイド: [`_docs/documentation_guide.md`](_docs/documentation_guide.md)

## 現状の制約

- Drift / SQLite の永続化 Repository はアプリ画面へ接続済みです。現在のタイムラインは自動保存され、再起動後は最後に開いていたタイムラインが復元されます
- カレンダー書き出しは `.ics` 文字列生成に加えて、Android / iOS ではネイティブ API でカレンダーへ直接登録します。登録前に開始日時、アンカー日時、件数、日跨ぎ状態をプレビューで確認できます
- Android / iOS のカレンダー登録では、権限拒否・書き込み可能カレンダーなし・ペイロード不正・保存失敗を domain error として区別します。iOS 17+ では write-only access を優先し、それ以前の OS では full access にフォールバックします
- カレンダー登録時の書き込み先カレンダー選択 UI は未実装です。現状は未指定時に OS の既定カレンダーへ自動的に書き込みます
- ローカル通知は予約サービスのみ実装済みで、権限要求や予約操作を行う UI は未実装です
- Supabase には Auth、Pro 現在状態、service-only の RevenueCat event log だけを保持します。タイムライン、テンプレート、履歴、ローカル通知、カレンダー登録データは Supabase に同期しません
- アカウント削除は `delete-account` Edge Function 経由で Supabase Auth user を削除し、`user_pro_entitlements` と `pro_entitlement_events` は外部キーの cascade delete で削除される設計です。ストア購読のキャンセルは Google Play / App Store 側で別途行う必要があります
- Undo / Redo は未実装です
- `applyStartTimeEdit` は状態層に実装済みですが、現状の UI では直接使用していません
- Web / Linux / Windows では RevenueCat billing を Free fallback として扱います。macOS / iOS 用のランナー雛形は存在しますが、運用・検証状況は別途確認が必要です

## 検証済みコマンド

2026-04-20 時点で、少なくとも以下は通過済みです。

```bash
/home/penne/sdk/flutter/flutter/bin/flutter analyze
/home/penne/sdk/flutter/flutter/bin/flutter test
```
