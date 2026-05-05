# Project Task Management Rules

## 0. System Metadata
- **Current Max ID**: `Next ID No: 39` (※タスク追加時にインクリメント必須)
- **ID Source of Truth**: このファイルの `Next ID No` 行が、全プロジェクトにおける唯一のID発番元である。

## 1. Task Lifecycle (State Machine)
タスクは以下の順序で単方向に遷移する。逆行は原則禁止とする。

### Phase 0: Inbox (Human Write-only)
- **Location**: `# Inbox (Unsorted)` セクション
- **Description**: 人間がアイデアや依頼を書き殴る場所。フォーマット不問。ID未付与。
- **Exit Condition**: LLMが内容を解析し、IDを付与して `Backlog` へ構造化移動する。

### Phase 1: Backlog (Structured)
- **Location**: `# Backlog` セクション
- **Status**: タスクとして認識済みだが、着手準備未完了。
- **Entry Criteria**: 
  - IDが一意に採番されている。
  - 必須フィールド（Title, ID, Priority, Size, Area, Description）が埋まっている。
- **Exit Condition**: `Ready` の要件を満たす。

### Phase 2: Ready (Actionable)
- **Location**: `# Ready` セクション
- **Status**: いつでも着手可能な状態。
- **Entry Criteria**:
  - **Plan Requirement**:
    - `Size: M` 以上 (M, L, XL): `Plan` フィールドに有効な `_docs/plan/...` へのリンクが**必須**。
    - `Size: S` 以下 (XS, S): `Plan` は **None** でよい。
  - **Dependencies**: 解決済み（または明確化済み）である。
  - **Steps**: 具体的な実行手順（またはPlanへのポインタ）が記述されている。
- **Exit Condition**: 作業者がタスクに着手する。

### Phase 3: In Progress
- **Location**: `# In Progress` セクション
- **Status**: 現在実行中。
- **Entry Criteria**: 作業者がアサインされている（または自律的に着手）。

### Phase 4: Done
- **Location**: なし（行削除）
- **Exit Action**: `Goal` 達成を確認後、リストから物理削除する。

## 2. Schema & Validation
各タスクは以下の厳格なスキーマに従うこと。

| Field | Type | Constraint / Value Set |
| :--- | :--- | :--- |
| **Title** | `String` | `[Category] Title` 形式。Categoryは後述のEnum参照。 |
| **ID** | `String` | `{Area}-{Category}-{Number}` 形式。不変の一意キー。 |
| **Priority** | `Enum` | `P0` (Critical), `P1` (High), `P2` (Medium), `P3` (Low) |
| **Size** | `Enum` | `XS` (<0.5d), `S` (1d), `M` (2-3d), `L` (1w), `XL` (>2w) |
| **Area** | `Enum` | タスクの論理的な対象領域を表す値。`Plan` がある場合は原則として `_docs/plan/<Area>/...` 配下に対応付ける。 |
| **Dependencies**| `List<ID>`| 依存タスクIDの配列 `[Core-Feat-1, UI-Bug-2]`。なしは `[]`。 |
| **Goal** | `String` | 完了条件（Definition of Done）。 |
| **Steps** | `Markdown` | 進行管理用のチェックリスト（詳細は後述）。 |
| **Description** | `String` | タスクの詳細。 |
| **Plan** | `Path` | `Size >= M` の場合必須。`_docs/plan/` へのパス。`Size < M` は `None` 可。 |

## 3. Field Usage Guidelines

### Area & Directory Mapping
- **Rule**: `Area` フィールドはタスクの論理的な対象領域を表す分類ラベルとして扱う。
- **Planとの対応**: `Plan` が存在する場合は、原則として `Area` に対応する `_docs/plan/<Area>/...` 配下へ配置する。
- **New Area**: 新しい領域のタスクを作成する場合、`Size >= M` などで `Plan` が必要になった時点で、必要に応じて `_docs/plan/<Area>/` を作成する。
- **Example**:
  - `Area: Core` かつ `Plan: _docs/plan/Core/auth-feature.md`
  - `Area: Docs` かつ `Plan: None`

### Steps vs Plan
タスクの規模に応じて `Steps` の記述方針を切り替えること。情報の二重管理を避ける。

- **Case A: Planあり (Size >= M)**
  - `Steps` は **「Planを実行するための進行管理チェックリスト」** として機能する。
  - 詳細な仕様やコードは Plan に記述し、Steps には複製しない。
  - 例: `1. [ ] Planの "DB Schema" セクションに従いマイグレーション作成`

- **Case B: Planなし (Size < M)**
  - `Steps` に **「具体的な作業手順」** を直接記述する。
  - 例: `1. [ ] src/utils/format.ts の dateFormat 関数を修正`

## 4. Defined Enums

### Categories (Title & ID)
ID生成およびタイトルのプレフィックスには以下のみを使用する。
- `Feat` (New Feature)
- `Enhance` (Improvement)
- `Bug` (Fix)
- `Refactor` (Code Structuring)
- `Perf` (Performance)
- `Doc` (Documentation)
- `Test` (Testing)
- `Chore` (Maintenance/Misc)

### Areas (Examples)
**※`Area` は論理的な分類ラベルであり、`Plan` がある場合に原則 `_docs/plan/<Area>/...` と対応する。**
- `Core`: 基盤ロジック
- `UI`: プレゼンテーション層
- `Docs`: ドキュメント整備自体
- `General`: 特定ドメインに属さない雑多なタスク
- `DevOps`: CI/CD, 環境構築

## 5. Operational Workflows (for LLM)

### [Action] Create Task from Inbox
1. `Next ID No` を読み取り、割り当て予定のIDを決定する。
2. `Next ID No` をインクリメントしてファイルを更新する。
3. Inboxの内容を解析し、最適な `Area` と `Category` を決定する。
4. IDを生成する（例: `Core-Feat-24`）。
5. タスクをフォーマットし、`Backlog` の末尾に追加する。
6. 元のInbox行を削除する。

### [Action] Promote to Ready
1. **Size check**:
   - `Size >= M` ならば、`Plan` フィールドが有効なリンクであることを検証する。リンク切れや未作成の場合は移動を拒否する。
   - `Size < M` ならば、`Plan` が `None` でも許容する。
2. **Steps check**: `Steps` が具体的か（あるいはPlanへのポインタとして機能しているか）確認する。
3. **Dependency check**: 依存タスクが完了済みか確認する。
4. 全てクリアした場合のみ `Ready` セクションへ移動する。

## 6. Task Definition Examples (Few-Shot)

以下の例を参考に、サイズ（Size）に応じた記述ルール（Planの有無、Stepsの粒度）を厳守すること。

### Case A: Feature Implementation (Size >= M)
**Rule**: `Plan` へのリンクが必須。`Steps` はPlanの参照ポインタとして記述する。

```markdown
- **Title**: [Feat] User Authentication Flow
- **ID**: Core-Feat-25
- **Priority**: P0
- **Size**: M
- **Area**: Core
- **Dependencies**: []
- **Goal**: ユーザーがEmail/Passwordでサインアップおよびログインできる状態にする。
- **Steps**:
  1. [ ] Planの "Schema Design" セクションに基づき、Userテーブルのマイグレーションを作成・適用
  2. [ ] Planの "API Specification" に従い、`/auth/login` エンドポイントを実装
  3. [ ] Planの "Security" に記載されたJWT発行ロジックを実装
  4. [ ] E2Eテストを実施し、ログインフローの疎通を確認
- **Description**: 新規サービスの基盤となる認証機能を実装する。
- **Plan**: `_docs/plan/Core/auth-feature.md`
````

### Case B: Small Fix / Maintenance (Size \< M)

**Rule**: `Plan` は `None` でよい。`Steps` に具体的なコード修正手順を記述する。

```markdown
- **Title**: [Bug] Fix typo in Submit button
- **ID**: UI-Bug-26
- **Priority**: P2
- **Size**: XS
- **Area**: UI
- **Dependencies**: []
- **Goal**: ログイン画面のボタンのラベルが "Subimt" から "Submit" に修正されている。
- **Steps**:
  1. [ ] `src/components/LoginForm.tsx` を開く
  2. [ ] Submitボタンのラベル文字列を修正する
  3. [ ] ブラウザで表示を確認し、レイアウト崩れがないか確認
- **Description**: ユーザーから報告された誤字の修正。
- **Plan**: None
```

### Case C: New Area / Doc Task (Size S)

**Rule**: `Plan: None` のタスクでは、Area定義のためだけに `_docs/plan/` 配下のディレクトリ作成は不要。

```markdown
- **Title**: [Doc] Add Deployment Guide
- **ID**: DevOps-Doc-27
- **Priority**: P1
- **Size**: S
- **Area**: DevOps
- **Dependencies**: [Core-Feat-25]
- **Goal**: 新メンバー向けのデプロイ手順書が `_docs/guide/deployment.md` に作成されている。
- **Steps**:
  1. [ ] `_docs/guide/deployment.md` を作成し、ステージング環境へのデプロイ手順を記述
  2. [ ] 必要に応じて関連する参照先やリンクを更新
- **Description**: オンボーディングコスト削減のため、暗黙知になっているデプロイ手順をドキュメント化する。
- **Plan**: None
```

--- 

## Inbox
1. ホーム画面ウィジェット: 現在のプランの次の行動・残り時間を表示
2. Apple Watch対応: 現在時刻インジケーターと残り時間を腕で確認
(以下優先)
3. iOS対応: RevenueCatのiOS API keyを実値化し、iOSのPro判定・restore導線を確認する
4. ドキュメント運用: 実装済みタスクのTODO lifecycleを復旧し、完了済み/未完了を追跡可能に戻す



---

## Backlog

- **Title**: [Chore] Add debug Pro entitlement override
- **ID**: Core-Chore-26
- **Priority**: P1
- **Size**: S
- **Area**: Core
- **Dependencies**: [Core-Feat-19]
- **Goal**: debug / profile 環境で疑似 Pro / Free 状態を切り替え、Pro/Free gate の動作確認を RevenueCat の実 entitlement に依存せず行える。
- **Steps**:
  1. [ ] `ProOverride.actual / forceFree / forcePro` 相当の debug-only 状態を追加する
  2. [ ] gate 参照用の effective Pro 判定 provider を追加し、debug / profile では override を反映する
  3. [ ] release build では override UI と override 状態が無効になることを保証する
  4. [ ] 設定画面または開発者向け導線から override を切り替えられるようにする
  5. [ ] override 中であることが分かる小さな表示を追加する
  6. [ ] Free / Pro / actual 切替で、タイムライン数・テンプレート・画像エクスポートの gate が同じ判定を見ることを確認する
- **Description**: Core-Feat-19 の Pro/Free gate を検証しやすくするため、RevenueCat の実 entitlement とは別に debug / profile 限定の疑似 Pro 状態を導入する。本番 release では使用不可とし、gate 実装は最終的に effective Pro 判定を参照する。
- **Plan**: None

---

- **Title**: [Feat] Add timeline list island modal
- **ID**: UI-Feat-31
- **Priority**: P1
- **Size**: M
- **Area**: UI
- **Dependencies**: []
- **Goal**: floating button から画面下部に浮く island modal を開き、複数タイムラインの作成・命名・一覧・切り替え・削除・Free/Pro 上限制御を安全に扱える状態にする。
- **Steps**:
  1. [ ] Plan の "Data Model" と "Save / Load Ordering" に従い、current plan 復元と切替前保存の境界を実装する
  2. [ ] Plan の "Floating List Button" に従い、下端に接地しない timeline list island modal を追加する
  3. [ ] Plan の "Entitlement Model" に従い、Free は2件まで、Pro は無制限として新規作成可否を制御する
  4. [ ] modal 上部の作成フォーム、row inline rename、削除確認を追加する
  5. [ ] current timeline 削除時に、残存 timeline または新規空 timeline へ current を切り替える
  6. [ ] Plan の "Test Plan" に従い、repository / widget / narrow viewport の検証を実施する
  7. [ ] 実装結果を `_docs/reference/medo/persistence_repository_reference.md` と `_docs/guide/medo/timeline_editor.md` に反映する
- **Description**: 既存の `plans` を日常的なタイムライン一覧として扱い、header の既存ロード導線とは別に、floating button 起点の island modal でタイムラインを作成・命名・切り替え・削除できるようにする。
- **Plan**: `_docs/plan/UI/timeline-slot-toggle.md`

---

- **Title**: [Feat] Add RevenueCat webhook Edge Function
- **ID**: Core-Feat-33
- **Priority**: P0
- **Size**: M
- **Area**: Core
- **Dependencies**: []
- **Goal**: RevenueCat webhook を Supabase Edge Function で受信し、解決済み event の監査ログ保存と `user_pro_entitlements` の正規状態同期が冪等に動作する。
- **Steps**:
  1. [x] Plan の "Edge Function Script Design" に従い、`supabase/functions/revenuecat-webhook/index.ts` を追加する
  2. [x] RevenueCat authorization header を検証し、service role key / RevenueCat secret API key を Edge Function secret から読む
  3. [x] webhook event から Supabase `user_id` を解決し、解決できない event は DB に保存せず redacted log に逃がす
  4. [x] RevenueCat `GET /subscribers/{app_user_id}` を呼び、subscriber 情報から Pro entitlement の現在状態を導出する
  5. [x] `revenuecat_event_id` unique を使って `pro_entitlement_events` へ冪等 insert する
  6. [x] subscriber 正規状態を `user_pro_entitlements` へ upsert / update し、古い webhook で metadata を巻き戻さない
  7. [x] `revenuecat-webhook` function を deploy し、RevenueCat dashboard の webhook URL / authorization header を接続する
  8. [x] duplicate、unresolved user、RevenueCat API failure、out-of-order event の function tests または local replay を追加する
- **Description**: Flutter client に service role key を持たせず、RevenueCat webhook と subscriber API から Supabase の Pro entitlement state を server-side で更新する。
- **Plan**: `_docs/plan/Core/revenuecat-supabase-entitlement-sync.md`

---

- **Title**: [Enhance] Align account deletion with entitlement retention policy
- **ID**: Core-Enhance-35
- **Priority**: P0
- **Size**: M
- **Area**: Core
- **Dependencies**: []
- **Goal**: アカウント削除時に Supabase 上のメールアドレス、Pro状態、RevenueCat event log が削除され、privacy policy / Google Play Data Safety の説明と実装が一致している。
- **Steps**:
  1. [x] Plan の "Account Deletion Design" に従い、authenticated account deletion Edge Function を追加する
  2. [x] function は user JWT を検証し、service role で `auth.admin.deleteUser(user.id)` を実行する
  3. [x] `delete-account` function を deploy する
  4. [x] `user_pro_entitlements` と `pro_entitlement_events` が cascade delete されることを検証する
  5. [x] 設定画面に account deletion 導線を追加し、store subscription のキャンセルとは別操作であることを明示する
  6. [x] `_docs/standards/privacy-policy.md` の placeholder と削除説明を実装に合わせて更新する
  7. [x] Google Play Data Safety / account deletion URL に必要な記入内容を guide または README に反映する
- **Description**: 初期ローンチでは Supabase 側に transaction 系 ID をアカウント削除後も保持しない方針とし、法務・privacy policy・Google Play account deletion 要件に合わせて削除導線を整備する。
- **Plan**: `_docs/plan/Core/revenuecat-supabase-entitlement-sync.md`

---

- **Title**: [Feat] Add RevenueCat purchase flow to Paywall
- **ID**: Core-Feat-36
- **Priority**: P0
- **Size**: M
- **Area**: Core
- **Dependencies**: []
- **Goal**: closed testing のテスターがアプリ内 Paywall から Google Play sandbox purchase を開始し、RevenueCat / Supabase sync 後に Pro gate が開く導線を再現できる。
- **Steps**:
  1. [x] Plan の "Purchase Flow" に従い、RevenueCat offerings / package 取得と表示用 state を追加する
  2. [x] Paywall に Pro package の価格・期間表示と購入ボタンを追加し、商品未設定・loading・error を扱う
  3. [x] 購入ボタンから `Purchases.purchasePackage(...)` を呼び、キャンセル・失敗・成功を区別して UI に反映する
  4. [x] 購入成功後に RevenueCat CustomerInfo と `currentProEntitlementProvider` を再読込し、webhook 反映待ちを考慮した状態表示にする
  5. [x] 既存の restore 導線を維持し、purchase / restore のどちらでも entitlement provider refresh が走ることを確認する
  6. [ ] Plan の "Test Plan" に従い、unit / widget / Android closed testing sandbox purchase の検証を実施する
  7. [x] 実装結果を README または guide/reference の課金導線説明に反映する
- **Description**: 現状の Paywall は restore のみで、新規購入を開始できない。12人クローズドテストで「Play Store からインストール → ログイン → テスト購入 → RevenueCat webhook → Supabase entitlement → Pro解放」を各テスターが再現できるよう、RevenueCat の purchase flow を Paywall に接続する。
- **Plan**: `_docs/plan/Core/revenuecat-purchase-flow.md`

---

- **Title**: [Feat] Add action-level buffer time
- **ID**: Core-Feat-37
- **Priority**: P1
- **Size**: L
- **Area**: Core
- **Dependencies**: []
- **Goal**: 各 action block が実所要時間とは別に buffer time を持ち、Pro ユーザーは block 本体のダブルタップと詳細編集シートから buffer を設定でき、逆算・表示・テンプレート・共有・カレンダー登録に一貫して反映される。
- **Steps**:
  1. [ ] Plan の "Data Model" に従い、`Block` / codec / Drift schema / migration に `bufferMinutes` を追加する
  2. [ ] Plan の "Interaction Model" に従い、action body double tap で buffer を5分増やす導線を実装する
  3. [ ] Plan の "Visual Model" に従い、buffer 部分を action 本体より少し横幅の狭い別枠として表示する
  4. [ ] Plan の "Pro / Free Behavior" に従い、Free では既存 buffer を保持・計算反映しつつ新規追加・編集をロックする
  5. [ ] Plan の "Export / Sharing" に従い、テンプレート、カレンダー登録、テキスト共有、画像共有へ buffer を反映する
  6. [ ] Plan の "Test Plan" に従い、model / persistence / gesture / export / downgrade の検証を追加する
  7. [ ] README、timeline editor guide、domain / persistence / export references を実装結果に合わせて更新する
- **Description**: Medo の Pro 価値として、行動ごとに余裕時間を設定できる機能を追加する。buffer は通常の余裕 block ではなく action に紐づく余裕として管理し、`duration + bufferMinutes` を逆算に使う。
- **Plan**: `_docs/plan/Core/action-buffer-time.md`

---

- **Title**: [Feat] Add timeline alternative comparison
- **ID**: UI-Feat-38
- **Priority**: P1
- **Size**: L
- **Area**: UI
- **Dependencies**: [UI-Feat-31, Core-Feat-37]
- **Goal**: 同じ予定に対する2つの候補案を read-only の2列比較ビューで見比べ、時間比例の block 長、buffer 合計、開始時刻、総所要時間を確認したうえで、各案を採用または単独編集できる。
- **Steps**:
  1. [ ] Plan の "Data Model" に従い、comparison set / variant の persistence と repository を追加する
  2. [ ] Plan の "Fork / Clone" に従い、現在 plan から fresh block IDs の別案 plan を作成する helper を追加する
  3. [ ] Plan の "Interaction Model" に従い、`この予定の別案を作る` と `比較する` 導線を追加する
  4. [ ] Plan の "Comparison View" と "Visual Model" に従い、2列 read-only timeline renderer を実装する
  5. [ ] Plan の "Adopt / Edit" に従い、各列の `採用` / `編集` action を実装する
  6. [ ] Plan の "Pro / Free Behavior" に従い、比較機能の Pro gate と downgrade 時のデータ保持を実装する
  7. [ ] Plan の "Test Plan" に従い、repository / summary / widget / Pro-Free の検証を追加する
  8. [ ] timeline editor guide と persistence reference を実装結果に合わせて更新する
- **Description**: 既存の timeline list は別々の予定を保存・切り替える棚として維持し、comparison は同じ予定の候補案を作って比較・採用する Pro 機能として分離する。
- **Plan**: `_docs/plan/UI/timeline-alternative-comparison.md`

---

## Ready

---

## In Progress
