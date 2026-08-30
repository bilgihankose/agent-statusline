# agent-cli-tools

Drop-in utilities for coding-agent CLIs — **Claude Code**, **Antigravity `agy`**,
and **OpenAI Codex**. Plain `sh`, no build step, nothing to install but `jq`.
Point your agent's config at a file and you're done.

## `statusline` — one status line for every agent

Every agent CLI reports session state in its own format, or not at all. This
gives all of them the **same one-line readout**, so you glance at the same spot
whichever agent you're driving:

```
agent-cli-tools  main*  ·  Sonnet 5 med  ·  $2.34  ·  sys 53k  msg 104k  Σ 157k
agent-cli-tools  main*  ·  Gemini 3.7 Flash hi  ·  ctx 87k/1.0M 8%
agent-cli-tools  main*  ·  gpt-5.6-terra lo  ·  sys 22k  msg 6k  Σ 28k
```

At a glance: **project + branch**, **model + reasoning effort**, **session cost**
(Claude Code), and **how full the context window is** — broken into the
system-prompt/tools baseline (`sys`), the conversation since (`msg`), and the
total (`Σ`) wherever the agent exposes enough data; a plain `ctx used/window %`
otherwise.

One shared renderer, one ~80-line adapter per agent. Adding the next agent is a
single new file — the layout never moves.

→ [install & per-agent notes](statusline/) · [`SL_*` field contract](statusline/SPEC.md)

## Why this repo exists

Reusable agent tooling kept ending up buried in personal dotfiles where nobody
else could use it. This is the shareable home for it — MIT licensed, one
directory per tool.

## License

MIT — see [LICENSE](LICENSE).
