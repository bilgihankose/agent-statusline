# claude-code statusline

A one-line status bar for [Claude Code](https://claude.com/claude-code), rendered
below the prompt on every state change.

```
BilgihanOS · Sonnet 5 med · $2.34 · +210 -12 · 25m · sys 53k  msg 104k  Σ 157k
```

| Segment | Meaning |
| --- | --- |
| `BilgihanOS` | project dir basename |
| `Sonnet 5 med` | model display name + reasoning effort (`lo` / `med` / `hi` / `max`) |
| `$2.34` | cumulative session cost in USD (turns yellow at ≥ $5) |
| `+210 -12` | file lines added / removed this session |
| `25m` | session duration |
| `sys 53k` | approx. tokens held by system prompt + tool schemas + memory files + first message (from the first transcript `usage` record) |
| `msg 104k` | approx. tokens accumulated by the conversation since then (last `usage` − first `usage`) |
| `Σ 157k` | total context tokens on the last request (green < 200k, yellow < 400k, red ≥ 400k) |

`sys` / `msg` is an approximation derived from the transcript's first vs. last
`usage` record — not an exact `/context` breakdown. Effort is read from the
transcript's top-level `.effort` field, so a mid-session `/config` change is
reflected immediately.

## Requirements

- `jq` on `PATH` (the script exits silently and prints nothing if it is missing)
- `sh` (POSIX; no bash-isms)

## Install

1. Copy the script somewhere stable:

   ```sh
   mkdir -p ~/.claude
   cp claude-code/statusline/statusline.sh ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Point Claude Code at it in `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "/bin/sh \"$HOME/.claude/statusline.sh\""
     }
   }
   ```

3. Start a new Claude Code session — the line appears under the input box.
   (An already-running session won't pick it up.)

## How it reads data

Claude Code pipes a JSON blob to the `statusLine` command on stdin containing
`model`, `workspace`, `cost`, and `transcript_path`. The script pulls cost and
model from that blob directly, then opens `transcript_path` (a JSONL file) to
compute the context-token breakdown and the current reasoning effort — data that
is not in the stdin blob.

## Notes

- Cost counts **only** Claude Code's own API calls. Work delegated to a separate
  CLI (`agy`, `codex`) is billed elsewhere and is invisible here. Sub-agents
  spawned via the Task tool *do* roll into this session's cost and transcript.
- The context window threshold colours assume a ~200k practical budget. Adjust
  the `190000` / `140000` / `200000` / `400000` constants in the script if you
  run with a 1M context.
