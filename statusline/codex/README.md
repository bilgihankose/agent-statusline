# Codex statusline adapter

A one-line status bar adapter for Codex. Reads the active or specified session
from `~/.codex/sessions/` (or parsed stdin) and maps it onto the shared
[`../core.sh`](../core.sh) renderer.

```
realtime-voice-chat  main*  ·  gpt-5.6-terra lo  ·  ctx 28k/258k 11%  ·  sbx  wk 68%
```

| Segment | Meaning |
| --- | --- |
| `realtime-voice-chat` | project dir basename from session metadata |
| `main*` | git branch, `*` = uncommitted changes |
| `gpt-5.6-terra lo` | active model + normalised effort (`lo` / `med` / `hi` / `max`) |
| `ctx 28k/258k 11%` | last turn context tokens / model context window / percentage |
| `sbx` | shown when the session runs in a sandbox container/profile |
| `wk 68%` | rate-limit quota remaining (derived from `rate_limits.primary.used_percent`) |

## Requirements

- `jq` on `PATH` (script exits silently if missing)
- `sh` (POSIX), `git`

## Usage

Codex does not have a native custom statusline command hook, so this adapter
operates standalone (terminal prompt, tmux status bar, or cron/watch):

### 1. Standalone / Auto-detect latest session
```bash
/bin/sh ~/opensource/agent-cli-tools/statusline/codex/statusline.sh
```

### 2. Specific session file
```bash
/bin/sh ~/opensource/agent-cli-tools/statusline/codex/statusline.sh ~/.codex/sessions/2026/07/24/rollout-*.jsonl
```

### 3. Tmux statusline integration
In `~/.tmux.conf`:
```tmux
set -g status-right "#(/bin/sh $HOME/opensource/agent-cli-tools/statusline/codex/statusline.sh)"
set -g status-interval 5
```

## How it reads data

The adapter inspects Codex rollout files (`.jsonl`) which record:

- `turn_context` — `model`, `effort`, `cwd`, `sandbox_policy`
- `event_msg` (`token_count`) — `last_token_usage.input_tokens`, `model_context_window`, `rate_limits`
- `session_meta` and message timestamps — session elapsed time calculation
