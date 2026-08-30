# statusline

A one-line status bar for agent CLIs. One shared renderer (`core.sh`), one thin
adapter per agent. Same layout everywhere:

```
BilgihanOS  main*  ·  Sonnet 5 med  ·  $2.34  ·  +210 -12  ·  2m18s  ·  sys 53k  msg 104k  Σ 157k
BilgihanOS  main*  ·  Gemini 3.7 Flash hi  ·  +18 -3  ·  ctx 87k/1.0M 8%  ·  sbx  wk 41%
```

| Adapter | Agent | Notes |
| --- | --- | --- |
| [`claude-code/`](claude-code/) | [Claude Code](https://claude.com/claude-code) | cost + duration + `sys/msg/Σ` token breakdown from the transcript |
| [`agy/`](agy/) | [Antigravity CLI](https://antigravity.google) (`agy`) | native context %, weekly-quota + sandbox tail; no cost/duration in its payload |

Design and the `SL_*` field contract: [`SPEC.md`](SPEC.md).

## Requirements

- `jq` on `PATH` (adapter exits silently if missing)
- `sh` (POSIX), `git` (for branch + line counts)

## Install

Point the agent's statusline setting straight at the adapter in your clone — no
copy, `git pull` updates it.

### Claude Code — `~/.claude/settings.json`

```json
{
  "statusLine": {
    "type": "command",
    "command": "/bin/sh \"$HOME/opensource/agent-cli-tools/statusline/claude-code/statusline.sh\""
  }
}
```

Start a **new** session to pick it up.

### agy — inside the CLI

```
/statusline /Users/you/opensource/agent-cli-tools/statusline/agy/statusline.sh
/statusline on
```

or `~/.gemini/antigravity-cli/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "enabled": true,
    "command": "/bin/sh \"$HOME/opensource/agent-cli-tools/statusline/agy/statusline.sh\""
  }
}
```

## Adding another agent

1. `mkdir <agent>/ && $EDITOR <agent>/statusline.sh`
2. Read the agent's stdin JSON, set the `SL_*` vars (see `SPEC.md`), `exec /bin/sh "$(dirname "$0")/../core.sh"`.
3. Put anything agent-specific in `SL_EXTRA`. Don't touch `core.sh`.
