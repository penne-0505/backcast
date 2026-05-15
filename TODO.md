# Project Task Management Rules

## 0. System Metadata
- **Current Max ID**: `Next ID No: 59` (※タスク追加時にインクリメント必須)
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
3. iOS対応: RevenueCatのiOS API keyを実値化し、iOSのPro判定・restore導線を確認する
4. ローカライズ方針: 海外展開を見据えた i18n / ローカライズ方針を立てる
5. アンカーブロックの表示改善。グレーにして文字サイズとウェイト上げるか？
6. Android Live Action指定: 最近 Android に組み込まれた status bar chip 指定を試す。



---

## Backlog

- **Title**: [Enhance] Rebuild calendar export for duplicate control
- **ID**: Core-Enhance-55
- **Priority**: P1
- **Size**: M
- **Area**: Core
- **Dependencies**: []
- **Goal**: 同じ current plan と同じ対象日のカレンダー登録を再実行したとき、過去に Medo が作成した同一 export group の event を削除してから現在の timeline を再登録し、重複が増えない。
- **Steps**:
  1. [ ] Plan の "Export Group" に従い、current plan id と対象日を含む export group metadata を request 境界へ追加する
  2. [ ] Plan の "Marker Storage" に従い、Android / iOS の native event に Medo marker と export group key を保存する
  3. [ ] Plan の "Rebuild Flow" に従い、同一 export group の delete-before-insert を native delivery に実装する
  4. [ ] Plan の "Test Plan" に従い、同一 group 再 export、別日 export、marker なし event 非削除の検証を追加する
  5. [ ] calendar export reference と関連 docs を、置き換え登録の仕様へ同期する
  6. [ ] Android 実機または emulator で、同じ timeline / 同じ対象日を 2 回登録しても重複が増えないことを確認する
- **Description**: カレンダー登録の重複制御は field-by-field merge ではなく、Medo が過去に作成した同じ plan / 同じ対象日の event group を削除してから完全再構築する。`timelineId` 単独削除は別日の予定を巻き込むため避ける。
- **Plan**: `_docs/plan/Core/calendar-export-rebuild-deduplication.md`

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

- **Title**: [Enhance] Replace reorder shrink with placement preview
- **ID**: UI-Enhance-56
- **Priority**: P1
- **Size**: M
- **Area**: UI
- **Dependencies**: []
- **Goal**: 移動ハンドルで block を並び替える間、timeline 全体を縮小せず、押下位置近くの小さい preview と timeline 上の挿入線で「何を持っているか」と「どこへ入るか」を確認できる。
- **Steps**:
  1. [ ] Plan の "Implementation Notes" に従い、既存の `_reorderOverviewBlockId` / `effectivePixelsPerMinute` による縮小依存を preview state へ置き換える
  2. [ ] `_QuickReorderListener` から pointer position を親へ通知し、hold 成立後だけ dragged block preview を表示する
  3. [ ] Plan の "Interaction Model" に従い、candidate insert index から timeline 上の insertion line を描画する
  4. [ ] `proxyDecorator` を調整し、長時間 block の dragged proxy が preview と挿入線の読み取りを妨げないようにする
  5. [ ] Plan の "Test Plan" に従い、preview 表示/解除、reorder 後の順序、duration drag / swipe delete / inline edit の回帰を確認する
  6. [ ] timeline editor guide と timeline domain reference を、移動中の preview / insertion line 仕様へ同期する
- **Description**: 現行 plan は移動中に timeline を一時縮小し、その縮小を drag gap / proxy / 挿入判定へ同期させる方針だった。しかし Flutter reorder internals への依存が強く、見た目と判定の同期が複雑になる。今回は block 本体を変形せず、持っている block は小さい overlay preview、挿入先は line で示す interaction へ置き換える。
- **Plan**: `_docs/plan/UI/reorder-overview-scaling.md`

---

- **Title**: [Enhance] Align template save flow with timeline creation
- **ID**: UI-Enhance-54
- **Priority**: P1
- **Size**: M
- **Area**: UI
- **Dependencies**: []
- **Goal**: テンプレート保存時に、timeline list island modal の新規タイムライン作成と同じく、保存前に名前を入力し、現在の未保存編集を確定・保存したうえでテンプレートを作成できる。
- **Steps**:
  1. [ ] Plan の "Current Flow Gap" に従い、既存の `TemplateSheet._saveCurrent` と `TimelineScreen._createTimelineFromList` の責務差分を実装前に再確認する
  2. [ ] Plan の "UI Flow" に従い、template popover 上部に保存フォームを追加し、既定名・空欄正規化・キャンセルを timeline 作成フォームと同じ操作感に揃える
  3. [ ] Plan の "Persistence Boundary" に従い、テンプレート作成前に current plan の pending autosave を flush できる境界を `TimelineScreen` 側から渡す
  4. [ ] Plan の "Tests" に従い、template sheet widget test と repository / save boundary の targeted test を追加・更新する
  5. [ ] Plan の "Documentation" に従い、timeline editor guide と persistence reference を実装結果へ同期する
- **Description**: 現在のテンプレート保存は即時保存ボタンだけで、timeline 作成時の「先に命名して保存する」流れと揃っていない。保存対象が現在 timeline の snapshot である以上、名前入力と保存前 flush を同じ操作モデルに寄せる。
- **Plan**: `_docs/plan/UI/template-save-flow-alignment.md`

## In Progress
