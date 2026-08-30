# statusline

A one-line status bar for agent CLIs. One shared renderer (`core.sh`), one thin
adapter per agent. Same layout everywhere:

```
agent-statusline  main*  ·  Sonnet 5 med  ·  $2.34  ·  sys 53k  msg 104k  Σ 157k
agent-statusline  main*  ·  Gemini 3.7 Flash hi  ·  ctx 87k/1.0M 8%
agent-statusline  main*  ·  gpt-5.6-terra lo  ·  sys 22k  msg 6k  Σ 28k
```

Every adapter renders the same shape: `project [branch] · model effort ·
[$cost] · <context>`. Only Claude Code has cost; only Claude Code and Codex
have the `sys/msg/Σ` breakdown (agy shows `ctx N/W %`).

| Adapter | Agent | Notes |
| --- | --- | --- |
| [`claude-code/`](claude-code/) | [Claude Code](https://claude.com/claude-code) | cost + effort/context from the stdin blob, `sys/msg/Σ` split |
| [`agy/`](agy/) | [Antigravity CLI](https://antigravity.google) (`agy`) | native context %, no cost/lines in payload |
| [`codex/`](codex/) | Codex | auto-parses the latest `~/.codex/sessions/` rollout, `sys/msg/Σ` split |

Design and the `SL_*` field contract: [`SPEC.md`](SPEC.md).

## Requirements

- `jq` on `PATH` (adapter exits silently if missing)
- `sh` (POSIX), `git` (for the branch segment)

## Install

Point the agent's statusline setting straight at the adapter in your clone — no
copy, `git pull` updates it. Replace `/path/to/agent-statusline` below with wherever
you cloned this repo.

### Claude Code — `~/.claude/settings.json`

```json
{
  "statusLine": {
    "type": "command",
    "command": "/bin/sh \"/path/to/agent-statusline/statusline/claude-code/statusline.sh\""
  }
}
```

Start a **new** session to pick it up.

### agy — inside the CLI

```
/statusline /path/to/agent-statusline/statusline/agy/statusline.sh
/statusline on
```

or `~/.gemini/antigravity-cli/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "enabled": true,
    "command": "/bin/sh \"/path/to/agent-statusline/statusline/agy/statusline.sh\""
  }
}
```

## Adding another agent

1. `mkdir <agent>/ && $EDITOR <agent>/statusline.sh`
2. Read the agent's stdin JSON, set the `SL_*` vars (see `SPEC.md`), `exec /bin/sh "$(dirname "$0")/../core.sh"`.
3. Keep to the shared shape — leave a segment empty when the payload lacks it. `SL_EXTRA` exists for a genuinely agent-specific tail, but the three current adapters keep it empty on purpose. Don't touch `core.sh`.
