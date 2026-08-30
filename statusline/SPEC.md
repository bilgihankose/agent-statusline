# statusline — shared contract

One renderer, many agents. Each agent CLI pipes its own JSON shape to a
`statusLine` command; a thin **adapter** normalises that into `SL_*` environment
variables and `exec`s `core.sh`, which owns the entire visual layout.

Adding a third agent = one new `<agent>/statusline.sh`. Never edit `core.sh` for
an agent-specific need — add it to that agent's adapter (`SL_EXTRA`) instead.

```
statusline/
  core.sh              renderer: SL_* env -> one line on stdout
  SPEC.md              this file
  claude-code/statusline.sh   adapter: Claude Code JSON + transcript -> SL_*
  agy/statusline.sh           adapter: Antigravity CLI JSON -> SL_*
  codex/statusline.sh         adapter: Codex rollout JSONL / sessions -> SL_*
```

## SL_* contract (adapter → core)

Every field is optional. A field that is empty or `0` drops its segment.

| Var | Type | Meaning |
| --- | --- | --- |
| `SL_PROJECT` | string | project name — adapter must `basename` it |
| `SL_BRANCH` | string | git branch; append `*` if the tree is dirty. Empty → no branch shown |
| `SL_MODEL` | string | model display name (strip any trailing `(High)` etc. — effort has its own slot) |
| `SL_EFFORT` | enum | normalised reasoning effort: `lo` \| `med` \| `hi` \| `max` \| `""` |
| `SL_CTX_USED` | int | context tokens in play right now. `0` → no context segment |
| `SL_CTX_WINDOW` | int | context window size. `>0` → percentage is shown and drives the colour |
| `SL_CTX_SYS` | int | optional breakdown: base tokens (system prompt + tools + memory + first msg) |
| `SL_CTX_MSG` | int | optional breakdown: tokens accumulated by the conversation since |
| `SL_ADDED` | int | lines added |
| `SL_REMOVED` | int | lines removed |
| `SL_DURATION` | string | pre-formatted (`2m18s`, `1h4m`). Empty → no duration segment |
| `SL_COST` | string | pre-formatted USD (`2.34`). Empty → no cost segment |
| `SL_EXTRA` | string | agent-specific tail, already coloured by the adapter if needed |

### Context segment: two shapes

- `SL_CTX_SYS > 0` **and** `SL_CTX_MSG > 0` → `sys 53k  msg 104k  Σ 157k`
  (used when the agent gives no window but the transcript yields a breakdown —
  Claude Code)
- otherwise → `ctx 87k/256k 34%`
  (used when the agent reports the window natively — agy, codex)

### Colours

`core.sh` owns all colour. Thresholds:

- **cost** — yellow at `≥ $5`, else green
- **context** — if `SL_CTX_WINDOW > 0`: green `< 50%`, yellow `< 80%`, red `≥ 80%`.
  If window unknown: green `< 200k`, yellow `< 400k`, red `≥ 400k`.
- **lines** — `+` green, `-` red always
- everything else — dim

## Segment order

```
project [branch] · model [effort] · $cost · +added -removed · duration · <context> · <extra>
```

## Per-agent data availability

| | Claude Code | agy | Codex |
| --- | --- | --- | --- |
| stdin / source | JSON (`model`, `cost`, `workspace`) | JSON (`model`, `window`, `quota`) | JSONL rollouts / stdin (`~/.codex/sessions/`) |
| context tokens | transcript `usage` parse → `sys/msg/Σ` | native `context_window` → `ctx N/W %` | rollout `token_count` → `ctx N/W %` |
| lines +/- | `cost.total_lines_*` (session-scoped) | — (not in payload) | — |
| duration | `cost.total_duration_ms` | — (not in payload) | — |
| cost | `cost.total_cost_usd` | — (not in payload) | — |
| effort | transcript `.effort` | `model.effort` | `turn_context.effort` |
| extra | — | `sbx` sandbox · `wk NN%` quota | `sbx` sandbox · `wk NN%` quota |

## core.sh resolution

Adapters find the renderer via `$(dirname "$0")/../core.sh`. Override with
`SL_CORE=/abs/path/core.sh` if you relocate a single adapter.
