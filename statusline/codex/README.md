# Codex statusline adapter

A one-line status bar adapter for Codex. Reads the active or specified session
from `~/.codex/sessions/` (or parsed stdin) and maps it onto the shared
[`../core.sh`](../core.sh) renderer.

```
agent-cli-tools  main*  ·  gpt-5.6-terra lo  ·  sys 22k  msg 6k  Σ 28k
```

| Segment | Meaning |
| --- | --- |
| `agent-cli-tools` | project dir basename from session metadata |
| `main*` | git branch, `*` = uncommitted changes |
| `gpt-5.6-terra lo` | active model + normalised effort (`lo` / `med` / `hi` / `max`) |
| `sys 22k` | approx. tokens held by system prompt + tool schemas + first message (first `token_count` event) |
| `msg 6k` | approx. tokens accumulated by the conversation since (last `token_count` − first) |
| `Σ 28k` | last turn context tokens (green < 50%, yellow < 80%, red ≥ 80% of the window) |

No cost, duration, or line-change segment: Codex rollouts carry none of these.
Sandbox / quota tails were dropped to keep all three adapters on the same shape.

## Requirements

- `jq` on `PATH` (script exits silently if missing)
- `sh` (POSIX), `git`, `find`, `stat` — GNU (`stat -c`) or BSD/macOS (`stat -f`),
  the adapter tries both. Linux and macOS both work.

## Usage

Codex does not have a native custom statusline command hook, so this adapter
operates standalone (terminal prompt, tmux status bar, or cron/watch):

### 1. Standalone / Auto-detect latest session
```bash
/bin/sh /path/to/agent-cli-tools/statusline/codex/statusline.sh
```

### 2. Specific session file
```bash
/bin/sh /path/to/agent-cli-tools/statusline/codex/statusline.sh ~/.codex/sessions/2026/07/24/rollout-*.jsonl
```

### 3. Tmux statusline integration
In `~/.tmux.conf`:
```tmux
set -g status-right "#(/bin/sh /path/to/agent-cli-tools/statusline/codex/statusline.sh)"
set -g status-interval 5
```

## How it reads data

The adapter inspects Codex rollout files (`.jsonl`) which record:

- `turn_context` — `model`, `effort`, `cwd`
- `event_msg` (`token_count`) — `last_token_usage.input_tokens`, `model_context_window`
- `session_meta` — project dir fallback

The `sys` baseline is the **first** `token_count` event's `last_token_usage.input_tokens`;
`msg` is `Σ − sys`. A session with only one `token_count` event (fresh session)
has `msg = 0`, so the segment collapses to a plain `ctx Σ/window %`.
