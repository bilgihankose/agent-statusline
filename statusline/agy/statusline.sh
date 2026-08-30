#!/bin/sh
# Antigravity CLI (agy) statusline adaptörü.
# agy stdin'e Claude Code'unkine çok yakın bir JSON verir; farklar:
#   - .context_window   : bağlam token + pencere + yüzde  (native, transcript parse gerekmez)
#   - .model.effort     : reasoning effort
#   - .quota            : rate-limit kovaları (5h / haftalık)
#   - .sandbox.enabled  : sandbox kipi
#   - maliyet / süre / satır bilgisi YOK -> satırlar git'ten hesaplanır, maliyet atlanır
#
# Kurulum: agy içinde  /statusline <bu-dosyanın-yolu>   ya da
#   ~/.gemini/antigravity-cli/settings.json:
#   "statusLine": { "type": "command", "enabled": true,
#     "command": "/bin/sh \"$HOME/opensource/agent-cli-tools/statusline/agy/statusline.sh\"" }

LC_ALL=C
export LC_ALL

CORE="${SL_CORE:-$(dirname "$0")/../core.sh}"
input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

eval "$(printf '%s' "$input" | jq -r '
  @sh "model=\(.model.display_name // .model.id // "?")",
  @sh "effort=\(.model.effort // "")",
  @sh "proj=\(.workspace.project_dir // .workspace.current_dir // .cwd // "")",
  @sh "cwd=\(.workspace.current_dir // .cwd // "")",
  @sh "win=\(.context_window.context_window_size // 0 | floor)",
  @sh "pct=\(.context_window.used_percentage // 0 | floor)",
  @sh "cur_usage=\(.context_window.current_usage // 0 | floor)",
  @sh "in_tok=\(.context_window.total_input_tokens // 0 | floor)",
  @sh "sandbox=\(.sandbox.enabled // false)",
  @sh "astate=\(.agent_state // "")",
  @sh "wk_frac=\(.quota["gemini-weekly"].remaining_fraction // .quota["3p-weekly"].remaining_fraction // 1)"
')"

proj_name=$(basename "$proj" 2>/dev/null)
[ -z "$proj_name" ] && proj_name="~"

# --- model adından effort parantezini at: "Gemini 3.7 Flash (High)" -> "Gemini 3.7 Flash" ---
model=$(printf '%s' "$model" | sed -E 's/ *\((High|Medium|Low|high|medium|low)\) *$//')

case "$effort" in
  low)    eff="lo"  ;;
  medium) eff="med" ;;
  high)   eff="hi"  ;;
  max)    eff="max" ;;
  *)      eff=""    ;;
esac

# --- git dalı + satır değişimi (working tree vs HEAD; agy oturum tabanı vermiyor) ---
branch=""; added=0; removed=0
if [ -n "$cwd" ] && command -v git >/dev/null 2>&1 && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null \
           || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  [ -n "$branch" ] && [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ] && branch="${branch}*"
  set -- $(git -C "$cwd" diff --numstat HEAD 2>/dev/null | awk '
    $1 ~ /^[0-9]+$/ { a += $1 } $2 ~ /^[0-9]+$/ { r += $2 } END { print a + 0, r + 0 }')
  added=${1:-0}; removed=${2:-0}
fi

# --- bağlam: yüzde varsa ondan geri hesapla, yoksa current_usage, yoksa input token ---
used=0
if [ "$pct" -gt 0 ] && [ "$win" -gt 0 ]; then
  used=$(( win * pct / 100 ))
elif [ "$cur_usage" -gt 0 ]; then
  used=$cur_usage
else
  used=$in_tok
fi

# --- araç-özel kuyruk: sandbox + haftalık kota ---
DIM='\033[2m'; RST='\033[0m'; YEL='\033[33m'
extra=""
[ "$sandbox" = "true" ] && extra="${DIM}sbx${RST}"
# wk_frac 0..1 -> yüzde; sadece anlamlı düşünce (< %99) göster
wk_pct=$(printf '%s' "$wk_frac" | awk '{ printf "%d", $1 * 100 }')
case "$wk_pct" in ''|*[!0-9]*) wk_pct=100 ;; esac
if [ "$wk_pct" -lt 99 ]; then
  wcol="$DIM"; [ "$wk_pct" -lt 20 ] && wcol="$YEL"
  seg="${wcol}wk ${wk_pct}%${RST}"
  [ -n "$extra" ] && extra="${extra} ${seg}" || extra="$seg"
fi

export SL_PROJECT="$proj_name"
export SL_BRANCH="$branch"
export SL_MODEL="$model"
export SL_EFFORT="$eff"
export SL_CTX_USED="$used"
export SL_CTX_WINDOW="$win"
export SL_CTX_SYS=0            # agy kırılım vermiyor -> "ctx Σ/pencere %" biçimi
export SL_CTX_MSG=0
export SL_ADDED="$added"
export SL_REMOVED="$removed"
export SL_DURATION=""          # agy payload'ında süre yok
export SL_COST=""              # agy payload'ında maliyet yok
export SL_EXTRA="$extra"

exec /bin/sh "$CORE"
