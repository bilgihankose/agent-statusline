# agent-statusline

Drop-in utilities for coding-agent CLIs — **Claude Code**, **Antigravity `agy`**,
and **OpenAI Codex**. Plain `sh`, no build step, nothing to install but `jq`.
Point your agent's config at a file and you're done.

## `statusline` — one status line for every agent

Every agent CLI reports session state in its own format, or not at all. This
gives all of them the **same one-line readout**, so you glance at the same spot
whichever agent you're driving:

```
agent-statusline  main*  ·  Sonnet 5 med  ·  $2.34  ·  sys 53k  msg 104k  Σ 157k
agent-statusline  main*  ·  Gemini 3.7 Flash hi  ·  ctx 87k/1.0M 8%
agent-statusline  main*  ·  gpt-5.6-terra lo  ·  sys 22k  msg 6k  Σ 28k
```

At a glance: **project + branch**, **model + reasoning effort**, **session cost**
(Claude Code), and **how full the context window is** — broken into the
system-prompt/tools baseline (`sys`), the conversation since (`msg`), and the
total (`Σ`) wherever the agent exposes enough data; a plain `ctx used/window %`
otherwise.

One shared renderer, one ~80-line adapter per agent. Adding the next agent is a
single new file — the layout never moves.

## Install

Needs `jq`, POSIX `sh`, and `git` on `PATH`. Works on Linux and macOS.

### Let your coding agent do it

Paste this to Claude Code, `agy`, Codex, or any agent with shell access:

```
Install the statusline from https://github.com/bilgihankose/agent-statusline for me.

1. Clone it somewhere stable (e.g. ~/.local/share/agent-statusline). If it's
   already cloned there, git pull instead.
2. Which agent CLI are you running inside — Claude Code, Antigravity agy, or
   Codex? If you can't tell for certain, ask me before changing any config.
3. Wire up that one adapter, using the ABSOLUTE path to the clone:
   - Claude Code — in ~/.claude/settings.json set:
       "statusLine": { "type": "command",
         "command": "/bin/sh \"<clone>/statusline/claude-code/statusline.sh\"" }
   - Antigravity agy — same shape in ~/.gemini/antigravity-cli/settings.json,
     pointing at statusline/agy/statusline.sh, plus "enabled": true
   - Codex — no native statusline hook. Ask me where I want it (shell prompt via
     PROMPT_COMMAND / precmd, or tmux status-right), then add:
       /bin/sh <clone>/statusline/codex/statusline.sh
4. Check `jq` is on PATH (the adapter is silent without it). Then tell me to
   restart the session.
```

### By hand

Per-agent config snippets: [`statusline/`](statusline/) · field contract:
[`statusline/SPEC.md`](statusline/SPEC.md)

## Why this repo exists

Reusable agent tooling kept ending up buried in personal dotfiles where nobody
else could use it. This is the shareable home for it — MIT licensed, one
directory per tool.

## License

MIT — see [LICENSE](LICENSE).
