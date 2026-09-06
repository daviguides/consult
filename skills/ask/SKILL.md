---
name: ask
description: |
  Consult another model or CLI harness for a second opinion.
  Spawns a consultant agent with the role-clause safety contract,
  inheriting session context (fork) or via external CLI (agy/kimi).

  Supported targets: opus, fable, kimi, agy, codex, all.
  - opus/fable: Agent fork with model override, CLI fallback.
  - kimi: Kimi Code CLI (`kimi -p` with `-m kimi-code/k3`).
  - agy: Antigravity CLI (`agy -p` with `--model "Gemini 3.5 Flash (High)"`).
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
| `opus` | Claude Opus 5 | Agent fork (`model: "opus"`), CLI fallback |
| `fable` | Claude Fable 5 | Agent fork (`model: "fable"`), CLI fallback |
| `kimi` | Kimi K3 (Moonshot) | CLI: `kimi -p ... -m kimi-code/k3` |
| `agy` | Gemini 3.5 Flash | CLI: `agy -p ... --model "Gemini 3.5 Flash (High)"` |
| `codex` | OpenAI Codex | CLI: `codex exec --model gpt-6-astra -c 'model_reasoning_effort="low"' ...` (requires codex CLI) |
| `all` | All of the above | Parallel fan-out |

If no argument, default to agy + kimi (the auto-trigger pair).

## Step 2: Build the Consultation Prompt

Every consultation prompt follows this structure, in order:

1. **Role clause** (mandatory, always first line):
   ```
   You are a CONSULTANT only. Do NOT write, edit, create or delete any files.
   Do NOT execute any actions. Respond exclusively with analysis and
   recommendations in text.
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

### For opus/fable (fork-first)

Try Agent fork with model override first:

```
Agent({
  subagent_type: "fork",
  model: "<opus|fable>",
  name: "<model>-consult",
  prompt: "<built prompt>"
})
```

If fork model override is ignored (responds as parent model), fall back to CLI:

```bash
claude -p "<built prompt>" --model claude-<opus-5|fable-5>
```

CLI safety: run with cwd OUTSIDE the project repo. Do NOT pass `--add-dir`.

### For kimi (CLI only)

```bash
kimi -p "<built prompt>" -m kimi-code/k3
```

Safety: run with cwd OUTSIDE the project repo. Do NOT pass `--add-dir`.
Do NOT use `-y`/`--yolo` or `--auto`.

### For agy (CLI only)

```bash
agy -p "<built prompt>" --model "Gemini 3.5 Flash (High)"
```

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

Launch all available targets in parallel (multiple Agent calls in one message for forks, sequential CLI calls for kimi/agy). Collect all responses.

## Step 4: Post-Consultation Safety Check

After ANY consultation that used CLI:

```bash
git status
```

Any tree change not made by you is from the consultant -- revert before continuing.

## Step 5: Adoption Protocol

Before testing any suggestion from the consultant:

1. **Check if already tried**: confront each input against session logs and implementation notes. If already refuted, reject citing the log.
2. **Adopt only what's testable**: test each input one at a time.
3. **Non-actionable warnings**: log in session log for future reference.

## Step 6: Report

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
