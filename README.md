# agent-cli-tools

Small, self-contained utilities for coding-agent CLIs — Claude Code, Antigravity
`agy`, and (later) OpenAI Codex.

Every tool is plain `sh` with no build step. Point your agent's config at it,
done. Each has its own README with install instructions.

## Tools

| Tool | What it does |
| --- | --- |
| [`statusline`](statusline/) | One terminal status line, one shared renderer, a thin adapter per agent. **Claude Code:** session cost, lines changed, elapsed time, model + effort, `sys / msg / Σ` context breakdown from the transcript. **agy:** model + effort, lines changed, native context %, sandbox flag, weekly-quota tail. Contract in [`statusline/SPEC.md`](statusline/SPEC.md). |

## Why this repo exists

Reusable agent tooling was ending up buried in personal config dirs where nobody
else could use it. This repo is the shareable home for it — MIT licensed, one
directory per tool.

## License

MIT — see [LICENSE](LICENSE).
