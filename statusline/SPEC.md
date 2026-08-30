# statusline — shared contract

One renderer, many agents. Each agent CLI pipes its own JSON shape to a
`statusLine` command; a thin **adapter** normalises that into `SL_*` environment
variables and `exec`s `core.sh`, which owns the entire visual layout.

Adding another agent = one new `<agent>/statusline.sh`. Never edit `core.sh` for
an agent-specific need. `core.sh` still supports a few segments no current
adapter fills (`SL_ADDED`/`SL_REMOVED`, `SL_DURATION`, `SL_EXTRA`) — the three
adapters deliberately keep the same minimal shape.

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
| `SL_ADDED` | int | lines added — *no current adapter sets this* |
| `SL_REMOVED` | int | lines removed — *no current adapter sets this* |
| `SL_DURATION` | string | pre-formatted (`2m18s`, `1h4m`). Empty → no segment — *no current adapter sets this* |
| `SL_COST` | string | pre-formatted USD (`2.34`). Empty → no cost segment. Claude Code only |
| `SL_EXTRA` | string | agent-specific tail, pre-coloured by the adapter — *no current adapter sets this* |

### Context segment: two shapes

- `SL_CTX_SYS > 0` **and** `SL_CTX_MSG > 0` → `sys 53k  msg 104k  Σ 157k`
  (Claude Code: `Σ` + window from the stdin blob, `sys` baseline from the
  transcript's first `usage`. Codex: first vs last `token_count` event. Both
  collapse to the plain shape below on a fresh session with only one data point.)
- otherwise → `ctx 87k/256k 34%`
  (agy always; Claude Code / Codex on the first turn)

### Colours

`core.sh` owns all colour. Thresholds:

- **cost** — yellow at `≥ $5`, else green
- **context** — if `SL_CTX_WINDOW > 0`: green `< 50%`, yellow `< 80%`, red `≥ 80%`.
  If window unknown: green `< 200k`, yellow `< 400k`, red `≥ 400k`.
- **lines** (if ever set) — `+` green, `-` red
- everything else — dim

## Segment order

`core.sh` renders in this order, skipping any empty/zero segment:

```
project [branch] · model [effort] · $cost · +added -removed · duration · <context> · <extra>
```

The three shipped adapters only ever fill `project [branch] · model effort ·
[$cost] · <context>` — the rest is left empty on purpose so all three read the
same.

## Per-agent data availability

| | Claude Code | agy | Codex |
| --- | --- | --- | --- |
| stdin / source | JSON (`model`, `cost`, `workspace`, `effort`, `context_window`, `transcript_path`) | JSON (`model`, `context_window`, `workspace`) | JSONL rollouts (`~/.codex/sessions/`) or a file arg |
| context tokens | blob `context_window` (+ transcript first `usage` for `sys` baseline) → `sys/msg/Σ` | native `context_window` → `ctx N/W %` | rollout `token_count` (first vs last) → `sys/msg/Σ` |
| effort | blob `.effort.level` | `model.effort` | `turn_context.effort` |
| cost | `cost.total_cost_usd` | — (not in payload) | — (not in rollout) |
| lines +/- · duration · extra | dropped for a uniform shape | — | — |

## core.sh resolution

Adapters find the renderer via `$(dirname "$0")/../core.sh`. Override with
`SL_CORE=/abs/path/core.sh` if you relocate a single adapter.
