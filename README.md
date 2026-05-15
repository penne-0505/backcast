# Medo

## このアプリは現在アプリストアで公開されています。このリポジトリには(おそらく)無料版の範囲までが存在します。ぜひストアリリースをご覧ください

`Medo` は、目標時刻から逆算して行動の流れを組み立てる Flutter アプリです。
「何時までに着きたいか / 終えたいか」を先に置き、そこから必要な行動を過去方向へ積み上げていくタイムラインエディタとして実装されています。

現状の実装は、単一画面で完結するプロトタイプ兼基礎実装です。Riverpod で保持している状態を編集しながら、目標時刻・各行動の所要時間・行動ポイントを即時に反映できます。編集中のタイムラインは自動保存され、起動時には最後に開いたタイムラインを復元します。

## 現在の機能

- 目標時刻と目標名の編集
- `action` ブロックの追加、名称変更、所要時間変更、余裕時間設定、並び替え
- `actionPoint` ブロックの追加、名称変更、並び替え
- 逆算結果に基づく各ブロック開始時刻と、余裕時間を含む総所要時間の表示
- timeline list island modal からのタイムライン作成と切り替え
- Android / iOS でのカレンダー登録
- 記号レイアウト形式のテキスト共有とクリップボードコピー
- タイムラインの画像カードとしての PNG 共有

## 画面の考え方

- タイムライン下端に「目標時刻」アンカーを置きます
- その上側へ向かって、より過去の行動を積み上げます
- `action` は時間を消費する行動で、実作業の所要時間とは別に Pro 向けの余裕時間を持てます
- `actionPoint` は経由点やチェックポイントで、所要時間は 0 分です
- すべての開始時刻は `targetTime` と後続ブロックの有効所要時間（`duration + bufferMinutes`）から再計算されます

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
- 利用改善用 analytics は `lib/analytics/usage_analytics.dart` にあり、明示同意後に allowlist event だけをローカル queue へ保存し、Supabase Edge Function へ background best-effort で送信します
- ローカル通知リマインダーのサービス層は `lib/notifications/` にあります
- 永続化 Repository は `lib/persistence/` にあります
- Pro 判定の現在状態は `lib/billing/pro_entitlement_repository.dart` と `lib/billing/pro_entitlement_providers.dart` で Supabase の `user_pro_entitlements` から read-only 取得します
- 主要 UI は `lib/timeline_screen.dart`、`lib/block_item.dart`、`lib/edit_sheet.dart` に分かれています
- テストは `test/widget_test.dart`、`test/persistence/`、各 export test にあり、計算ロジック、UI 操作、Repository、テンプレート、共有・カレンダー書き出しを含みます

### Supabase / RevenueCat 課金状態同期

Flutter アプリは `anon` / publishable key のみを使い、`user_pro_entitlements` を select します。`pro_entitlement_events` は RevenueCat webhook 由来の service-only log で、Flutter code からは参照しません。

Paywall は RevenueCat の `current` offering から Pro package を取得し、価格・期間を表示します。Paywall 自体は未ログインでも閲覧できますが、`Purchases.purchasePackage(...)` による Google Play / App Store の購入フロー開始と `Purchases.restorePurchases()` による購入復元は、Supabase login 後の user id があり、かつ RevenueCat identity が同じ user id へ同期済みの場合だけ許可します。購入成功後は RevenueCat `CustomerInfo` と Supabase の `currentProEntitlementProvider` を再読込します。RevenueCat webhook から Supabase へ反映されるまで短い遅延があり得るため、購入直後は「確認中」として扱い、最終的な Pro 判定は引き続き Supabase の `user_pro_entitlements` を source of truth にします。Supabase から確認済みの Pro / Free snapshot は Drift の `cached_pro_entitlements` に保存し、次の問い合わせが完了するまではローカル snapshot を暫定判定として採用します。起動直後や再同期中の未判定状態は Free と同一視せず、`effectiveProAccessProvider` で `loading` / `error` / `pro` / `free` を分けて UI と action gate を制御します。

アカウント削除は `delete-account` Edge Function 成功直後に cleanup marker を保存してからローカル cleanup を実行します。端末内では `plans` / `plan_blocks` / `plan_snapshots` / `timeline_templates` / `timeline_template_blocks`、現在タイムライン参照と analytics 同意状態を含む `app_preferences`、`cached_pro_entitlements`、未送信 analytics queue、予約済みローカル通知、削除可能な `medo_share.png` 一時ファイルを削除します。cleanup 失敗時は pending marker を残し、次回起動時に再試行します。

設定画面のサブスクリプションセクションでは、Free ユーザーのプランカードは Paywall へ遷移します。Pro ユーザーの `Proプラン利用中` カードは Paywall には戻さず、RevenueCat `CustomerInfo.managementURL` から Google Play / App Store の購読管理画面を外部アプリで開きます。Pro 判定済みの間は「購入を復元」ボタンを無効化し、UI 状態にかかわらず復元処理自体も開始しません。`managementURL` が取得できない場合は、各ストアのサブスクリプション管理を確認する案内を表示します。

Web / Linux / Windows など RevenueCat SDK を使わない実行環境では、アプリ起動時に `Purchases.configure(...)`、`logIn`、`logOut`、offering 取得、restore を呼ばず、billing state は Free 相当に倒します。Paywall は Pro package なしとして表示され、ストア購入フローは Android / iOS / macOS の対応環境だけで有効になります。

レビュー担当者や検証用アカウントには、Supabase `reviewer_entitlement_allowlist` にメールアドレスと期限を登録できます。Google OAuth 後に `sync-reviewer-entitlement` Edge Function が現在ユーザーのメールアドレスを照合し、期限内で有効な場合だけ `user_pro_entitlements` に `status = temporary` の Pro 状態を作成します。メールは小文字・trim 済みで登録し、審査完了後は `disabled_at` を設定するか期限切れにしてください。

closed testing で課金導線を確認する場合は、Play Store の opt-in 経由でインストールし、Supabase login 後に Paywall から sandbox purchase を開始します。未ログイン状態では Paywall の商品表示までは確認できますが、購入ボタンと復元ボタンはログイン案内に留まり、ストア購入シートは開きません。ログイン直後で RevenueCat identity 同期がまだ完了していない間も購入・復元は開始せず、準備中として扱います。その後、RevenueCat dashboard の customer / entitlement、Supabase `user_pro_entitlements.is_pro`、アプリ内の Pro gate 解放を順に確認します。購入済み状態の再同期には Paywall または設定画面の「購入を復元」を使用し、購読の解約・更新停止は設定画面の Pro プランカードから開くストア側の管理画面で確認します。

Supabase 側のローカル成果物は以下です。

- SQL migration: `supabase/migrations/20260509081731_revenuecat_supabase_entitlement_sync.sql`
- reviewer allowlist migration: `supabase/migrations/20260510113000_reviewer_temporary_entitlement.sql`
- usage analytics migration: `supabase/migrations/20260513090000_usage_analytics.sql`
- RevenueCat webhook: `supabase/functions/revenuecat-webhook/index.ts`
- account deletion function: `supabase/functions/delete-account/index.ts`
- reviewer entitlement sync function: `supabase/functions/sync-reviewer-entitlement/index.ts`
- usage analytics ingestion function: `supabase/functions/usage-analytics/index.ts`

Edge Function secrets は、Supabase hosted defaults の `SUPABASE_URL`、`SUPABASE_PUBLISHABLE_KEYS`、`SUPABASE_SECRET_KEYS` を優先します。互換用に `SUPABASE_ANON_KEY` と `SUPABASE_SERVICE_ROLE_KEY` も読みます。追加で以下が必要です。

- `REVENUECAT_WEBHOOK_AUTHORIZATION`: RevenueCat dashboard 側にも設定する webhook 認証ヘッダー値
- `REVENUECAT_SECRET_API_KEY`: RevenueCat subscriber API 用の secret API key
- `REVENUECAT_PRO_ENTITLEMENT_ID`: Pro entitlement identifier

Supabase CLI が PATH にない環境では `npx supabase ...` で実行できます。`usage-analytics` は未ログインの opt-in event も受けるため、`supabase/config.toml` で `verify_jwt = false` を明示しています。

```bash
npx supabase db push
npx supabase functions deploy revenuecat-webhook
npx supabase functions deploy delete-account
npx supabase functions deploy sync-reviewer-entitlement
npx supabase functions deploy usage-analytics
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
- 利用改善 analytics 設計意図: [`_docs/intent/medo/usage_analytics.md`](_docs/intent/medo/usage_analytics.md)
- ドキュメント運用ガイド: [`_docs/documentation_guide.md`](_docs/documentation_guide.md)

## 現状の制約

- Drift / SQLite の永続化 Repository はアプリ画面へ接続済みです。現在のタイムラインは自動保存され、再起動後は最後に開いていたタイムラインが復元されます
- カレンダー書き出しは `.ics` 文字列生成に加えて、Android / iOS ではネイティブ API でカレンダーへ直接登録します。登録前に開始日時、アンカー日時、件数、日跨ぎ状態をプレビューで確認でき、同じタイムラインを同じ対象日に再登録する場合は前回の Medo 作成イベントを置き換えます
- `action.bufferMinutes` は Pro で編集できます。Free では既存データの余裕時間は保持・表示・逆算に反映しますが、新規編集は Paywall に誘導します
- Android / iOS のカレンダー登録では、権限拒否・書き込み可能カレンダーなし・ペイロード不正・保存失敗を domain error として区別します。iOS 17+ では前回登録の検索・削除に必要な full access を使用し、それ以前の OS では従来の event access にフォールバックします
- カレンダー登録時の書き込み先カレンダー選択 UI は未実装です。現状は未指定時に OS の既定カレンダーへ自動的に書き込みます
- ローカル通知は予約サービスのみ実装済みで、権限要求や予約操作を行う UI は未実装です
- Supabase には Auth、Pro 現在状態、service-only の RevenueCat event log、明示同意後の利用改善 analytics event だけを保持します。タイムライン、テンプレート、履歴、ローカル通知、カレンダー登録データは Supabase に同期しません
- 利用改善 analytics は既定で off です。設定画面で明示的に有効化した場合のみ、起動、作成、保存、共有、カレンダー登録、Paywall などの allowlist event と bucket 化済み property を送信します。タイムライン本文、タイトル、自由入力、raw time、メールアドレス、Supabase user id は送信しません
- アカウント削除は `delete-account` Edge Function 経由で Supabase Auth user を削除し、`user_pro_entitlements` と `pro_entitlement_events` は外部キーの cascade delete で削除されます。Edge Function 成功後、端末内の予定・テンプレート・履歴・Pro cache・通知予約・削除可能な共有一時ファイルも cleanup します。ストア購読のキャンセルは Google Play / App Store 側で別途行う必要があります
- Undo / Redo は未実装です
- `applyStartTimeEdit` は状態層に実装済みですが、現状の UI では直接使用していません
- Web / Linux / Windows では RevenueCat billing を Free fallback として扱います。macOS / iOS 用のランナー雛形は存在しますが、運用・検証状況は別途確認が必要です

## 検証済みコマンド

2026-05-14 時点で、少なくとも以下は通過済みです。

```bash
/home/penne/sdk/flutter/flutter/bin/flutter analyze lib/analytics/usage_analytics.dart lib/auth/auth_providers.dart lib/auth/account_deletion_cleanup.dart lib/persistence/app_database.dart lib/plan_panel.dart lib/settings/settings_screen.dart lib/timeline_screen.dart lib/template_sheet.dart lib/billing/billing_providers.dart lib/billing/paywall_screen.dart
/home/penne/sdk/flutter/flutter/bin/flutter test test/analytics/usage_analytics_test.dart test/auth/account_deletion_cleanup_test.dart
deno test --config supabase/functions/usage-analytics/deno.json --allow-env --allow-net supabase/functions/usage-analytics/index_test.ts
```
