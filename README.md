# Consult

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> Second-opinion consultations across models and CLI harnesses for Claude Code.

## What is Consult?

**Consult** is a Claude Code plugin that orchestrates second-opinion queries to other LLM models and CLI harnesses. It enforces a safety-first consultation protocol -- role-clause contracts, sandbox isolation, adoption discipline -- so you get diverse perspectives without risking your working tree.

## Installation

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/daviguides/consult/main/install.sh)"
```

## Targets

| Target | Model | Method | Trigger |
|--------|-------|--------|---------|
| `agy` | Gemini 3.5 Flash (Google) | Antigravity CLI | Auto |
| `kimi` | K3 (Moonshot AI) | Kimi Code CLI | Auto |
| `opus` | Claude Opus 5 (Anthropic) | Agent fork / Claude CLI | Explicit |
| `fable` | Claude Fable 5 (Anthropic) | Agent fork / Claude CLI | Explicit |
| `codex` | Codex (OpenAI) | Codex CLI | Explicit |
| `all` | All of the above | Parallel fan-out | Explicit |

### Auto-trigger pair: agy + kimi

These two are launched proactively by the model when consultation triggers fire:

- After first evidence-backed refutation of a design
- Ambiguous decision with no quick local evidence
- Integration question about external model/API behavior
- During EXPLORING/PLANNING/DESIGN: once first perspective is clear

**Why these two?** Different model families from the base (Opus 4.6). Different training = different blind spots = higher value as second opinions. Proven in real sessions.

### Explicit targets: opus, fable, codex, all

Activated only by user phrase ("ask opus", "pergunte ao fable", "consult codex", etc.). Same-family models (opus/fable) share blind spots with the base; their value is narrower but real for specific use cases.

## Usage

```bash
/consult:ask              # Default: agy + kimi
/consult:ask opus         # Consult Opus 5
/consult:ask fable        # Consult Fable 5
/consult:ask kimi         # Consult Kimi K3
/consult:ask agy          # Consult Gemini via agy
/consult:ask codex        # Consult OpenAI Codex
/consult:ask all          # Parallel fan-out to all targets
```

## Safety Protocol

Every consultation enforces:

1. **Role clause**: consultant-only contract as first line of every prompt
2. **Sandbox isolation**: cwd outside repo, no `--add-dir`, no `--yolo`/`--auto`
3. **Post-consultation check**: `git status` after every CLI consultation
4. **Adoption protocol**: confront suggestions against session logs before testing

## Model Selection Guide

| Need | Best target | Why |
|------|------------|-----|
| Blind spot check (different family) | agy + kimi | Different training, proven value |
| Constrained decoding questions | agy | Gemini-native knowledge |
| Adversarial code review | opus | Strong output verification |
| Agentic architecture for Claude systems | opus | Understands Claude from inside |
| Long-horizon agent design | fable | Purpose-built for sustained execution |
| Prompt engineering for Claude | fable | Creative+analytical blend |
| OpenAI ecosystem questions | codex | Native OpenAI knowledge |
| Maximum coverage | all | Parallel diverse perspectives |

## Relationship with Other Plugins

| Plugin | Relationship |
|--------|-------------|
| [arche](https://github.com/daviguides/arche) | Behavioral principles that govern consultation discipline |

## Project Structure

```
consult/
├── .claude-plugin/
│   └── plugin.json
├── consult/              # Bundle (installed to ~/.claude/consult)
├── skills/
│   └── ask/
│       └── SKILL.md      # Main consultation skill
├── install.sh
└── README.md
```

## License

MIT License

## Author

Second-opinion consultations for Claude Code.

---

> *"The test of a first-rate intelligence is the ability to hold two opposing ideas in mind at the same time and still retain the ability to function."*
> -- F. Scott Fitzgerald
