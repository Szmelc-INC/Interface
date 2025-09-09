#!/usr/bin/env bash
# tui-mixer (value bars) — boxed UI edition (no deps, fixed padding)
# - Up/Down: select bar
# - Left/Right (or h/l): decrease/increase by step
# - q / ESC: quit (prints final values if PRINT=1)
#
# Config: provide a Bash file that calls add "Title" MIN MAX STEP [INIT] [STEPUP_CMD] [STEPDOWN_CMD]
# Example config (save as mixer.conf):
#   add "Master" 0 100 5 50 "wpctl set-volume @DEFAULT_SINK@ ${VB_VAL}%" "wpctl set-volume @DEFAULT_SINK@ ${VB_VAL}%"
#   add "Bass"   -20 20 1 0  ":" ":"
#   add "Mic"     0 150 5 80 "pactl set-source-volume @DEFAULT_SOURCE@ ${VB_VAL}%" "pactl set-source-volume @DEFAULT_SOURCE@ ${VB_VAL}%"
#
# Usage:
#   ./bar.sh [config.sh]
#   PRINT=1 ./bar.sh [config.sh]    # print NAME=VALUE lines on exit

shopt -s lastpipe

# arrays (short names)
declare -a t a b s v u d

# add one bar: add "Title" MIN MAX STEP [INIT] [UPCMD] [DNCMD]
add(){
  local _t="$1" _a="$2" _b="$3" _s="$4" _v _u _d
  _v="${5:-$2}"; _u="${6-}"; _d="${7-}"
  t+=("$_t"); a+=($_a); b+=($_b); s+=($_s); v+=($_v); u+=("${_u}"); d+=("${_d}")
}

# config
[[ -n "${1-}" ]] && source -- "$1"

# tiny demo if none supplied
if [[ ${#t[@]} -eq 0 ]]; then
  add "Master" 0 100 5 50 "echo up:$VB_TITLE=$VB_VAL" "echo dn:$VB_TITLE=$VB_VAL"
  add "Lows"  -20  20 1  0  ":" ":"
  add "Highs" -20  20 2  0  ":" ":"
fi

# term/ui
W=${W:-$(tput cols 2>/dev/null || echo 80)}
H=${H:-$(tput lines 2>/dev/null || echo 24)}
BW=${BW:-40}        # bar width (chars)
HD=${HD:-"TUI Mixer"}
PRINT=${PRINT:-0}

# simple colors (optional)
bold=$'\e[1m'; cyan=$'\e[36m'; reset=$'\e[0m'

rep(){ local ch="$1" n=$2; (( n<0 )) && n=0; printf "%*s" "$n" "" | tr ' ' "$ch"; }
clamp(){ local x=$1 lo=$2 hi=$3; (( x<lo )) && x=$lo; (( x>hi )) && x=$hi; echo "$x"; }
ratio(){ local num=$1 den=$2 div=$3; (( div==0 )) && { echo 0; return; }; echo $(( (num*den + div/2) / div )); }

cleanup(){ tput cnorm 2>/dev/null; tput rmcup 2>/dev/null; stty echo 2>/dev/null; (( PRINT==1 )) && dump_vals; }
trap cleanup EXIT

resize(){ W=$(tput cols 2>/dev/null || echo 80); H=$(tput lines 2>/dev/null || echo 24); draw; }
trap resize SIGWINCH

enter_alt(){ tput smcup 2>/dev/null; tput civis 2>/dev/null; stty -echo 2>/dev/null; }

clear_scr(){ tput clear 2>/dev/null || printf "\033c"; }

dump_vals(){ local i; for (( i=0; i<${#t[@]}; i++ )); do printf '%s=%s\n' "${t[i]// /_}" "${v[i]}"; done; }

# ----- rendering helpers (boxed UI) -----

# produce bar visualization line (no ANSI), title padded to 16 chars inside quotes
barline_str(){ # idx -> string
  local i=$1 title="${t[i]}" lo=${a[i]} hi=${b[i]} cur=${v[i]}
  local rng=$(( hi-lo )); (( rng<=0 )) && rng=1
  local pos=$(( cur-lo ))
  local fill; fill=$(ratio "$pos" "$BW" "$rng"); (( fill<0 )) && fill=0; (( fill>BW )) && fill=$BW
  local filled empty; filled=$(rep "#" "$fill"); empty=$(rep "-" $(( BW-fill )))
  printf ' "%-16s" [%s%s] %6d (%d..%d step:%d)' "$title" "$filled" "$empty" "$cur" "$lo" "$hi" "${s[i]}"
}

# compute interior width needed to fit all rows (no borders), then box params
compute_layout(){
  local i line len maxlen=0
  for (( i=0; i<${#t[@]}; i++ )); do
    line=$(barline_str "$i")
    len=${#line}
    (( len>maxlen )) && maxlen=$len
  done
  # room for leading space + 2-char cursor marker ("> ") => +3
  LINE_LEN=$(( maxlen + 3 ))
  (( LINE_LEN > W-6 )) && LINE_LEN=$(( W-6 ))  # keep at least 3 chars margin each side
  (( LINE_LEN < 10 )) && LINE_LEN=10
  BOX_WIDTH=$(( LINE_LEN + 2 ))        # borders add 2
  PADDING=$(( (W - BOX_WIDTH) / 2 ))
  (( PADDING < 0 )) && PADDING=0
}

draw_title_box(){
  local title="[$HD]"
  local tlen=${#title}
  local inner=$LINE_LEN
  local leftpad=$PADDING

  # top
  printf "%*s┌" "$leftpad" ""
  printf '─%.0s' $(seq 1 "$inner")
  printf "┐\n"
  # centered title (we center based on raw title length; ANSI applied only in payload)
  local lpad=$(( (inner - tlen) / 2 ))
  (( lpad<0 )) && lpad=0
  printf "%*s│" "$leftpad" ""
  printf "%*s%s%*s" "$lpad" "" "$bold$title$reset" "$((inner - lpad - tlen))" ""
  printf "│\n"
  # bottom
  printf "%*s└" "$leftpad" ""
  printf '─%.0s' $(seq 1 "$inner")
  printf "┘\n"
}

draw_menu_box(){
  local leftpad=$PADDING inner=$LINE_LEN
  # top
  printf "%*s┌" "$leftpad" ""
  printf '─%.0s' $(seq 1 "$inner")
  printf "┐\n"

  local i line trimmed marker_raw marker_disp row_raw row_disp vlen pad
  for (( i=0; i<${#t[@]}; i++ )); do
    # raw marker used for width math; disp marker may add ANSI
    marker_raw="  "
    marker_disp="  "
    if [[ $i -eq $sel ]]; then
      marker_raw="> "
      marker_disp="${cyan}> ${reset}"
    fi

    line=$(barline_str "$i")

    # trim content if needed (content has no ANSI)
    if (( ${#line} > inner-3 )); then   # -3 accounts for leading space + marker
      trimmed="${line:0:inner-6}..."
    else
      trimmed="$line"
    fi

    # build raw vs display rows
    row_raw=" ${marker_raw}${trimmed}"
    row_disp=" ${marker_disp}${trimmed}"

    # visible length equals raw length (since raw has no ANSI)
    vlen=${#row_raw}
    pad=$(( inner - vlen ))
    (( pad < 0 )) && pad=0

    printf "%*s│" "$leftpad" ""
    printf "%s%*s" "$row_disp" "$pad" ""
    printf "│\n"
  done

  # bottom
  printf "%*s└" "$leftpad" ""
  printf '─%.0s' $(seq 1 "$inner")
  printf "┘\n"
}

hint(){
  local leftpad=$PADDING
  printf "\n"
  printf "%*s%s\n" "$leftpad" "" "  ↑/↓ select   ←/→ adjust   q to quit"
}

draw(){
  clear_scr
  compute_layout
  printf "\n\n"
  draw_title_box
  draw_menu_box
  hint
}

# ----- logic -----

sel=0

run_cmd(){ # dir: +1 or -1
  local dir=$1 i=$sel
  local prev=${v[i]} cur=${v[i]} lo=${a[i]} hi=${b[i]} st=${s[i]}
  (( dir>0 )) && cur=$(( cur+st )) || cur=$(( cur-st ))
  cur=$(clamp "$cur" "$lo" "$hi")
  v[i]=$cur
  export VB_IDX=$i VB_TITLE="${t[i]}" VB_MIN=$lo VB_MAX=$hi VB_STEP=$st VB_PREV=$prev VB_VAL=$cur
  local cmd; if (( dir>0 )); then cmd=${u[i]}; else cmd=${d[i]}; fi
  if [[ -n "$cmd" && "$cmd" != ":" && "$cmd" != "-" ]]; then ( set +e; bash -lc "$cmd" ); fi
}

read_key(){
  local k
  IFS= read -rsn1 k || return 1
  if [[ $k == $'\e' ]]; then
    IFS= read -rsn1 -t 0.01 k || { echo ESC; return; }
    if [[ $k == "[" ]]; then IFS= read -rsn1 -t 0.01 k; fi
    case "$k" in A) echo UP;; B) echo DN;; C) echo RT;; D) echo LT;; *) echo ESC;; esac
  else
    case "$k" in q) echo QUIT;; h) echo LT;; l) echo RT;; j) echo DN;; k) echo UP;; *) echo "";; esac
  fi
}

main(){
  enter_alt
  draw
  while true; do
    case "$(read_key)" in
      UP) (( sel>0 )) && ((sel--)); draw ;;
      DN) (( sel<${#t[@]}-1 )) && ((sel++)); draw ;;
      RT) run_cmd +1; draw ;;
      LT) run_cmd -1; draw ;;
      QUIT|ESC) break ;;
    esac
  done
}

main "$@"
