# agent-cli-tools

Small, self-contained utilities for coding-agent CLIs — Claude Code, and (later)
Antigravity `agy`, OpenAI Codex.

Every tool is a single script with no build step. Copy it, point your config at it,
done. Each has its own README with install instructions.

## Tools

| Tool | What it does |
| --- | --- |
| [`claude-code/statusline`](claude-code/statusline/) | Terminal status line for Claude Code: session cost, lines changed, elapsed time, model + reasoning effort, and a `sys / msg / Σ` context-token breakdown read from the live transcript. |

## Why this repo exists

Reusable agent tooling was ending up buried in personal config dirs where nobody
else could use it. This repo is the shareable home for it — MIT licensed, one
directory per tool.

## License

MIT — see [LICENSE](LICENSE).
