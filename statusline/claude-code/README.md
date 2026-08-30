# claude-code statusline adapter

A one-line status bar for [Claude Code](https://claude.com/claude-code), rendered
below the prompt on every state change. Maps Claude Code's stdin JSON + transcript
onto the shared [`../core.sh`](../core.sh) renderer.

```
BilgihanOS  main*  ·  Sonnet 5 med  ·  $2.34  ·  +210 -12  ·  2m18s  ·  sys 53k  msg 104k  Σ 157k
```

| Segment | Meaning |
| --- | --- |
| `BilgihanOS` | project dir basename |
| `main*` | git branch, `*` = uncommitted changes |
| `Sonnet 5 med` | model display name + reasoning effort (`lo` / `med` / `hi` / `max`) |
| `$2.34` | cumulative session cost in USD (yellow at ≥ $5) |
| `+210 -12` | file lines added / removed this session |
| `2m18s` | session duration |
| `sys 53k` | approx. tokens held by system prompt + tool schemas + memory files + first message (first transcript `usage` record) |
| `msg 104k` | approx. tokens accumulated by the conversation since (last `usage` − first `usage`) |
| `Σ 157k` | total context tokens on the last request (green < 200k, yellow < 400k, red ≥ 400k) |

`sys` / `msg` is an approximation from the transcript's first vs. last `usage`
record — not an exact `/context` breakdown. Effort comes from the transcript's
top-level `.effort`, so a mid-session `/config` change shows immediately.

## Requirements

- `jq` on `PATH` (script exits silently and prints nothing if missing)
- `sh` (POSIX), `git`

## Install

`~/.claude/settings.json`, then start a **new** Claude Code session:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/bin/sh \"$HOME/opensource/agent-cli-tools/statusline/claude-code/statusline.sh\""
  }
}
```

`git pull` updates the script; nothing else to do. To decouple from the repo,
copy both `statusline/core.sh` and `statusline/claude-code/statusline.sh`
somewhere stable (keeping the `../core.sh` relative layout, or set
`SL_CORE=/abs/core.sh`).

## How it reads data

Claude Code pipes a JSON blob to the command on stdin with `model`, `workspace`,
`cost`, and `transcript_path`. The adapter takes cost / lines / duration / model
from the blob, then opens `transcript_path` (JSONL) to compute the context-token
breakdown and current effort — data not in the blob.

## Notes

- Cost counts **only** Claude Code's own API calls. Work delegated to a separate
  CLI (`agy`, `codex`) is billed elsewhere. Task-tool sub-agents *do* roll in.
- Context colours assume a ~200k practical budget. On 1M context, adjust the
  `200000` / `400000` constants in `../core.sh`.
