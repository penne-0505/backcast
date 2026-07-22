# AGENTS.md

このファイルは、LLM/AI エージェントがリポジトリを扱う際の最小限のガイダンスです。

## 原則

- 日本語で会話する。
- 日付確認には`date`コマンドを使用する。
- tool や shell command を優先して使用する。
- **徹底的に現状実装・ドキュメントを参照、分析してから実装を行う。**
- **`git rm`や`rm`などのファイル削除は禁止**（ユーザーに提案し、実行は待つ）
- [documentation guidelines](_docs/standards/documentation_guidelines.md) と [documentation operations](_docs/standards/documentation_operations.md) を遵守して、積極的にドキュメントを更新する。`.agents/skills/` を積極活用してドキュメント更新と実装準備を行う。
- `Size >= M` または `Risk >= Medium` のタスクでは、実装前に QA test-plan を作成し、実装後に verification を残す。QA / テスト方針は [quality assurance standard](_docs/standards/quality_assurance.md) に従う。
- 完了前には `qa-review` skill を使い、verification verdict を確認する。
- 安全性・権限・secret・外部入力の扱いは [security for agents](_docs/standards/security_for_agents.md) に従う。
- root 直下の Markdown は active project guidance として扱う。一回限りの実装プロンプトは root に残さず、保持する場合は `_evals/prompts/` 等に移して非運用の履歴資料と明記する。
- QA / テストポリシーは過去のドキュメントに遡及適用しない。本ルールは今後作成するタスク・ドキュメントに対して適用する。
