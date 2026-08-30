#!/bin/sh
# statusline/core.sh — ortak renderer.
#
# Araç-özel adaptörler (claude-code/, agy/) stdin'deki native JSON'u parse eder,
# normalleştirilmiş alanları SL_* ortam değişkenlerine yazar ve bu dosyayı çağırır.
# Bu dosya tek satırı basar. Görünüm tek yerde — yeni bir araç eklendiğinde sadece
# yeni bir adaptör yazılır, buraya dokunulmaz.
#
# Sözleşme: SPEC.md
#
# Girdi (hepsi opsiyonel; boş/0 olan segment atlanır):
#   SL_PROJECT      proje adı (adaptör basename'lemiş olmalı)
#   SL_BRANCH       git dalı; kirliyse sonuna "*" — boşsa segment yok
#   SL_MODEL        model görünen adı
#   SL_EFFORT       normalize reasoning effort: lo | med | hi | max  (ya da boş)
#   SL_CTX_USED     bağlam token (tam sayı); 0 => bağlam segmenti yok
#   SL_CTX_WINDOW   bağlam penceresi (tam sayı); >0 ise yüzde hesaplanır
#   SL_CTX_SYS      opsiyonel kırılım: sistem/taban token
#   SL_CTX_MSG      opsiyonel kırılım: biriken konuşma token
#                   (SYS ve MSG ikisi de >0 ise "sys .. msg .. Σ .." biçimi,
#                    değilse "ctx Σ/pencere %" biçimi)
#   SL_ADDED        eklenen satır (tam sayı)
#   SL_REMOVED      silinen satır (tam sayı)
#   SL_DURATION     önceden biçimlenmiş süre ("2m18s") — boşsa segment yok
#   SL_COST         önceden biçimlenmiş maliyet ("2.34") — boşsa segment yok
#   SL_EXTRA        araç-özel serbest kuyruk (adaptör renklendirmiş olabilir)

LC_ALL=C
export LC_ALL

# --- renkler ---
DIM='\033[2m'; RST='\033[0m'
GRN='\033[32m'; RED='\033[31m'; YEL='\033[33m'

isnum() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
isnum "$SL_CTX_USED"   || SL_CTX_USED=0
isnum "$SL_CTX_WINDOW" || SL_CTX_WINDOW=0
isnum "$SL_CTX_SYS"    || SL_CTX_SYS=0
isnum "$SL_CTX_MSG"    || SL_CTX_MSG=0
isnum "$SL_ADDED"      || SL_ADDED=0
isnum "$SL_REMOVED"    || SL_REMOVED=0

k()  { echo $(( ($1 + 500) / 1000 )); }          # en yakın k
win() {                                           # 200000->200k  1048576->1.0M
  if [ "$1" -ge 1000000 ]; then
    printf '%d.%dM' $(( $1 / 1000000 )) $(( ($1 % 1000000) / 100000 ))
  else
    printf '%dk' "$(k "$1")"
  fi
}

SEP=" ${DIM}·${RST} "
out=""
add() { [ -n "$1" ] && { [ -n "$out" ] && out="${out}${SEP}${1}" || out="$1"; }; }

# 1) proje (+ dal)
proj="${SL_PROJECT:-~}"
if [ -n "$SL_BRANCH" ]; then
  add "${DIM}${proj}${RST} ${DIM}${SL_BRANCH}${RST}"
else
  add "${DIM}${proj}${RST}"
fi

# 2) model (+ effort)
if [ -n "$SL_EFFORT" ]; then
  add "${SL_MODEL} ${DIM}${SL_EFFORT}${RST}"
else
  add "${SL_MODEL}"
fi

# 3) maliyet
if [ -n "$SL_COST" ]; then
  whole=${SL_COST%%.*}
  case "$whole" in ''|*[!0-9]*) whole=0 ;; esac
  [ "$whole" -ge 5 ] && CC="$YEL" || CC="$GRN"
  add "${CC}\$${SL_COST}${RST}"
fi

# 4) satır değişimi
if [ "$SL_ADDED" -gt 0 ] || [ "$SL_REMOVED" -gt 0 ]; then
  add "${GRN}+${SL_ADDED}${RST} ${RED}-${SL_REMOVED}${RST}"
fi

# 5) süre
[ -n "$SL_DURATION" ] && add "${DIM}${SL_DURATION}${RST}"

# 6) bağlam
if [ "$SL_CTX_USED" -gt 0 ]; then
  # renk: pencere biliniyorsa yüzdeye, bilinmiyorsa mutlak eşiğe göre
  col="$GRN"
  if [ "$SL_CTX_WINDOW" -gt 0 ]; then
    pct=$(( SL_CTX_USED * 100 / SL_CTX_WINDOW ))
    if   [ "$pct" -ge 80 ]; then col="$RED"
    elif [ "$pct" -ge 50 ]; then col="$YEL"; fi
  else
    if   [ "$SL_CTX_USED" -ge 400000 ]; then col="$RED"
    elif [ "$SL_CTX_USED" -ge 200000 ]; then col="$YEL"; fi
  fi

  if [ "$SL_CTX_SYS" -gt 0 ] && [ "$SL_CTX_MSG" -gt 0 ]; then
    seg="${DIM}sys${RST} $(k "$SL_CTX_SYS")k ${DIM}msg${RST} $(k "$SL_CTX_MSG")k ${DIM}Σ${RST} ${col}$(k "$SL_CTX_USED")k${RST}"
  else
    seg="${DIM}ctx${RST} ${col}$(k "$SL_CTX_USED")k${RST}"
    [ "$SL_CTX_WINDOW" -gt 0 ] && seg="${seg}${DIM}/$(win "$SL_CTX_WINDOW") ${pct}%${RST}"
  fi
  add "$seg"
fi

# 7) araç-özel kuyruk
add "$SL_EXTRA"

printf "%b" "$out"
