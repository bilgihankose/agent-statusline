#!/bin/sh
# Claude Code statusline — session maliyeti + bağlam kırılımı.
# stdin'den JSON alır, terminalde tek satır basar.
# Kurulum: ~/.claude/settings.json -> statusLine.command bu dosyayı çağırır.

LC_ALL=C
export LC_ALL

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0   # jq yoksa sessizce çık

eval "$(printf '%s' "$input" | jq -r '
  @sh "model=\(.model.display_name // "?")",
  @sh "proj=\(.workspace.project_dir // .workspace.current_dir // "")",
  @sh "tpath=\(.transcript_path // "")",
  @sh "cents=\(((.cost.total_cost_usd // 0) * 100) | floor)",
  @sh "added=\(.cost.total_lines_added // 0)",
  @sh "removed=\(.cost.total_lines_removed // 0)",
  @sh "secs=\(((.cost.total_duration_ms // 0) / 1000) | floor)"
')"

proj_name=$(basename "$proj" 2>/dev/null)
[ -z "$proj_name" ] && proj_name="~"

# --- maliyet: cent -> $X.XX ---
dollars=$((cents / 100)); rem=$((cents % 100))
cost_fmt=$(printf '%d.%02d' "$dollars" "$rem")

# --- süre ---
if [ "$secs" -ge 3600 ]; then dur="$((secs / 3600))h$(((secs % 3600) / 60))m"
elif [ "$secs" -ge 60 ]; then dur="$((secs / 60))m"
else dur="${secs}s"; fi

# --- bağlam kırılımı: transcript'teki ilk vs son usage kaydı ---
# ilk asistan turu   ~= sistem promptu + tool tanımları + hafıza + ilk mesaj  (= "sys")
# son tur toplam     ~= güncel bağlamın tamamı
# fark               ~= o günden bu yana biriken konuşma  (= "msg")
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

case "$effort" in
  low) eff="lo" ;; medium) eff="med" ;; high) eff="hi" ;; max|xhigh) eff="max" ;;
  *) eff="" ;;
esac

msg_tok=$((cur_tok - base_tok))
[ "$msg_tok" -lt 0 ] && msg_tok=0

k() { echo $(( ($1 + 500) / 1000 )); }   # en yakın k'ya yuvarla

DIM='\033[2m'; RST='\033[0m'
GRN='\033[32m'; RED='\033[31m'; YEL='\033[33m'
if [ "$cents" -ge 500 ]; then COST_COL="$YEL"; else COST_COL="$GRN"; fi

if [ "$cur_tok" -gt 0 ]; then
  if   [ "$cur_tok" -ge 400000 ]; then TOT_COL="$RED"
  elif [ "$cur_tok" -ge 200000 ]; then TOT_COL="$YEL"
  else TOT_COL="$GRN"; fi
  CTX=" ${DIM}·${RST} ${DIM}sys${RST} $(k "$base_tok")k ${DIM}msg${RST} $(k "$msg_tok")k ${DIM}Σ${RST} ${TOT_COL}$(k "$cur_tok")k${RST}"
else
  CTX=""
fi

[ -n "$eff" ] && MODEL_SEG="${model} ${DIM}${eff}${RST}" || MODEL_SEG="${model}"

printf "%b" "${DIM}${proj_name}${RST} ${DIM}·${RST} ${MODEL_SEG} ${DIM}·${RST} ${COST_COL}\$${cost_fmt}${RST} ${DIM}·${RST} ${GRN}+${added}${RST} ${RED}-${removed}${RST} ${DIM}·${RST} ${DIM}${dur}${RST}${CTX}"
