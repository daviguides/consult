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

## Releasing — mandatory workflow

Every plugin modification MUST follow this sequence. No exceptions.

### 1. Bump version

Patch for fixes/tweaks, minor for new skills or behavioral changes.
Update `.claude-plugin/plugin.json` and `install.sh` header.

### 2. Commit and push

```bash
git add -A && git commit -m "bump: vX.Y.Z — <what changed>"
git tag -a vX.Y.Z -m "<what changed>"
git push && git push origin vX.Y.Z
```

### 3. Run install.sh

```bash
~/work/sources/continuum/gradients/consult/install.sh
```

install.sh clones from GitHub remote — push must land first.

### 4. Verify cache is not stale

The plugin cache (`~/.claude/plugins/cache/daviguides/consult/`) is
unstable — even after install, it can preserve stale state. install.sh
now patches `installed_plugins.json` and rebuilds the cache, but always
verify:

```bash
diff <(ls -lR ~/.claude/consult/skills/) <(ls -lR consult/skills/)
ls ~/.claude/plugins/cache/daviguides/consult/
```

If stale, nuke and reinstall:

```bash
rm -rf ~/.claude/plugins/cache/daviguides/consult/ ~/.claude/consult/
./install.sh
```
