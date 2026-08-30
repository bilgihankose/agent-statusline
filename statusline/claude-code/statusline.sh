#!/bin/sh
# Claude Code statusline adaptörü.
# Claude Code stdin'e bir JSON nesnesi verir. v2.1+ payload'ında effort, bağlam
# penceresi ve kullanılan token doğrudan bulunur (.effort, .context_window) —
# bunlar oturumun ilk turundan itibaren dolu gelir, transcript parse'ına gerek yok.
# Sadece sys/msg kırılımının tabanı transcript'teki ilk usage kaydından alınır
# (best-effort; transcript boşsa sade "ctx Σ/pencere %" biçimine düşer).
# Normalize alanları SL_* olarak çekirdek renderer'a devreder.
#
# Kurulum: ~/.claude/settings.json
#   "statusLine": { "type": "command",
#     "command": "/bin/sh \"/path/to/agent-statusline/statusline/claude-code/statusline.sh\"" }

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
  @sh "effort=\(.effort.level // "")",
  @sh "ctx_used=\(.context_window.total_input_tokens // 0)",
  @sh "ctx_win=\(.context_window.context_window_size // 0)",
  @sh "cents=\(((.cost.total_cost_usd // 0) * 100) | floor)"
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

# --- sys tabanı: transcript'teki ilk usage kaydı (best-effort) ---
# ilk asistan turu ~= sistem promptu + tool tanımları + hafıza + ilk mesaj  (= "sys")
# ctx_used (payload) ~= güncel bağlamın tamamı  (= "Σ")
# fark               ~= o günden bu yana biriken konuşma  (= "msg")
base_tok=0
if [ -n "$tpath" ] && [ -r "$tpath" ]; then
  base_tok=$(jq -rs '
    [ .[] | select(.message.usage) | .message.usage
      | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0) ]
    | if length > 0 then .[0] else 0 end
  ' "$tpath" 2>/dev/null)
fi
case "$base_tok" in ''|*[!0-9]*) base_tok=0 ;; esac
case "$ctx_used" in ''|*[!0-9]*) ctx_used=0 ;; esac
case "$ctx_win"  in ''|*[!0-9]*) ctx_win=0  ;; esac

msg_tok=$((ctx_used - base_tok)); [ "$msg_tok" -lt 0 ] && msg_tok=0
# taban güncel bağlamdan büyükse (yeni oturum, eski transcript) kırılımı gösterme
[ "$base_tok" -gt "$ctx_used" ] && base_tok=0

case "$effort" in
  low)       eff="lo"  ;;
  medium)    eff="med" ;;
  high)      eff="hi"  ;;
  max|xhigh) eff="max" ;;
  *)         eff=""    ;;
esac

export SL_PROJECT="$proj_name"
export SL_BRANCH="$branch"
export SL_MODEL="$model"
export SL_EFFORT="$eff"
export SL_CTX_USED="$ctx_used"
export SL_CTX_WINDOW="$ctx_win"
export SL_CTX_SYS="$base_tok"
export SL_CTX_MSG="$msg_tok"
export SL_ADDED=0               # satır sayacı kaldırıldı — üç adaptör aynı biçim
export SL_REMOVED=0
export SL_DURATION=""           # oturum süresi düşük sinyal — kaldırıldı (codex ile tutarlı)
export SL_COST="$cost_fmt"
export SL_EXTRA=""

exec /bin/sh "$CORE"
