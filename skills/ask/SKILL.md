---
name: ask
description: |
  Consult another model or CLI harness for a second opinion.
  Spawns a consultant agent with the role-clause safety contract,
  inheriting session context (fork) or via external CLI (agy/kimi).

  Supported targets: opus, fable, kimi, agy, codex, all.
  - opus/fable: Native subagent inside Claude Code when model selection is supported; Claude CLI elsewhere.
  - kimi: Kimi Code CLI (`kimi -p` with `-m kimi-code/k3`).
  - agy: Antigravity CLI (`agy --print-timeout 1h -p` with `--model "Gemini 3.8 Flash (High)"`).
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
| `opus` | Claude Opus | Claude Code native subagent when supported; otherwise `claude -p --model opus` |
| `fable` | Claude Fable | Claude Code native subagent when supported; otherwise `claude -p --model fable` |
| `kimi` | Kimi K3 (Moonshot) | CLI: `kimi -p ... -m kimi-code/k3` |
| `agy` | Gemini 3.8 Flash | CLI: `agy --print-timeout 1h -p ... --model "Gemini 3.8 Flash (High)"` |
| `codex` | OpenAI Codex | CLI: `codex exec --model gpt-6-astra -c 'model_reasoning_effort="low"' ...` (requires codex CLI) |
| `all` | All of the above | Parallel fan-out |

If no argument, default to agy + kimi (the auto-trigger pair).

## Step 2: Build the Consultation Prompt

Every consultation prompt follows this structure, in order:

1. **Role clause** (mandatory, always first line):
   ```
   You are a CONSULTANT only. Do NOT write, edit, create or delete any
   project files. Do NOT execute any actions beyond analysis.
   At the end of your analysis, write a detailed markdown report of all
   findings to /tmp/consult-report-{target}.md (replace {target} with your
   model name, e.g. /tmp/consult-report-agy.md). This report is your
   primary deliverable.
   ```

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

### MANDATORY: Background Mode for CLI Calls

All CLI calls to external harnesses (agy, kimi, codex, claude) MUST use the
Bash tool with `run_in_background: true`. These harnesses are agentic and
routinely take 2-5+ minutes to produce output. Synchronous Bash calls hit the
timeout ceiling (default 120s, max 600s) and kill the process before the
harness finishes, resulting in empty or partial output.

**Execution flow:**
1. Launch the CLI command with `run_in_background: true`.
2. Wait for the background task notification (arrives automatically).
3. Read the output file from the notification to get the consultant's response.

This applies to every target that uses CLI: agy, kimi, codex, and the
`claude -p` fallback path for opus/fable. Native Claude Code subagents
(Agent tool) are not affected -- they have their own completion mechanism.

#### Timeout Limits

`run_in_background` itself has **no time limit** from Claude Code's side --
the process runs until it finishes. The synchronous Bash timeout (default 120s,
max 600s) does not apply to background tasks.

The real blocker is **agy's print timeout in headless mode**: agy kills itself
after 5 min without stdout output (default `--print-timeout`). Fix: pass
`--print-timeout 1h` (15 min) in the agy command. This flag is documented at
https://antigravity.google/docs/cli/headless and accepts Go duration format (e.g. `5m`, `15m`, `1h`).

| Harness | Headless behavior | Fix |
|---------|-------------------|-----|
| agy | print timeout (default 5 min, no incremental output in headless) | `--print-timeout 1h` |
| kimi | No known print timeout issue | None needed |
| codex | No known print timeout issue | None needed |
| claude | No known print timeout issue | None needed |

**All targets including agy work with `run_in_background: true`** when the
print timeout is set high enough.

**Last resort (agy still timing out):** save the prompt to a file and instruct
the user to run interactively via the `!` prefix in Claude Code:

```
! agy --sandbox --dangerously-skip-permissions --model "<model>" -p "$(cat <prompt-file>)"
```

Interactive mode produces incremental output, resetting the print timeout
continuously. No time limit.

### For opus/fable (route by host environment)

Determine the host from the session's runtime identity and exposed tool schemas.
The presence of `claude` on PATH only establishes CLI availability; it does not
mean the current agent is running inside Claude Code.

- **Inside Claude Code:** use its native Agent tool only when the exposed schema
  supports explicit selection of the requested model (`opus` or `fable`). Use an
  available subagent type; do not assume a `fork` type exists. Inherit context
  only if the tool supports it; otherwise include the full consultation prompt.
  If model selection is unsupported or rejected, use the CLI path below.
- **Inside Codex or another host, or if the host is uncertain:** go directly to
  the Claude CLI. Do not attempt to select Anthropic models through that host's
  native subagent tool.

Use tool/runtime metadata when available to verify model selection. An agent's
self-reported identity is not evidence of its actual model. If metadata is
unavailable, report the requested model without claiming it was verified.

#### Claude CLI path

Check `claude` is installed. If absent, report "claude CLI not installed" and
skip that target. Run the selected command non-interactively:

```bash
claude -p --model opus --tools "" --strict-mcp-config "<built prompt>"
# For the fable target instead:
claude -p --model fable --tools "" --strict-mcp-config "<built prompt>"
```

Use the alias matching the requested target; preserve an explicit full model ID
if the user supplies one. If the account or CLI rejects the requested model,
report that target as unavailable instead of substituting another model.

CLI safety: run with cwd OUTSIDE the project repo. Do NOT pass `--add-dir`.
`--tools ""` disables built-in tools and `--strict-mcp-config` excludes configured
MCP servers. Include all relevant context in the prompt; the CLI session does
not inherit the parent conversation. Pass the prompt through a structured
argument or stdin with proper shell quoting, never unescaped interpolation.
If Claude Code rejects a nested CLI session, report the limitation rather than
clearing its nesting guard or bypassing it.

### For kimi (CLI only)

```bash
kimi -p "<built prompt>" -m kimi-code/k3
```

Safety: run with cwd OUTSIDE the project repo. Do NOT pass `--add-dir`.
Do NOT use `-y`/`--yolo` or `--auto`.

### For agy (CLI only)

```bash
agy --print-timeout 1h -p "<built prompt>" --model "Gemini 3.8 Flash (High)"
```

`--print-timeout 1h` prevents the default 5-min headless timeout from killing
the process before it finishes.

Safety: use `--sandbox` flag OR run with cwd OUTSIDE the project repo.

### For codex (CLI only)

```bash
codex exec --model gpt-6-astra -c 'model_reasoning_effort="low"' \
  --sandbox read-only --skip-git-repo-check "<built prompt>"
```

Use `gpt-6-astra` with reasoning effort `low` for Codex consultations.
`exec` runs non-interactively; `-p` selects a configuration profile, not a prompt.
Safety: run with cwd OUTSIDE the project repo. `--skip-git-repo-check` allows
that location, and `--sandbox read-only` prevents workspace writes.
Requires the OpenAI Codex CLI to be installed (`npm install -g @openai/codex`
or equivalent). If not available, report "codex CLI not installed" and skip.

### For all (parallel fan-out)

Apply the host-routing rules above independently to opus and fable. Launch available targets in parallel where the host supports it, using native agents only on the eligible Claude Code path and CLI calls for the remaining targets. Collect all responses.

## Step 4: Post-Consultation Safety Check

After ANY consultation that used CLI:

```bash
git status
```

Any tree change not made by you is from the consultant -- revert before continuing.

## Step 5: Collect Results

The consultant writes a detailed report to `/tmp/consult-report-{target}.md`.
Read the report file as the **primary** source of results. CLI stdout is the
fallback if the report file was not created.

```bash
cat /tmp/consult-report-agy.md   # or -kimi, -opus, -fable, -codex
```

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
| Adversarial code review | opus | Strong output verification (benchmark-proven) |
| Agentic architecture for Claude-based systems | opus | Understands Claude behavior from inside |
| Design of long-horizon / multi-day agent systems | fable | Purpose-built for sustained autonomous execution |
| Prompt engineering for Claude | fable | Creative+analytical blend, better phrasings |
| Problem reframing / naming abstractions | fable | Lateral thinking + analytical together |
| OpenAI ecosystem / API behavior questions | codex | Native OpenAI knowledge, different family |
| Maximum coverage | all | Parallel diverse perspectives |

### Why this split

agy (Gemini) and kimi (K3/Moonshot) are **different model families** from the
base (Opus 4.6). Different training = different blind spots = higher value as
second opinions. Proven in real sessions: agy caught scope-escape bugs,
kimi caught planner.txt blind spot.

Opus 5 and Fable 5 are **same family** as the base. Shared training means
shared blind spots on systematic biases. Their value is narrower: Opus 5
excels at self-verification and agentic reasoning, Fable 5 at long-horizon
and creative+analytical blend. Both are explicit-request-only until real
session evidence justifies auto-triggering for specific situations.
