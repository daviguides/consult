---
name: ask
description: |
  Consult another model or CLI harness for a second opinion.
  Spawns a consultant agent with the role-clause safety contract,
  inheriting session context (fork) or via external CLI (agy/kimi).

  Supported targets: opus, fable, kimi, agy, codex, all.
  - opus/fable: Always via Claude CLI (`claude -p --model claude-opus-5-5` / `claude-fable-5-1`). Agent tool cannot guarantee model version -- aliases resolve to session default, explicit IDs rejected.
  - kimi: Kimi Code CLI (`kimi -p` with `-m kimi-code/k3`).
  - agy: Antigravity CLI (`agy --print-timeout 1h -p` with `--model gemini-3.8-flash-high`). Always use model slug, never display name. Omit `--effort` flag if no value (empty string = silent failure). Omit `--sandbox` when writing files.
  - codex: OpenAI Codex CLI (`codex exec --model gpt-6-astra -c 'model_reasoning_effort="low"'`). Requires codex CLI installed.
  - all: parallel fan-out to every available target.

  AUTOMATIC TRIGGERS (proactive, model decides -- agy + kimi only):
  - After first evidence-backed refutation of a design
  - Ambiguous decision with no quick local evidence
  - Integration question about external model/API behavior
  - During EXPLORING/PLANNING/DESIGN: once first perspective is clear,
    second opinion is almost always positive (don't wait for failure)

  EXPLICIT TRIGGERS (user phrase required -- opus, fable, codex):
  - "ask opus", "pergunte ao opus", "consult opus"
  - "ask fable", "pergunte ao fable", "consult fable"
  - "ask codex", "pergunte ao codex", "consult codex"
  - "ask all", "second opinion from all", "consult all"

  DO NOT auto-trigger:
  - During IMPLEMENTING/BUGFIX: when a test/smoke/regression decides faster
  - Before forming your own clear first perspective
  - On mechanical/obvious tasks

  TARGET SELECTION:
  - agy + kimi: default pair for auto-triggers (different model families,
    proven session value). Both launched on every proactive trigger.
  - opus: explicit user request only. Best for adversarial code review,
    agentic architecture decisions, output verification.
  - fable: explicit user request only. Best for design of long-horizon
    agent systems, prompt engineering for Claude, creative reframing.
  - codex: explicit user request only. Different model family (OpenAI),
    valuable for OpenAI ecosystem questions and diverse blind spots.
  - all: explicit user request only.
argument-hint: opus|fable|kimi|agy|codex|all
---

# Consult: Second-Opinion Protocol

Ask another model or CLI harness for a second opinion on a technical decision.

## Step 1: Parse Target

Parse $ARGUMENTS to determine which consultant(s) to use:

| Argument | Target | Method |
|----------|--------|--------|
| `opus` | Claude Opus 5.5 (`claude-opus-5-5`) | Claude Code native subagent when supported; otherwise `claude -p --model opus` |
| `fable` | Claude Fable 5.1 (`claude-fable-5-1`) | Claude Code native subagent when supported; otherwise `claude -p --model fable` |
| `kimi` | Kimi K3 (Moonshot) | CLI: `kimi -p ... -m kimi-code/k3` |
| `agy` | Gemini 3.8 Flash | CLI: `agy --print-timeout 1h -p ... --model gemini-3.8-flash-high` |
| `codex` | OpenAI Codex | CLI: `codex exec --model gpt-6-astra -c 'model_reasoning_effort="low"' ...` (requires codex CLI) |
| `all` | All of the above | Parallel fan-out |

If no argument, default to agy + kimi (the auto-trigger pair).

## Step 2: Build the Consultation Prompt

Every consultation prompt follows this structure, in order:

1. **Role clause** (mandatory, always first line):

   **Default (analysis-only):**
   ```
   You are a CONSULTANT only. Do NOT write, edit, create or delete any
   project files. Do NOT execute any actions beyond analysis.
   At the end of your analysis, write a detailed markdown report of all
   findings to /tmp/consult-report-{target}.md (replace {target} with your
   model name, e.g. /tmp/consult-report-agy.md). This report is your
   primary deliverable.
   ```

   **With file deliverables (HTML, markdown, etc):**
   When the consultation requires generating files (mockups, design systems,
   landing pages, etc), specify an output directory and exact filenames:
   ```
   You are a CONSULTANT generating deliverables. Do NOT read, modify, or
   delete any existing project files. Do NOT execute any actions beyond
   generating the requested deliverables.
   Write your output ONLY to the specified output directory:
     {output_dir}/{target}/
   Files to generate: {file list with names}
   Do NOT write anywhere else. Do NOT read other files in the project
   unless explicitly listed in the prompt as context.
   ```
   The coordinator passes the output directory via prompt. Consultants write
   ONLY to `{output_dir}/{target}/`. For native subagents (opus/fable via
   Agent tool), they use the Write tool. For CLI targets, the coordinator
   extracts deliverables from stdout and writes them to the target directory.

   **Safety invariant:** consultants NEVER modify existing files. They create
   new files only in the designated output directory. `git status` (Step 4)
   catches violations.

2. **System context**: the relevant architecture (5-10 lines).

3. **Relevant history**: session logs, prior refutations, what was already tried.
   Explicit instruction: "this is the history, including approaches already tried
   and refuted with evidence; do NOT re-suggest anything refuted; reason FROM
   the refutations."

4. **Refutation conclusions**: not just the problem, but WHY the prior approach failed.

5. **Failure inventory by class** with concrete examples.

6. **Inviolable constraints**: what works today and must not break.

7. **Candidate design + specific questions** -- not "what do you think?".

The user provides the question/context. The skill wraps it with the role clause and structure.

## Step 3: Execute Consultation

### MANDATORY: nohup + Monitor for All CLI Calls

#### Why not Bash `run_in_background`?

The Bash tool's `run_in_background` parameter looks convenient but is **wrong
for consultations**:

1. **Timeout kills the process.** Default is 2 minutes. Even with `timeout:
   600000` (10 min), an LLM generating 1000+ lines of HTML routinely exceeds
   it. The process is killed with SIGTERM (exit code 144) and the output is
   silently truncated — no error, no warning, just incomplete HTML.
2. **No session survival.** If the Claude Code session ends or compresses
   context, the background process dies with it.
3. **No completion signal you control.** You get a task notification, but
   cannot customize what happens on completion.

`nohup` has none of these problems: no timeout, survives session end, output
goes to a file you control. Monitor gives you the completion notification.

#### The correct pattern

All CLI harness calls (agy, kimi, codex, claude) MUST use `nohup`:

```bash
# 1. Launch with nohup — NO timeout, survives session end
nohup <command> > {output_path} 2>&1 &
echo $!   # capture PID for monitoring
```

```
# 2. Arm Monitor for completion notification
Monitor({
  command: "while kill -0 <PID> 2>/dev/null; do sleep 10; done; echo '{target} consultation finished: {output_path}'",
  description: "{target} consultation completion",
  timeout_ms: 3600000
})
```

```
# 3. When Monitor fires, read the output
Read({file_path: "{output_path}"})
```

**Output path**: default `/tmp/consult-report-{target}.md`. If the user
specifies a custom directory, write there instead (e.g.
`/path/to/audits/consult-report-agy.md`).

#### Anti-pattern reference

```
❌ WRONG — killed after 2 min, truncated output, exit 144:
Bash({
  command: "kimi -p '...' -m kimi-code/k3",
  run_in_background: true,
  timeout: 600000
})

✅ CORRECT — no timeout, survives session, output to file:
Bash({ command: "nohup kimi -p '...' -m kimi-code/k3 > /tmp/consult-report-kimi.md 2>&1 & echo $!" })
Monitor({ command: "while kill -0 <PID> ...", timeout_ms: 3600000 })
```

Native Claude Code subagents (Agent tool for opus/fable) are not affected --
they have their own completion mechanism and do not need nohup.

### Headless Timeout Reference

Each harness behaves differently in headless (`-p` / `exec`) mode:

| Harness | Print timeout | Default | Configurable? | Action needed |
|---------|--------------|---------|---------------|---------------|
| **agy** | `--print-timeout` CLI flag | 5m | Yes (Go duration: `5m`, `1h`) | `--print-timeout 1h` |
| **claude** | None | Unlimited | N/A | None |
| **codex** | None documented | Unlimited | N/A | None |
| **kimi** | `print_wait_ceiling_s` in config | ~24.8 days | Yes (config.toml) | None (default is fine) |

Only **agy** needs an explicit timeout flag. The others run until completion.
agy docs: https://antigravity.google/docs/cli/headless

**Last resort** (if nohup + Monitor still fails for a target): save the prompt
to a file and instruct the user to run interactively via `!` in Claude Code:
```
! agy --sandbox --dangerously-skip-permissions --model "<model>" -p "$(cat <prompt-file>)"
```

### For opus/fable (always CLI)

**The Agent tool CANNOT be used for opus/fable consultations.** The Agent tool's
`model` parameter accepts only aliases (`opus`, `fable`) which resolve to the
session's own model version -- not necessarily the latest. Explicit model IDs
(e.g. `claude-opus-5-5`) are rejected with `InputValidationError`. There is no
way to guarantee the consultation runs on Opus 5.5 or Fable 5.1 via the Agent
tool.

**Always use the Claude CLI path below** -- it accepts explicit model IDs and
guarantees the correct model version.

#### Claude CLI path

Check `claude` is installed. If absent, report "claude CLI not installed" and
skip that target. Launch with nohup:

```bash
nohup claude -p --model claude-opus-5-5 --tools "" --strict-mcp-config "<built prompt>" \
  > /tmp/consult-report-opus.md 2>&1 &
echo $!
# For the fable target instead:
nohup claude -p --model claude-fable-5-1 --tools "" --strict-mcp-config "<built prompt>" \
  > /tmp/consult-report-fable.md 2>&1 &
echo $!
```

**Always use explicit model IDs** (`claude-opus-5-5`, `claude-fable-5-1`), not
aliases. Aliases resolve to the CLI's default, which may not match the intended
version. If the account or CLI rejects the requested model, report that target
as unavailable instead of substituting another model.

CLI safety: run with cwd OUTSIDE the project repo. Do NOT pass `--add-dir`.
`--tools ""` disables built-in tools and `--strict-mcp-config` excludes configured
MCP servers. Include all relevant context in the prompt; the CLI session does
not inherit the parent conversation. Pass the prompt through a structured
argument or stdin with proper shell quoting, never unescaped interpolation.
If Claude Code rejects a nested CLI session, report the limitation rather than
clearing its nesting guard or bypassing it.

### For kimi (CLI only)

```bash
nohup kimi -p "<built prompt>" -m kimi-code/k3 \
  > /tmp/consult-report-kimi.md 2>&1 &
echo $!
```

Safety: run with cwd OUTSIDE the project repo. Do NOT pass `--add-dir`.
Do NOT use `-y`/`--yolo` or `--auto`.

### For agy (CLI only)

```bash
# Analysis/opinion (default — read-only, sandboxed):
nohup agy --print-timeout 1h --sandbox --dangerously-skip-permissions \
  --model gemini-3.8-flash-high --effort low -p "<built prompt>" \
  > /tmp/consult-report-agy.md 2>&1 &
echo $!

# File deliverables (HTML, mockups, landing pages — needs write access):
nohup agy --print-timeout 1h --dangerously-skip-permissions \
  --model gemini-3.8-flash-high --effort high -p "<built prompt>" \
  > /tmp/consult-report-agy.md 2>&1 &
echo $!
```

#### AGY flags reference

| Flag | Purpose | Values | Notes |
|------|---------|--------|-------|
| `--model` | Model slug (use `agy models` to list) | `gemini-3.8-flash-high`, etc. | Always use slug, never display name |
| `--effort` | Agent reasoning effort | `low` / `medium` / `high` | **Omit flag entirely if no value** — empty string causes silent failure |
| `--print-timeout` | Headless timeout before kill | Go duration: `1h`, `30m` | Default 5m is too short for HTML generation |
| `--sandbox` | Restrict terminal writes | (flag, no value) | Use for analysis; **omit for file deliverables** (blocks writes) |
| `--dangerously-skip-permissions` | Auto-approve tool permissions | (flag, no value) | Required in headless mode to prevent interactive prompts |

**Model slug vs display name:** `agy models` shows both columns. Use the slug
(`gemini-3.8-flash-high`) not the display name (`Gemini 3.8 Flash (High)`) —
display names have spaces that break shell quoting and may not be accepted by
the CLI. Always quote-free slugs.

**`--effort` vs model tier:** The "High/Medium/Low" in the model name is the
model's built-in reasoning tier. `--effort` is a separate agent-level reasoning
knob. Both matter. For deliverables, use the High tier model AND `--effort high`.
**Never pass `--effort` with an empty string** — omit the flag entirely when no
effort level is specified.

**`--sandbox` vs file deliverables:** `--sandbox` prevents the agent from writing
files. For analysis-only consultations, use it. For consultations that must
generate files (HTML mockups, landing pages, design systems), **omit `--sandbox`**
and rely on the role clause to constrain writes to the output directory. Always
run `git status` after (Step 4) to catch any unexpected writes.

`--print-timeout 1h` prevents the default 5-min headless timeout from killing
the process before it finishes.

Safety: `--sandbox` prevents project writes. Also run with cwd OUTSIDE the
project repo when possible.

### For codex (CLI only)

```bash
# Analysis/opinion (default):
nohup codex exec --model gpt-6-astra -c 'model_reasoning_effort="low"' \
  --sandbox read-only --skip-git-repo-check "<built prompt>" \
  > /tmp/consult-report-codex.md 2>&1 &
echo $!

# File deliverables (HTML, mockups, landing pages):
nohup codex exec --model gpt-6-astra -c 'model_reasoning_effort="high"' \
  --sandbox read-only --skip-git-repo-check "<built prompt>" \
  > /tmp/consult-report-codex.md 2>&1 &
echo $!
```

#### Reasoning effort by consultation type

| Consultation type | `model_reasoning_effort` | Why |
|-------------------|--------------------------|-----|
| Analysis, second opinion, code review | `"low"` | Short output, factual, fast |
| File deliverables (HTML, mockups, design systems, landing pages) | `"high"` | Long structured output, creative, needs full generation capacity |

**Default is `"low"`.** Switch to `"high"` when the deliverable clause (Step 2)
specifies file output. With `"low"`, Codex truncates or iterates incomplete
attempts on long-form HTML generation (observed: 131-line design system vs
1500+ from other models on the same prompt).

`exec` runs non-interactively; `-p` selects a configuration profile, not a prompt.
Safety: run with cwd OUTSIDE the project repo. `--skip-git-repo-check` allows
that location, and `--sandbox read-only` prevents workspace writes.
Requires the OpenAI Codex CLI to be installed (`npm install -g @openai/codex`
or equivalent). If not available, report "codex CLI not installed" and skip.

### For all (parallel fan-out)

Apply the host-routing rules above independently to opus and fable. Launch all
CLI targets with nohup in a single Bash call (each with its own output file and
PID), then set up one Monitor per PID. Use native agents only on the eligible
Claude Code path. Collect all responses from their respective report files.

## Step 4: Post-Consultation Safety Check

After ANY consultation that used CLI:

```bash
git status
```

Any tree change not made by you is from the consultant -- revert before continuing.

## Step 5: Collect Results

The nohup redirect captures all harness output to `{output_path}`. The
consultant is also instructed to write structured findings to the same path.
Read the report file as the **primary** source of results.

```bash
cat /tmp/consult-report-agy.md   # or -kimi, -opus, -fable, -codex
```

**Custom output directory**: if the user specified a directory (e.g.
`output:/path/to/audits/`), the report lives at
`/path/to/audits/consult-report-{target}.md` instead of `/tmp/`.

## Step 6: Adoption Protocol

Before testing any suggestion from the consultant:

1. **Check if already tried**: confront each input against session logs and implementation notes. If already refuted, reject citing the log.
2. **Adopt only what's testable**: test each input one at a time.
3. **Non-actionable warnings**: log in session log for future reference.

## Step 7: Report

Present consultant output with:
- Source model identified
- Novel points highlighted (things not already in session context)
- Already-refuted suggestions flagged and skipped
- Actionable items separated from observations

For `all`: synthesize across models, highlight consensus and disagreements.

## Transient Unavailability

If any target fails (service error, timeout, rate limit):
1. At MOST 1 immediate retry.
2. If fails again, skip that target for THIS query only.
3. Try again on NEXT query -- don't mark as dead for the session.
4. Continue with other available targets.

## Model Selection Guide

### Auto-trigger pair (agy + kimi)

| Need | Target | Why |
|------|--------|-----|
| Blind spot check (different family) | agy + kimi | Different training, different biases, proven session value |
| Constrained decoding / external model behavior | agy | Gemini-native knowledge |
| Quick factual check | kimi or agy | Faster, cheaper than Claude models |

### Explicit request only (opus + fable)

| Need | Target | Why |
|------|--------|-----|
| Adversarial code review | opus | Opus 5.5 -- strong output verification (benchmark-proven) |
| Agentic architecture for Claude-based systems | opus | Opus 5.5 -- understands Claude behavior from inside |
| Design of long-horizon / multi-day agent systems | fable | Fable 5.1 -- purpose-built for sustained autonomous execution |
| Prompt engineering for Claude | fable | Fable 5.1 -- creative+analytical blend, better phrasings |
| Problem reframing / naming abstractions | fable | Fable 5.1 -- lateral thinking + analytical together |
| OpenAI ecosystem / API behavior questions | codex | Native OpenAI knowledge, different family |
| Maximum coverage | all | Parallel diverse perspectives |

### Why this split

agy (Gemini) and kimi (K3/Moonshot) are **different model families** from the
base session model. Different training = different blind spots = higher value as
second opinions. Proven in real sessions: agy caught scope-escape bugs,
kimi caught planner.txt blind spot.

Opus 5.5 and Fable 5.1 are **same family** as the base. Shared training means
shared blind spots on systematic biases. Their value is narrower: Opus 5.5
excels at self-verification and agentic reasoning, Fable 5.1 at long-horizon
and creative+analytical blend. Both are explicit-request-only until real
session evidence justifies auto-triggering for specific situations.
