# Consult - Claude Code Project Instructions

## Project Overview

**Consult** provides second-opinion consultation protocol for Claude Code, orchestrating queries to other LLM models and CLI harnesses.

**Purpose**: Plugin that enables safe, disciplined cross-model consultations. Unlike direct CLI calls, Consult enforces role-clause safety contracts, sandbox isolation, and adoption discipline.

---

## Structure

```
consult/
├── consult/                  # BUNDLE (installed to ~/.claude/consult)
├── skills/
│   └── ask/
│       └── SKILL.md          # Main consultation skill
├── .claude-plugin/
│   └── plugin.json
└── install.sh
```

---

## Targets

| Target | Model Family | Method | Auto-trigger |
|--------|-------------|--------|--------------|
| agy | Google (Gemini) | Antigravity CLI | Yes |
| kimi | Moonshot (K3) | Kimi Code CLI | Yes |
| opus | Anthropic (Opus 5) | Agent fork / CLI | No |
| fable | Anthropic (Fable 5) | Agent fork / CLI | No |
| codex | OpenAI (Codex) | Codex CLI | No |

---

## Commands

| Command | Purpose |
|---------|---------|
| `/consult:ask` | Consult another model (default: agy + kimi) |
| `/consult:ask <target>` | Consult specific target |

---

## Development Notes

- **Bundle pattern**: consultation specs inside `consult/consult/`
- **Safety-first**: every path enforces role clause + sandbox
- **No em dashes**: use `--` throughout all files

---

## Releasing

When creating a new version:

1. Update `.claude-plugin/plugin.json` version field
2. Commit the version bump
3. Create annotated tag: `git tag -a vX.Y.Z -m "message"`
4. Push with tag: `git push && git push origin vX.Y.Z`
