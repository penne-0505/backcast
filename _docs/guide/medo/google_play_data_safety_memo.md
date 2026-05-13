---
title: Medo Google Play Data Safety Memo
status: active
draft_status: n/a
created_at: "2026-05-13"
updated_at: "2026-05-14"
references:
  - _docs/standards/privacy-policy.md
  - _docs/guide/medo/privacy_policy_operations.md
  - public/medo/privacy/index.html
related_issues: []
related_prs: []
---

# Medo Google Play Data Safety Memo

## Overview

このメモは、Google Play Console の Data Safety 入力時に参照するための候補整理です。法務助言ではなく、2026-05-14 時点の Medo の実装方針とプライバシーポリシーに基づく確認メモとして扱います。

Google Play のフォーム文言や分類は変更される可能性があるため、提出時は Play Console の最新項目に合わせて再確認してください。

## Current Product Boundary

- Androidアプリは、今日の予定の目処を立てるためのアプリ。
- タイムライン、予定名、予定時刻、テンプレートなどのユーザー作成データは、原則として端末内保存。
- Supabaseには、タイムライン、予定、テンプレートなどのユーザー作成データを保存しない。
- Web版はAndroidアプリ誘導用のデモで、課金導線はない。
- Web版ではPro課金情報を扱わず、タイムライン、予定、テンプレートなどのユーザー作成データを保存しない。
- Pro管理にはRevenueCat、Supabase Auth、Supabase、Google Playを使う。
- Googleログインは、主にPro購入、復元、権限管理のために使う。
- Firebase Analyticsは使わない。
- 利用改善analyticsは既定offで、設定画面で明示的に有効化した場合だけallowlist eventを送信する。
- 現状の実装検索では、RevenueCat subscriber attributesへメールアドレス、氏名、予定データ、自由入力内容を渡す処理は見つかっていない。
- 現状の実装検索では、フィードバック本文をアプリからサーバーへ送信する処理は見つかっていない。今後追加する場合は再確認する。

## Data Safety Input Candidates

### Personal Info

候補: 収集あり。

理由:

- Googleログイン時にメールアドレスをSupabase Authで扱う。
- Supabase Auth + Google OAuthの仕様により、表示名、プロフィール画像URL、Google由来のプロフィールメタデータがSupabase Authに保存される場合がある。
- 審査用temporary Pro allowlistでは、事前登録したメールアドレスとログイン済みユーザーのメールアドレスを照合する。
- ユーザーが問い合わせ・フィードバック本文を任意で送信する場合、返信先や本文を扱う可能性がある。

用途候補:

- Account management
- App functionality
- Developer communications / customer support（問い合わせ対応に使う場合）

注意:

- メールアドレスをRevenueCatへ渡さない方針であることを、実装で維持する。
- 表示名、プロフィール画像URL、Google由来のプロフィールメタデータを、予定データ同期、広告、プロファイリング目的に使わないこと。
- Googleログインを無料コア体験の必須条件にしていないことを、ストア説明やアプリ内導線と矛盾させない。

### Financial Info / Purchase History

候補: 収集あり。

理由:

- Google PlayとRevenueCatを通じて、Proサブスクリプションの購入状態を確認する。
- Supabaseの`user_pro_entitlements`と`pro_entitlement_events`に、Pro権限状態、商品ID、ストア、購入・有効期限に関する時刻、RevenueCatイベントID、取引IDなどを保存する場合がある。

用途候補:

- App functionality
- Account management
- Fraud prevention, security, and compliance

注意:

- Google Playの決済情報そのもの、支払い方法、カード番号等はアプリ側で扱わない。
- ユーザー向け購入履歴表示用のsanitized historyは保存しない。
- RevenueCat webhook raw payload全体はSupabaseに保存しない。
- Google PlayまたはRevenueCat側に法令、不正防止、決済管理、監査目的で残る情報は、各社のポリシーに従う。Play Console入力時は「削除されない/別手続き」の説明と矛盾しないようにする。

### App Activity / Analytics

候補: 収集あり。

理由:

- 明示同意後に、起動、初回タイムライン作成、タイムライン作成・保存、項目追加、項目並べ替え、テンプレート作成・適用、カレンダー登録開始・完了、テキスト/画像共有完了、Pro画面表示、購入開始、購入結果など、allowlistされた最小限のイベントを取得する可能性がある。

用途候補:

- Analytics
- App functionality

注意:

- 予定名、予定本文、テンプレート名、予定の正確な日時、移動先、自由入力テキストは送信しない。
- Firebase Analyticsを使わない方針を維持する。
- イベントに含める状態情報は、件数区分、結果区分、platformなど必要最小限にとどめ、予定内容を復元できる粒度にしない。
- 分析IDはアプリ内で生成するrandom install UUIDで、Supabase user idとは分離する。メールアドレスや予定内容はイベントに含めない。

### Device Or Other IDs

候補: 収集ありの可能性が高い。

理由:

- RevenueCat SDKおよびGoogle Playの課金処理は、購入管理、不正防止、利用資格確認のために、端末、インストール、ストア、購入に関する識別情報を処理する場合がある。
- Medo側のRevenueCat App User IDは、メールアドレスやGoogle IDではなくSupabase由来のUUIDを使う方針。
- 利用改善analyticsを有効化した場合、MedoはSupabase user idとは分離したrandom install UUIDをanalytics eventに含める。

用途候補:

- App functionality
- Fraud prevention, security, and compliance
- Account management

注意:

- 広告IDは取得しない方針。SDK追加時に広告ID権限や広告SDKが混入していないか確認する。
- RevenueCat App User IDには、メールアドレス、Google ID、広告ID、端末固有IDを使わず、Supabase由来の非推測UUIDを使うことを確認する。
- RevenueCat subscriber attributesにメールアドレス、氏名、予定データ、自由入力内容を渡す処理がないことを確認する。
- analytics install UUIDを導入しているため、Data Safety上の識別子分類をPlay Consoleの最新分類で再確認する。

### User-Generated Content

候補: 原則として予定データは収集なし。ただし、問い合わせ・フィードバック本文をユーザーが任意送信する場合は収集ありになる可能性がある。

理由:

- タイムライン、予定名、予定本文、テンプレートなどは端末内保存であり、SupabaseやRevenueCatへ送信しない方針。
- フィードバック送信は、現在のアプリ実装では本文送信処理が見つかっていない。将来、自由入力本文を送る導線を追加する場合は、User-generated contentまたは該当するData Safety分類の確認が必要。

注意:

- フィードバック送信で自由入力本文をサーバーへ送る実装にする場合は、予定名、予定本文、テンプレート名、予定の正確な日時を自動添付しないことを確認する。
- カレンダー書き出しや共有機能は端末内またはOS連携として扱う。クラウド同期を追加する場合は再確認が必要。

### Location, Health, Contacts, Messages, Photos, Audio, Files

候補: 現在の方針では収集なし。

注意:

- 将来、位置情報、連絡先、ファイルアップロード、クラウドバックアップなどを追加する場合は、実装前にData Safetyとプライバシーポリシーを更新する。

## Sharing / Third Parties

候補: Google Playの定義に従って要確認。

Medoは、Pro権限管理、認証、課金状態管理のために、Supabase、Google OAuth、RevenueCat、Google Playを利用する。Google Play Data Safetyでは、サービスプロバイダによる処理が「sharing」に該当しない場合もあるため、提出時はPlay Consoleの最新定義に照らして判断する。

少なくとも、第三者サービスによる処理があることは、プライバシーポリシー本文に明記している。問い合わせフォームやWebホスティング基盤の提供者がアクセスログや問い合わせ内容を処理する場合も、実際の利用サービスに合わせて確認する。

## Security / Deletion

候補:

- データは転送時に暗号化される: Supabase、RevenueCat、Google Play、Webフォーム等との通信がHTTPSであることを前提に候補とする。ただし、実装・設定を提出前に確認する。
- ユーザーはデータ削除をリクエストできる: アプリ内のアカウント削除、Web上の削除申請ページ、問い合わせ窓口があるため候補とする。

注意:

- アカウント削除はGoogle Playのサブスクリプション解約とは別手続きであることを、Data Safety、プライバシーポリシー、アプリ内表示でそろえる。
- アカウント削除URLまたは説明ページをPlay Consoleに登録する場合は、`https://otibo.dev/medo/account-deletion/` を候補とする。Medo名、開発者名、削除方法、削除されるデータ、削除されない/別手続きが必要なもの、購読解約は別手続きであることを確認できるページにする。
- Google PlayやRevenueCat側で法令、不正防止、決済管理、監査目的により保持される情報がある場合は、各社のポリシーに従う旨を説明する。

## Implementation Checks Before Submission

- アナリティクス実装で、予定名、予定本文、テンプレート名、予定の正確な日時、移動先、自由入力テキストを送っていないこと。
- アナリティクスが既定offで、同意後のallowlist eventだけを送ること。
- analytics install UUIDがSupabase user id、メールアドレス、Google ID、広告ID、端末固有IDではないこと。
- Google OAuthのスコープとSupabase Authに保存されるuser metadataの実値。メールアドレス以外の表示名、プロフィール画像URL、Google由来メタデータが保存される前提でData Safetyとポリシーをそろえること。
- RevenueCatのApp User IDがSupabase由来のUUIDであり、メールアドレス、Google ID、広告ID、端末固有IDではないこと。
- RevenueCat subscriber attributesへメールアドレス、氏名、予定データ、自由入力内容を設定する処理がないこと。
- Supabaseに、タイムライン、予定、テンプレートなどのユーザー作成データを保存するテーブルやAPIがないこと。
- `pro_entitlement_events`にRevenueCat webhook raw payload全体を保存していないこと。
- フィードバック送信の実装内容。自由入力本文をサーバーに送るなら、予定内容を自動添付しないこと、プライバシーポリシーとData Safetyの分類が一致すること。
- 広告ID権限、位置情報権限、Firebase Analytics、広告SDKがAndroidビルドに含まれていないこと。
