# agent-cli-tools

Small, self-contained utilities for coding-agent CLIs — Claude Code, Antigravity
`agy`, and OpenAI Codex.

Every tool is plain `sh` with no build step. Point your agent's config at it,
done. Each has its own README with install instructions.

## Tools

| Tool | What it does |
| --- | --- |
| [`statusline`](statusline/) | One terminal status line, one shared renderer, a thin adapter per agent. Same shape everywhere: `project [branch] · model effort · [$cost] · context`. **Claude Code** adds session cost and reads effort/context straight from the stdin blob; **Claude Code** and **Codex** show a `sys / msg / Σ` context breakdown, **agy** shows `ctx N/W %`. Contract in [`statusline/SPEC.md`](statusline/SPEC.md). |

## Why this repo exists

Reusable agent tooling was ending up buried in personal config dirs where nobody
else could use it. This repo is the shareable home for it — MIT licensed, one
directory per tool.

## License

MIT — see [LICENSE](LICENSE).
