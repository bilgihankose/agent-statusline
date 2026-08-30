# claude-code statusline adapter

A one-line status bar for [Claude Code](https://claude.com/claude-code), rendered
below the prompt on every state change. Maps Claude Code's stdin JSON onto the
shared [`../core.sh`](../core.sh) renderer.

```
agent-statusline  main*  ·  Sonnet 5 med  ·  $2.34  ·  sys 53k  msg 104k  Σ 157k
```

| Segment | Meaning |
| --- | --- |
| `agent-statusline` | project dir basename |
| `main*` | git branch, `*` = uncommitted changes |
| `Sonnet 5 med` | model display name + reasoning effort (`lo` / `med` / `hi` / `max`) |
| `$2.34` | cumulative session cost in USD (yellow at ≥ $5) |
| `sys 53k` | approx. tokens held by system prompt + tool schemas + memory files + first message (first transcript `usage` record) |
| `msg 104k` | approx. tokens accumulated by the conversation since (last `usage` − first `usage`) |
| `Σ 157k` | total context tokens on the last request (green < 200k, yellow < 400k, red ≥ 400k) |

Effort, total context tokens (`Σ`), and the context window all come straight from
the stdin blob (`.effort.level`, `.context_window.*`), so they are populated from
the first render and a mid-session `/config` change shows immediately. Only the
`sys` baseline is read from the transcript's first `usage` record; `msg` is
`Σ − sys`. When the transcript has no `usage` yet (fresh session) the breakdown
collapses to a plain `ctx Σ/window %` segment.

## Requirements

- `jq` on `PATH` (script exits silently and prints nothing if missing)
- `sh` (POSIX), `git`

## Install

`~/.claude/settings.json`, then start a **new** Claude Code session:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/bin/sh \"/path/to/agent-statusline/statusline/claude-code/statusline.sh\""
  }
}
```

`git pull` updates the script; nothing else to do. To decouple from the repo,
copy both `statusline/core.sh` and `statusline/claude-code/statusline.sh`
somewhere stable (keeping the `../core.sh` relative layout, or set
`SL_CORE=/abs/core.sh`).

## How it reads data

Claude Code pipes a JSON blob to the command on stdin with `model`, `workspace`,
`cost`, `effort`, `context_window`, and `transcript_path`. The adapter takes
everything it renders from the blob; it only opens `transcript_path` (JSONL) to
read the first `usage` record for the `sys` baseline of the `sys/msg` split.

## Notes

- Cost counts **only** Claude Code's own API calls. Work delegated to a separate
  CLI (`agy`, `codex`) is billed elsewhere. Task-tool sub-agents *do* roll in.
- Context colours: when the blob carries `context_window.context_window_size`
  the segment is coloured by percentage (yellow ≥ 50%, red ≥ 80%). Without a
  window it falls back to the absolute `200000` / `400000` thresholds in
  `../core.sh`.
