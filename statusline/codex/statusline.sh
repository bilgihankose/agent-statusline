#!/bin/sh
# Codex statusline adaptörü.
# Codex'in yerleşik statusline hook'u olmadığı için bu adaptör:
#   1) Argüman olarak rollout dosyası verilirse ($1) onu okur,
#   2) Argüman yoksa ~/.codex/sessions/ altındaki en son oturumu otomatik bulup okur.
#
# Çıktı: SL_* değişkenleri üzerinden shared core.sh renderer'ı çağırır.
#
# Kullanım:
#   - Standalone / tmux: /bin/sh /path/to/agent-cli-tools/statusline/codex/statusline.sh
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
  (map(select(.type == "event_msg" and .payload.type == "token_count"))) as $toks |
  ($toks | last_val(.)) as $tok |
  (if ($toks | length) > 0 then $toks[0] else null end) as $tok0 |

  @sh "model=\($ctx.payload.model // "codex")",
  @sh "effort=\($ctx.payload.effort // $ctx.payload.collaboration_mode.settings.reasoning_effort // "")",
  @sh "proj=\($ctx.payload.cwd // $meta.payload.cwd // "")",
  @sh "cwd=\($ctx.payload.cwd // $meta.payload.cwd // "")",
  @sh "win=\($tok.payload.info.model_context_window // 0 | floor)",
  @sh "used=\($tok.payload.info.last_token_usage.input_tokens // $tok.payload.info.total_token_usage.input_tokens // 0 | floor)",
  @sh "base=\($tok0.payload.info.last_token_usage.input_tokens // 0 | floor)"
' "$file" 2>/dev/null)"

[ -z "$model" ] && model="codex"

proj_name=$(basename "$proj" 2>/dev/null)
[ -z "$proj_name" ] && proj_name="~"

# --- sys/msg kırılımı ---
# ilk token_count kaydı ~= sistem promptu + tool tanımları + ilk mesaj  (= "sys")
# son kayıt          ~= güncel bağlamın tamamı  (= "Σ")
# fark               ~= biriken konuşma  (= "msg")
# tek kayıt varsa (yeni oturum) msg=0 -> core sade "ctx N/W %" biçimine düşer
case "$base" in ''|*[!0-9]*) base=0 ;; esac
case "$used" in ''|*[!0-9]*) used=0 ;; esac
msg=$((used - base)); [ "$msg" -lt 0 ] && msg=0
[ "$base" -gt "$used" ] && base=0

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

export SL_PROJECT="$proj_name"
export SL_BRANCH="$branch"
export SL_MODEL="$model"
export SL_EFFORT="$eff"
export SL_CTX_USED="${used:-0}"
export SL_CTX_WINDOW="${win:-0}"
export SL_CTX_SYS="$base"
export SL_CTX_MSG="$msg"
export SL_ADDED=0
export SL_REMOVED=0
export SL_DURATION=""          # süre segmenti yok
export SL_COST=""
export SL_EXTRA=""             # sbx/kota kuyruğu kaldırıldı — üç adaptör aynı biçim

exec /bin/sh "$CORE"
