# Project Task Management Rules

## 0. System Metadata
- **Current Max ID**: `Next ID No: 63` (※タスク追加時にインクリメント必須)
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
| **Risk** | `Enum` | （任意）`Low` \| `Medium` \| `High` \| `Critical`。未記載は `Low` 相当。失敗時の影響と検証難度で判断する。 |
| **QA** | `Path` | （任意）`Size >= M` または `Risk >= Medium` で必須。`_docs/qa/<Area>/<slug>/test-plan.md`。それ以外は `None` 可。 |
| **Verification** | `Path` | （任意）`Risk High/Critical` で完了前必須。`_docs/qa/<Area>/<slug>/verification.md`。それ以外は `None` 可。 |

### QA Requirement (今後のタスクに適用)

- `Size >= M` または `Risk >= Medium` のタスクは、実装前または実装中に QA test-plan を作成し、`QA` フィールドに `_docs/qa/<Area>/<slug>/test-plan.md` を記載する。
- `Risk High / Critical` のタスクは、完了前に verification を作成し、`Verification` フィールドに `_docs/qa/<Area>/<slug>/verification.md` を記載する。rollback / recovery / security / data safety の観点を含める。
- Bug は regression test または no-test rationale、Refactor は behavior-preservation checks を残す。
- 基準の詳細は `_docs/standards/quality_assurance.md`、運用は `_docs/standards/documentation_operations.md` を参照。
- **本ルールは今後作成するタスクに適用し、既存タスク・過去ドキュメントへ遡及しない。**

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

### Risk (任意)

失敗時の影響と検証難度で判断する（作業量ではない）。

- `Low`: 局所的で、失敗しても影響が小さい変更
- `Medium`: 機能挙動・ワークフロー・ドキュメント規約・skill に影響する変更
- `High`: 互換性・データ・認証・権限・課金・外部 API・CI/CD・migration に関わる変更
- `Critical`: 本番障害・secret 漏洩・重大なデータ破壊につながり得る変更

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
3. iOS対応: RevenueCatのiOS API keyを実値化し、iOSのPro判定・restore導線を確認する
4. ローカライズ方針: 海外展開を見据えた i18n / ローカライズ方針を立てる
5. アンカーブロックの表示改善。グレーにして文字サイズとウェイト上げるか？
6. Android Live Action指定: 最近 Android に組み込まれた status bar chip 指定を試す。
7. `test/template_sheet_test.dart` の保存フォーム系テストでは、focus 後の settle 待ちに依存せず固定時間 pump で完了条件を確認する。

---

## Backlog

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

- **Title**: [Feat] Paywall に年額プランを追加し 2 プラン選択式にする
- **ID**: UI-Feat-61
- **Priority**: P1
- **Size**: M
- **Area**: UI
- **Dependencies**: []
- **Goal**: RevenueCat offering の月額 480 円 / 年額 3,000 円（税込）の 2 パッケージが paywall にプラン選択カードとして表示され、選択したプランで購入が完了する。offering に片方しか無い場合は単一表示に degrade する。
- **Steps**:
  1. [ ] `_docs/plan/UI/paywall-annual-plan.md` を作成する（provider のリスト化、選択 UI、degrade 挙動、テスト方針）
  2. [ ] QA test-plan を `_docs/qa/UI/paywall-annual-plan/test-plan.md` に作成する
  3. [ ] Google Play Console に年額 3,000 円の商品を作成し、RevenueCat current offering に `$rc_annual` としてアタッチする（コンソール作業）
  4. [ ] `proPackageProvider` を単一パッケージからパッケージリスト返却に変更する
  5. [ ] `PaywallScreen` にプラン選択カード（2 枚・選択状態付き）を実装し、購入ボタンに選択中パッケージを渡す
  6. [ ] paywall の identity 分岐の重複（同一処理の if/else）と汎用 catch による BillingState 消失を整理する
  7. [ ] `test/billing/purchase_flow_test.dart` 等のテストを追随させ、verification を残す
- **Description**: 現状の `proPackageProvider` は `offering.monthly ?? offering.annual ?? availablePackages.first` で 1 パッケージに絞るため、月額が存在する限り年額はアプリ内から購入できない。販売意図（月額 480 円 / 年額 3,000 円の 2 プラン、買い切りなし）に合わせて選択式にする。課金導線のため Risk High。
- **Plan**: None（Ready 昇格前に `_docs/plan/UI/paywall-annual-plan.md` を作成する）
- **Risk**: High
- **QA**: `_docs/qa/UI/paywall-annual-plan/test-plan.md`（未作成・実装前に作成）
- **Verification**: `_docs/qa/UI/paywall-annual-plan/verification.md`（完了前に作成）

- **Title**: [Doc] 法務文書と実際の販売プラン表記の整合を確認する
- **ID**: Docs-Doc-62
- **Priority**: P1
- **Size**: XS
- **Area**: Docs
- **Dependencies**: []
- **Goal**: 特商法表記・プライバシーポリシー等の法務文書に記載するプラン内容が、アプリで実際に購入可能なプランと一致している（年額対応リリース前は「月額 480 円のみ」が事実である点を反映）。
- **Steps**:
  1. [ ] 法務文書のプラン・価格記載箇所を洗い出す
  2. [ ] UI-Feat-61 のリリース時期と照らし、記載内容（月額のみ / 2 プラン）を決定・修正する
- **Description**: paywall 調査（2026-07-03）で、アプリは現状月額のみ購入可能と判明。法務文書が「2 プラン販売」と記載する場合、年額対応リリースまで実態と乖離するため整合を取る。
- **Plan**: None

---

## Ready

---

## In Progress
