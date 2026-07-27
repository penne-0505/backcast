# Validator fixtures

These fixtures exercise the repository validators themselves.

They are not active project tasks or QA records. `scripts/test-validators.ts`
runs the validators against these files and expects:

- files under `valid/` to pass;
- files under `invalid/` to fail.

The intent, QA, and frontmatter fixtures run through their validators with `--fixture` and
use `fixture_path` front matter so the validators can apply the normal
canonical-path rules while the fixture files remain under `_evals/`.

The QA invalid fixture without `qa_schema` also verifies legacy compatibility:
legacy plans still require an `INV-*`, while schema v2 accepts `None`.

Frontmatter fixtures also verify that `intent_schema` and `qa_schema` are known
only for their matching document types, generic unknown fields are rejected by
the strict TypeScript validator, and duplicate or wrongly typed fields fail.
Backlog tasks may retain canonical future QA references until they become Ready
or In Progress.

The duplicate-block fixture uses a `.txt` extension because its intentionally
duplicated front matter is not valid Markdown. This keeps the full Markdown
lint set at zero errors without a project-wide or local ignore while the
frontmatter validator still reads the raw fixture content.
