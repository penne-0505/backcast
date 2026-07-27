import {
  analyzePreToolUse,
  analyzeStop,
  analyzeUserPromptSubmit,
  auditEvidenceCount,
  isWorkflowSensitivePath,
  parsePorcelainPaths,
} from "./agent-workflow-hook.ts";

const assert = (condition: unknown, message: string): void => {
  if (!condition) {
    console.error(`FAIL ${message}`);
    Deno.exit(1);
  }
  console.log(`PASS ${message}`);
};

assert(
  parsePorcelainPaths(" M TODO.md\nR  old.md -> new.md\n?? scripts/x.mjs\n")
    .join(",") === "TODO.md,old.md,new.md,scripts/x.mjs",
  "parse git porcelain paths",
);

const userPromptResult = analyzeUserPromptSubmit();
assert(
  userPromptResult.decision === "context" &&
    userPromptResult.context.includes("plausible counterevidence") &&
    userPromptResult.context.includes("Scope") &&
    userPromptResult.context.length < 240,
  "AC-001 INV-001 keep per-prompt audit short and evidence-based",
);

const patchAudit = analyzePreToolUse({
  tool_name: "apply_patch",
  tool_input: { command: "*** Begin Patch\n*** Update File: README.md\n" },
});
const writeAudit = analyzePreToolUse({
  tool_name: "Write",
  tool_input: { file_path: "src/example.ts" },
});
assert(
  patchAudit?.decision === "context" &&
    patchAudit.context.includes("root cause") &&
    writeAudit?.decision === "context" &&
    writeAudit.context.includes("silently expanding scope"),
  "AC-002 INV-002 add durable write audit context",
);

assert(
  analyzePreToolUse({
    tool_name: "Read",
    tool_input: { file_path: "README.md" },
  }) === null,
  "INV-002 avoid write audit noise on read-only tools",
);

const workflowWriteAudit = analyzePreToolUse({
  tool_name: "Write",
  tool_input: { file_path: ".github/workflows/docs-ci.yml" },
});
assert(
  workflowWriteAudit?.decision === "context" &&
    workflowWriteAudit.context.includes("workflow-sensitive") &&
    workflowWriteAudit.context.includes("Risk High") &&
    workflowWriteAudit.context.includes("quality_assurance.md") &&
    workflowWriteAudit.context.includes("root cause") &&
    workflowWriteAudit.context.includes("silently expanding scope"),
  "AC-005 INV-006 warn about the Risk High document chain before workflow-sensitive writes",
);

assert(
  workflowWriteAudit?.decision === "context" &&
    workflowWriteAudit.context.includes("Judge the actual Risk yourself") &&
    workflowWriteAudit.context.includes("never settles the classification"),
  "AC-005 INV-006 write-time notice reports the requirement without settling Risk",
);

assert(
  writeAudit?.decision === "context" &&
    !writeAudit.context.includes("workflow-sensitive"),
  "AC-005 INV-006 keep ordinary source writes free of the workflow-sensitive notice",
);

const patchWorkflowAudit = analyzePreToolUse({
  tool_name: "apply_patch",
  tool_input: {
    command:
      "*** Begin Patch\n*** Update File: _docs/standards/quality_assurance.md\n",
  },
});
assert(
  patchWorkflowAudit?.decision === "context" &&
    patchWorkflowAudit.context.includes("workflow-sensitive"),
  "AC-005 INV-004 detect workflow-sensitive apply_patch targets like Codex uses",
);

assert(
  isWorkflowSensitivePath("AGENTS.md") &&
    isWorkflowSensitivePath("./_docs/standards/quality_assurance.md") &&
    isWorkflowSensitivePath(".claude/settings.json") &&
    !isWorkflowSensitivePath("README.md") &&
    !isWorkflowSensitivePath("_docs/qa/Workflow/x/test-plan.md"),
  "AC-005 single workflow-sensitive predicate is shared by write and stop audits",
);

assert(
  analyzePreToolUse({
    tool_name: "Bash",
    tool_input: { command: "git rm _docs/qa/Core/x/test-plan.md" },
  })?.decision === "block",
  "block git rm",
);

assert(
  analyzePreToolUse({
    tool_name: "Bash",
    tool_input: { command: "rm -rf _docs/intent/Core/x" },
  })?.decision === "block",
  "block rm",
);

assert(
  analyzePreToolUse({
    tool_name: "apply_patch",
    tool_input: { command: "*** Begin Patch\n*** Delete File: README.md\n" },
  })?.decision === "block",
  "block apply_patch file deletion",
);

assert(
  analyzePreToolUse({
    tool_name: "Write",
    tool_input: { file_path: ".env" },
  })?.decision === "block",
  "block sensitive file edit",
);

assert(
  analyzeStop({
    dirtyPaths: ["TODO.md", ".codex/hooks.json"],
    input: { last_assistant_message: "対応しました。" },
  })?.decision === "block",
  "stop hook nudges missing closure evidence",
);

assert(
  analyzeStop({
    dirtyPaths: ["TODO.md"],
    input: {
      last_assistant_message: "対応しました。qa-reviewと検証はPASSです。",
    },
  })?.decision === "block",
  "AC-003 INV-003 stop hook rejects verification without independent audit",
);

assert(
  analyzeStop({
    dirtyPaths: ["TODO.md"],
    input: {
      last_assistant_message:
        "対応しました。qa-reviewと検証はPASSです。反証候補を確認し、影響範囲と長期保守性を再監査しました。残リスクはありません。",
    },
  }) === null,
  "AC-003 INV-003 stop hook allows verification with multi-perspective audit",
);

assert(
  auditEvidenceCount("反証を確認し、影響範囲と長期保守性を監査した。") === 3,
  "INV-003 count distinct audit perspectives",
);

const fullyWordedClosure =
  "対応しました。qa-reviewと検証はPASSです。反証候補を確認し、影響範囲と長期保守性を再監査しました。残リスクはありません。";

const workflowWithoutDocs = analyzeStop({
  dirtyPaths: [".github/workflows/docs-ci.yml", "AGENTS.md"],
  input: { last_assistant_message: fullyWordedClosure },
});
assert(
  workflowWithoutDocs?.decision === "block" &&
    workflowWithoutDocs.reason.includes("_docs/intent/") &&
    workflowWithoutDocs.reason.includes("_docs/qa/") &&
    workflowWithoutDocs.reason.includes(".github/workflows/docs-ci.yml"),
  "AC-006 INV-007 stop hook requires closure from working-tree facts, not wording alone",
);

assert(
  analyzeStop({
    dirtyPaths: [
      ".github/workflows/docs-ci.yml",
      "_docs/qa/Workflow/x/verification.md",
    ],
    input: { last_assistant_message: fullyWordedClosure },
  }) === null,
  "AC-006 INV-007 accompanying QA docs satisfy the working-tree evidence condition",
);

assert(
  analyzeStop({
    dirtyPaths: [
      "_docs/standards/quality_assurance.md",
      "_docs/intent/Workflow/x/decision.md",
    ],
    input: { last_assistant_message: fullyWordedClosure },
  }) === null,
  "AC-006 INV-007 accompanying intent docs satisfy the working-tree evidence condition",
);

assert(
  workflowWithoutDocs?.decision === "block" &&
    workflowWithoutDocs.reason.includes("Risk High") &&
    workflowWithoutDocs.reason.includes("Plan") &&
    workflowWithoutDocs.reason.includes("QA test-plan") &&
    workflowWithoutDocs.reason.includes("verification"),
  "AC-007 stop message spells out the Risk High document chain for workflow-sensitive paths",
);

const todoOnlyBlock = analyzeStop({
  dirtyPaths: ["TODO.md"],
  input: { last_assistant_message: "対応しました。" },
});
assert(
  todoOnlyBlock?.decision === "block" &&
    !todoOnlyBlock.reason.includes("Risk High") &&
    !todoOnlyBlock.reason.includes("No change under _docs/intent/"),
  "AC-007 keep the Risk High chain out of non workflow-sensitive closures",
);

assert(
  analyzeStop({
    dirtyPaths: ["README.md"],
    input: {
      stop_hook_active: true,
      last_assistant_message: "対応しました。",
    },
  }) === null,
  "stop hook avoids recursive block",
);

const HOOK_SCRIPT = `${Deno.cwd()}/scripts/agent-workflow-hook.ts`;

const sanitizedEnv = (): Record<string, string> => {
  const env = { ...Deno.env.toObject() };
  delete env.LD_LIBRARY_PATH;
  delete env.LD_PRELOAD;
  return env;
};

const runGitIn = async (cwd: string, args: string[]): Promise<void> => {
  const output = await new Deno.Command("git", {
    args,
    cwd,
    clearEnv: true,
    env: sanitizedEnv(),
    stdout: "piped",
    stderr: "piped",
  }).output();
  if (!output.success) {
    throw new Error(
      `git ${args.join(" ")} failed: ${
        new TextDecoder().decode(output.stderr)
      }`,
    );
  }
};

const runStopHook = async (
  args: string[],
  cwd: string,
): Promise<{ code: number; stdout: string; stderr: string }> => {
  const command = new Deno.Command(Deno.execPath(), {
    args,
    cwd,
    clearEnv: true,
    env: sanitizedEnv(),
    stdin: "piped",
    stdout: "piped",
    stderr: "piped",
  });
  const child = command.spawn();
  const writer = child.stdin.getWriter();
  await writer.write(
    new TextEncoder().encode(
      JSON.stringify({
        hook_event_name: "Stop",
        last_assistant_message: "対応しました。",
      }),
    ),
  );
  await writer.close();
  const output = await child.output();
  return {
    code: output.code,
    stdout: new TextDecoder().decode(output.stdout).trim(),
    stderr: new TextDecoder().decode(output.stderr).trim(),
  };
};

const stopFixture = await Deno.makeTempDir({ prefix: "docs-dd-stop-hook-" });
try {
  await Deno.writeTextFile(`${stopFixture}/TODO.md`, "# TODO\n");
  await runGitIn(stopFixture, ["init", "--quiet"]);
  await runGitIn(stopFixture, ["config", "user.email", "hook@example.test"]);
  await runGitIn(stopFixture, ["config", "user.name", "Hook"]);
  await runGitIn(stopFixture, ["add", "TODO.md"]);
  await runGitIn(stopFixture, ["commit", "--quiet", "-m", "base"]);
  await Deno.writeTextFile(`${stopFixture}/TODO.md`, "# TODO\n\ndirty\n");

  const stopWithContract = await runStopHook([
    "run",
    "--allow-read",
    "--allow-env",
    "--allow-run=git",
    HOOK_SCRIPT,
    "stop",
  ], stopFixture);
  assert(
    stopWithContract.code === 0 &&
      stopWithContract.stdout.includes('"decision":"block"'),
    "Stop hook blocks under declared --allow-read --allow-env --allow-run=git",
  );

  const stopWithoutEnv = await runStopHook([
    "run",
    "--allow-read",
    "--allow-run=git",
    HOOK_SCRIPT,
    "stop",
  ], stopFixture);
  assert(
    stopWithoutEnv.code !== 0 &&
      stopWithoutEnv.stderr.includes("--allow-env") &&
      !stopWithoutEnv.stdout.includes('"decision"'),
    "Stop hook fails closed without --allow-env instead of silent skip",
  );
} finally {
  await Deno.remove(stopFixture, { recursive: true });
}
