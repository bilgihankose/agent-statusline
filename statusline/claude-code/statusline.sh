#!/bin/sh
# Claude Code statusline adaptörü.
# Claude Code stdin'e bir JSON nesnesi verir (.model, .workspace, .cost, .transcript_path).
# Bağlam token kırılımı transcript'teki usage kayıtlarından yaklaşık çıkarılır.
# Normalize alanları SL_* olarak çekirdek renderer'a devreder.
#
# Kurulum: ~/.claude/settings.json
#   "statusLine": { "type": "command",
#     "command": "/bin/sh \"$HOME/opensource/agent-cli-tools/statusline/claude-code/statusline.sh\"" }

LC_ALL=C
export LC_ALL

CORE="${SL_CORE:-$(dirname "$0")/../core.sh}"
input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0   # jq yoksa sessizce çık

eval "$(printf '%s' "$input" | jq -r '
  @sh "model=\(.model.display_name // "?")",
  @sh "proj=\(.workspace.project_dir // .workspace.current_dir // "")",
  @sh "cwd=\(.workspace.current_dir // .cwd // "")",
  @sh "tpath=\(.transcript_path // "")",
  @sh "cents=\(((.cost.total_cost_usd // 0) * 100) | floor)",
  @sh "added=\(.cost.total_lines_added // 0)",
  @sh "removed=\(.cost.total_lines_removed // 0)",
  @sh "secs=\(((.cost.total_duration_ms // 0) / 1000) | floor)"
')"

proj_name=$(basename "$proj" 2>/dev/null)
[ -z "$proj_name" ] && proj_name="~"

# --- git dalı (kirli işareti) ---
branch=""
if [ -n "$cwd" ] && command -v git >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null \
           || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ] && [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
    branch="${branch}*"
  fi
fi

# --- maliyet: cent -> X.XX ---
dollars=$((cents / 100)); rem=$((cents % 100))
cost_fmt=$(printf '%d.%02d' "$dollars" "$rem")

# --- süre ---
if   [ "$secs" -ge 3600 ]; then dur="$((secs / 3600))h$(((secs % 3600) / 60))m"
elif [ "$secs" -ge 60 ];   then dur="$((secs / 60))m$((secs % 60))s"
else dur="${secs}s"; fi

# --- bağlam kırılımı: transcript'teki ilk vs son usage kaydı ---
# ilk asistan turu ~= sistem promptu + tool tanımları + hafıza + ilk mesaj  (= "sys")
# son tur toplam   ~= güncel bağlamın tamamı  (= "Σ")
# fark             ~= o günden bu yana biriken konuşma  (= "msg")
base_tok=0; cur_tok=0; effort="-"
if [ -n "$tpath" ] && [ -r "$tpath" ]; then
  set -- $(jq -rs '
    ([ .[] | select(.message.usage) | .message.usage
       | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0) ]) as $t
    | ([ .[] | select(.type == "assistant" or .message.role == "assistant") | .effort // empty ]) as $e
    | (if ($t | length) > 0 then $t[0]  else 0 end),
      (if ($t | length) > 0 then $t[-1] else 0 end),
      ($e[-1] // "-")
  ' "$tpath" 2>/dev/null)
  base_tok=${1:-0}; cur_tok=${2:-0}; effort=${3:--}
fi
case "$base_tok" in ''|*[!0-9]*) base_tok=0 ;; esac
case "$cur_tok"  in ''|*[!0-9]*) cur_tok=0 ;; esac

msg_tok=$((cur_tok - base_tok)); [ "$msg_tok" -lt 0 ] && msg_tok=0

case "$effort" in
  low)      eff="lo"  ;;
  medium)   eff="med" ;;
  high)     eff="hi"  ;;
  max|xhigh) eff="max" ;;
  *)        eff=""    ;;
esac

export SL_PROJECT="$proj_name"
export SL_BRANCH="$branch"
export SL_MODEL="$model"
export SL_EFFORT="$eff"
export SL_CTX_USED="$cur_tok"
export SL_CTX_WINDOW=0          # Claude Code payload'ında pencere yok; mutlak eşik kullanılır
export SL_CTX_SYS="$base_tok"
export SL_CTX_MSG="$msg_tok"
export SL_ADDED="$added"
export SL_REMOVED="$removed"
export SL_DURATION="$dur"
export SL_COST="$cost_fmt"
export SL_EXTRA=""

exec /bin/sh "$CORE"
