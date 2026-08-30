# agy statusline adapter

A one-line status bar for the [Antigravity CLI](https://antigravity.google)
(`agy`). Maps agy's stdin JSON + `git` onto the shared [`../core.sh`](../core.sh)
renderer.

```
BilgihanOS  main*  ·  Gemini 3.7 Flash hi  ·  ctx 87k/1.0M 8%
```

| Segment | Meaning |
| --- | --- |
| `BilgihanOS` | project dir basename |
| `main*` | git branch, `*` = uncommitted changes |
| `Gemini 3.7 Flash hi` | model (trailing `(High)` stripped) + effort (`lo` / `med` / `hi` / `max`) |
| `ctx 87k/1.0M 8%` | context tokens / window / fill (green < 50%, yellow < 80%, red ≥ 80%) |

No cost, duration, or line-change segment: agy's statusline payload carries none
of these. Sandbox / quota tails were dropped to keep all three adapters on the
same shape.

## Requirements

- `jq` on `PATH` (script exits silently if missing)
- `sh` (POSIX), `git`

## Install

Inside agy:

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

`/statusline delete` reverts to the built-in default.

## How it reads data

agy pipes a JSON blob very close to Claude Code's — same `model` / `workspace` /
`version` / `cwd` keys — plus:

- `context_window` — `{ total_input_tokens, context_window_size, used_percentage, current_usage }`.
  The adapter prefers `used_percentage × window`, falling back to `current_usage`,
  then `total_input_tokens`.
- `model.effort` — `low` / `medium` / `high`


