#!/bin/sh
# Codex statusline adaptörü.
# Codex'in yerleşik statusline hook'u olmadığı için bu adaptör:
#   1) Argüman olarak rollout dosyası verilirse ($1) onu okur,
#   2) Argüman yoksa ~/.codex/sessions/ altındaki en son oturumu otomatik bulup okur.
#
# Çıktı: SL_* değişkenleri üzerinden shared core.sh renderer'ı çağırır.
#
# Kullanım:
#   - Standalone / tmux: /bin/sh ~/opensource/agent-cli-tools/statusline/codex/statusline.sh
#   - Belirli oturum:    /bin/sh .../statusline.sh ~/.codex/sessions/2026/07/24/rollout-*.jsonl

LC_ALL=C
export LC_ALL

CORE="${SL_CORE:-$(dirname "$0")/../core.sh}"
command -v jq >/dev/null 2>&1 || exit 0

file=""
if [ -n "$1" ] && [ -r "$1" ]; then
  file="$1"
fi

if [ -z "$file" ]; then
  sessions_dir="$HOME/.codex/sessions"
  if [ -d "$sessions_dir" ]; then
    file=$(find "$sessions_dir" -type f -name "rollout-*.jsonl" -exec stat -f "%m %N" {} + 2>/dev/null \
      | sort -n \
      | tail -n 1 \
      | cut -d' ' -f2-)
  fi
fi

if [ -z "$file" ] || [ ! -r "$file" ]; then
  exit 0
fi

eval "$(jq -s -r '
  def last_val(arr): if (arr | length) > 0 then arr[-1] else null end;
  (map(select(.type == "session_meta")) | last_val(.)) as $meta |
  (map(select(.type == "turn_context")) | last_val(.)) as $ctx |
  (map(select(.type == "event_msg" and .payload.type == "token_count")) | last_val(.)) as $tok |
  
  (if (.[0].timestamp and .[-1].timestamp) then
    ( (.[-1].timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) - 
      (.[0].timestamp   | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) )
   else 0 end) as $elapsed |

  @sh "model=\($ctx.payload.model // "codex")",
  @sh "effort=\($ctx.payload.effort // $ctx.payload.collaboration_mode.settings.reasoning_effort // "")",
  @sh "proj=\($ctx.payload.cwd // $meta.payload.cwd // "")",
  @sh "cwd=\($ctx.payload.cwd // $meta.payload.cwd // "")",
  @sh "win=\($tok.payload.info.model_context_window // 0 | floor)",
  @sh "used=\($tok.payload.info.last_token_usage.input_tokens // $tok.payload.info.total_token_usage.input_tokens // 0 | floor)",
  @sh "sandbox=\(if $ctx.payload.sandbox_policy.type != null then "true" else "false" end)",
  @sh "secs=\($elapsed | floor)",
  @sh "quota_used=\($tok.payload.rate_limits.primary.used_percent // 0)"
' "$file" 2>/dev/null)"

[ -z "$model" ] && model="codex"

proj_name=$(basename "$proj" 2>/dev/null)
[ -z "$proj_name" ] && proj_name="~"

case "$effort" in
  low)       eff="lo"  ;;
  medium)    eff="med" ;;
  high)      eff="hi"  ;;
  max|xhigh) eff="max" ;;
  ultra)     eff="max" ;;
  *)         eff=""    ;;
esac

# --- git dalı (kirli işareti) ---
branch=""
if [ -n "$cwd" ] && command -v git >/dev/null 2>&1 && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null \
           || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  [ -n "$branch" ] && [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ] && branch="${branch}*"
fi

# --- araç-özel kuyruk: sandbox + kalan kota ---
DIM='\033[2m'; RST='\033[0m'; YEL='\033[33m'
extra=""
[ "$sandbox" = "true" ] && extra="${DIM}sbx${RST}"

if [ -n "$quota_used" ]; then
  qu_int=$(printf '%s' "$quota_used" | cut -d. -f1)
  case "$qu_int" in ''|*[!0-9]*) qu_int=0 ;; esac
  if [ "$qu_int" -gt 0 ]; then
    rem_pct=$((100 - qu_int))
    [ "$rem_pct" -lt 0 ] && rem_pct=0
    if [ "$rem_pct" -lt 99 ]; then
      wcol="$DIM"; [ "$rem_pct" -lt 20 ] && wcol="$YEL"
      seg="${wcol}wk ${rem_pct}%${RST}"
      [ -n "$extra" ] && extra="${extra} ${seg}" || extra="$seg"
    fi
  fi
fi

export SL_PROJECT="$proj_name"
export SL_BRANCH="$branch"
export SL_MODEL="$model"
export SL_EFFORT="$eff"
export SL_CTX_USED="${used:-0}"
export SL_CTX_WINDOW="${win:-0}"
export SL_CTX_SYS=0
export SL_CTX_MSG=0
export SL_ADDED=0
export SL_REMOVED=0
export SL_DURATION=""          # süre segmenti yok
export SL_COST=""
export SL_EXTRA="$extra"

exec /bin/sh "$CORE"
