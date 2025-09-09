#!/usr/bin/env bash
# pane.sh — dependency-free 2-pane TUI (menu left, preview right)
# Keys: ↑/↓ move • Space/Tab toggle • a/d all/none • e execute • q quit
# API:  add "Title" "Description" "command_to_run" ["preview_cmd"]
# Env:  RUN_CONFIRM=0/1 (default 1)  NO_COLOR=1  DEBUG=1

shopt -s lastpipe

# ----- colors -----
if [[ ${NO_COLOR:-0} -eq 1 ]]; then
  bold="" dim="" yellow="" green="" red="" reset=""
else
  bold=$'\e[1m'; dim=$'\e[2m'; yellow=$'\e[33m'; green=$'\e[32m'; red=$'\e[31m'; reset=$'\e[0m'
fi

# ----- state -----
declare -a T=() D=() C=() P=() S=()
cursor=0; offset=0; W=80; H=24
BOT_CTRL_LINES=2      # bottom help occupies last 2 lines
GAP=1                 # gap between boxes
MIN_L_INNER=12
MIN_R_INNER=24
RUN_CONFIRM="${RUN_CONFIRM:-1}"
BOX_TITLE_LEFT=' ====  M PANEL  ==== '

# ----- config API -----
add(){ local t="${1:?title}" d="${2:?desc}" c="${3:?cmd}" p="${4-}"; T+=("$t"); D+=("$d"); C+=("$c"); P+=("$p"); S+=(0); }
demo_if_empty(){
  (( ${#T[@]} )) && return
  add "Demo: LS" "List files" "ls" "ls"
  add "Demo: Show date"  "Print current date/time"               "date"            "date"
  add "Demo: Uname"      "Kernel and arch info"                  "uname -a"        "uname -a"
}

# ----- ANSI helpers -----
clr(){ printf '\033[2J\033[H'; }
cup(){ printf '\033[%d;%dH' "$(($2+1))" "$(($1+1))"; }
hide_cursor(){ printf '\033[?25l'; }
show_cursor(){ printf '\033[?25h'; }
reset_term(){ printf '\033[0m'; show_cursor; stty echo 2>/dev/null; }
trap 'reset_term' EXIT
rep(){ local ch="$1" n="${2:-0}" pad; ((n<=0)) && return; printf -v pad '%*s' "$n" ''; printf '%s' "${pad// /$ch}"; }
get_wh(){ if rc=$(stty size 2>/dev/null); then H=${rc%% *}; W=${rc##* }; else H=24; W=80; fi; }

# ----- measuring -----
strlen(){ printf '%s' "$1" | wc -c | tr -d ' '; }

measure_left_inner(){
  local first="$1" rows="$2" max=0 i last=$(( first + rows - 1 ))
  (( last > ${#T[@]}-1 )) && last=$(( ${#T[@]}-1 ))
  for (( i=first; i<=last && i>=0; i++ )); do
    local L; L=$(strlen "${T[i]}")
    local n=$(( 2 + 3 + 1 + L ))   # "> " + "[x]" + space + title
    (( n > max )) && max=$n
  done
  (( max < MIN_L_INNER )) && max=$MIN_L_INNER
  echo "$max"
}

measure_right_inner(){
  local idx="$1" max=0 line
  local title_len=$(( 1 + $(strlen "${T[idx]}") ))             # leading space
  (( title_len > max )) && max=$title_len
  while IFS= read -r line; do
    local L=$(( 4 + $(strlen "$line") ))                       # 4-space indent
    (( L > max )) && max=$L
  done <<< "${D[idx]}"
  local lab=$(( 4 + $(strlen "Preview:") ))
  (( lab > max )) && max=$lab
  while IFS= read -r line; do
    local L=$(( 4 + $(strlen "$line") ))
    (( L > max )) && max=$L
  done <<< "${C[idx]}"
  (( max < MIN_R_INNER )) && max=$MIN_R_INNER
  echo "$max"
}

# ----- layout -----
compute_layout(){
  get_wh
  CONTENT_H=$(( H - BOT_CTRL_LINES - 2 ))   # rows inside boxes; -2 for borders
  (( CONTENT_H < 3 )) && CONTENT_H=3

  local li ri; li=$(measure_left_inner "$offset" "$CONTENT_H"); ri=$(measure_right_inner "$cursor")

  local label=" [ ${BOX_TITLE_LEFT} ] "
  local label_need=${#label}
  (( li < label_need )) && li=$label_need

  local L_W=$(( li + 2 ))
  local R_W=$(( ri + 2 ))
  local need=$(( L_W + GAP + R_W ))

  if (( need > W )); then
    local rmin=$(( MIN_R_INNER + 2 ))
    local over=$(( need - W ))
    local rcan=$(( R_W - rmin )); (( rcan < 0 )) && rcan=0
    local take=$(( over<rcan ? over : rcan ))
    R_W=$(( R_W - take )); need=$(( L_W + GAP + R_W ))
  fi
  if (( need > W )); then
    local lmin=$(( (label_need>MIN_L_INNER?label_need:MIN_L_INNER) + 2 ))
    local over=$(( need - W ))
    local lcan=$(( L_W - lmin )); (( lcan < 0 )) && lcan=0
    local take=$(( over<lcan ? over : lcan ))
    L_W=$(( L_W - take )); need=$(( L_W + GAP + R_W ))
  fi

  L_X=0; L_W_FINAL=$L_W
  R_X=$(( L_X + L_W_FINAL + GAP )); R_W_FINAL=$(( W - R_X )); (( R_W_FINAL < 3 )) && R_W_FINAL=3
  BOX_Y=0
  L_INNER_W=$(( L_W_FINAL - 2 ))
  R_INNER_W=$(( R_W_FINAL - 2 ))
}

# ----- drawing helpers -----
row_print(){
  local x="$1" y="$2" width="$3" text="$4"
  cup "$x" "$y"; printf "%-${width}s" ""
  cup "$x" "$y"
  local s="$text"; (( ${#s} > width )) && s="${s:0:width}"
  printf "%s" "$s"
}

draw_box_titled(){ # x y w h title
  local x=$1 y=$2 w=$3 h=$4 title="$5" i
  (( w<2 || h<2 )) && return
  local label=""
  [[ -n "$title" ]] && label=" [ $title ] "
  local mid=$(( w-2 - ${#label} )); (( mid<0 )) && mid=0
  # top
  row_print "$x" "$y" "$w" "┌$(rep '─' $((mid/2)))${label}$(rep '─' $((mid - mid/2)))┐"
  # sides
  for ((i=1;i<=h-2;i++)); do
    row_print "$x" $((y+i)) 1 "│"
    row_print $((x+w-1)) $((y+i)) 1 "│"
  done
  # bottom
  row_print "$x" $((y+h-1)) "$w" "└$(rep '─' $((w-2)))┘"
}

draw_controls_bottom(){
  local line1="${bold} - Space/Tab:${reset}toggle  ${bold}e:${reset}execute  ${bold}a/d:${reset}all/none  ${bold}q:${reset}exit"
  local n=0 i; for ((i=0;i<${#S[@]};i++)); do (( n+=S[i] )); done

  local s1="$line1"; (( ${#s1} > W )) && s1="${s1:0:W}"
  local x1=$(( (W-${#s1})/2 )); (( x1<0 )) && x1=0
  row_print 0 $((H-2)) "$W" ""
  cup "$x1" $((H-2)); printf "%s" "$s1"

  local s2="$line2"; (( ${#s2} > W )) && s2="${s2:0:W}"
  local x2=$(( (W-${#s2})/2 )); (( x2<0 )) && x2=0
  row_print 0 $((H-1)) "$W" ""
  cup "$x2" $((H-1)); printf "%s" "$s2"
}

draw_list(){
  local first="$1" sel="$2" row inner_w=$L_INNER_W
  (( inner_w<1 )) && inner_w=1
  local x=$((L_X+1)) y=$((BOX_Y+1))
  for (( row=0; row<CONTENT_H; row++ )); do
    local idx=$(( first + row ))
    row_print "$x" $(( y + row )) "$inner_w" ""
    if (( idx < ${#T[@]} )); then
      local mark; (( idx==sel )) && mark="> " || mark="  "
      local raw_box; (( S[idx]==1 )) && raw_box="[x]" || raw_box="[ ]"
      local head_raw="${mark}${raw_box} "
      local usable=$(( inner_w - ${#head_raw} )); (( usable<0 )) && usable=0
      local shown; shown="$(printf '%s' "${T[idx]}" | cut -c1-"$usable")"
      local box_disp="$raw_box"; (( S[idx]==1 )) && box_disp="[$yellow""x$reset]"
      local head_disp="${mark}${box_disp} "
      row_print "$x" $(( y + row )) "$inner_w" "${head_disp}${shown}"
    fi
  done
}

# ---- RIGHT PANE RENDER (no overflow, manual wrap with 4-space indent) ----
IND="    "; INDW=4

_wrap_emit_lines(){ # $1=text, $2=cw -> wrapped lines to stdout
  local text="$1" cw="$2" line="" word
  [[ -z "$text" ]] && { printf '\n'; return; }
  for word in $text; do
    if [[ -z "$line" ]]; then
      line="$word"
    else
      local cand="$line $word"
      if (( ${#cand} <= cw )); then
        line="$cand"
      else
        printf '%s\n' "$line"
        line="$word"
      fi
    fi
  done
  [[ -n "$line" ]] && printf '%s\n' "$line"
}

_wrap_block(){ # $1=multiline text, $2=cw -> prints wrapped lines
  local txt="$1" cw="$2" l
  while IFS= read -r l || [[ -n "$l" ]]; do
    _wrap_emit_lines "$l" "$cw"
  done <<< "$txt"
}

draw_preview(){
  local idx="$1"
  local x=$(( R_X+1 ))
  local y=$(( BOX_Y+1 ))
  local width=$R_INNER_W
  (( width<1 )) && width=1

  # clear full inner area
  local r; for (( r=0; r<CONTENT_H; r++ )); do row_print "$x" $(( y + r )) "$width" ""; done

  # title
  row_print "$x" "$y" "$width" " ${bold}${T[idx]}${reset}"; (( y++ ))

  # content width after indent
  local cw=$(( width - INDW )); (( cw<1 )) && cw=1

  # description
  _wrap_block "${D[idx]}" "$cw" | while IFS= read -r l; do
    (( y > BOX_Y + CONTENT_H )) && break
    row_print "$x" "$y" "$width" "${IND}${l}"; (( y++ ))
  done

  # preview
  if [[ -n "${P[idx]}" && "${P[idx]}" != ":" && "${P[idx]}" != "-" && $y -le $((BOX_Y + CONTENT_H)) ]]; then
    (( y <= BOX_Y + CONTENT_H )) && { row_print "$x" "$y" "$width" ""; (( y++ )); }
    (( y <= BOX_Y + CONTENT_H )) && { row_print "$x" "$y" "$width" "${IND}${dim}Preview:${reset}"; (( y++ )); }
    local pv; pv="$(bash -lc "${P[idx]}" 2>&1 | head -n 200)" || true
    [[ -z "$pv" ]] && pv="[no preview output]"
    _wrap_block "$pv" "$cw" | while IFS= read -r l; do
      (( y > BOX_Y + CONTENT_H )) && break
      row_print "$x" "$y" "$width" "${IND}${l}"; (( y++ ))
    done
  fi

  # command
  if (( y <= BOX_Y + CONTENT_H )); then
    row_print "$x" "$y" "$width" ""; (( y++ ))
    (( y <= BOX_Y + CONTENT_H )) && { row_print "$x" "$y" "$width" "${IND}${dim}Command:${reset}"; (( y++ )); }
    _wrap_block "${C[idx]}" "$cw" | while IFS= read -r l; do
      (( y > BOX_Y + CONTENT_H )) && break
      row_print "$x" "$y" "$width" "${IND}${l}"; (( y++ ))
    done
  fi
}

draw_all(){
  clr
  compute_layout
  draw_box_titled "$L_X" "$BOX_Y" "$((L_INNER_W+2))" "$((CONTENT_H+2))" "$BOX_TITLE_LEFT"
  draw_box_titled "$((L_X+L_INNER_W+2+GAP))" "$BOX_Y" "$((R_INNER_W+2))" "$((CONTENT_H+2))" ""
  draw_list "$offset" "$cursor"
  draw_preview "$cursor"
  draw_controls_bottom
}

# ----- key reader -----
read_key(){
  local k rest seq=""
  IFS= read -rsn1 k || return 1
  [[ $k == 'e' ]] && { echo EXEC; return; }
  [[ $k == $'\n' || $k == $'\r' ]] && { echo EXEC; return; }
  if [[ $k == $'\e' ]]; then
    local more; while IFS= read -rsn1 -t 0.01 more; do seq+="$more"; done
    case "$seq" in
      "[A") echo UP;;
      "[B") echo DN;;
      "[C") echo RT;;
      "[D") echo LT;;
      "OM"|"[M"|"[13~"|"[E") echo EXEC;;
      *) echo "";;
    esac
  else
    case "$k" in
      ' ') echo TOGGLE;;
      $'\t') echo TOGGLE;;
      'a') echo ALL;;
      'd') echo NONE;;
      'q') echo QUIT;;
      *) echo "";;
    esac
  fi
}

# ----- run -----
run_selected(){
  local idxs=() i
  for (( i=0; i<${#T[@]}; i++ )); do (( S[i]==1 )) && idxs+=("$i"); done
  (( ${#idxs[@]} == 0 )) && idxs=("$cursor")

  if [[ "$RUN_CONFIRM" == "1" ]]; then
    show_cursor; stty echo 2>/dev/null
    echo; echo "${bold}Selected to run (in order):${reset}"
    for i in "${idxs[@]}"; do echo " - ${T[i]}"; done
    read -r -p $'\nProceed? [Y/n] ' ans; ans="${ans:-Y}"
    hide_cursor; stty -echo 2>/dev/null
    [[ ! "$ans" =~ ^[Yy]$ ]] && { echo "Cancelled."; return; }
  fi

  reset_term; echo
  for i in "${idxs[@]}"; do
    echo ">>> ${bold}${T[i]}${reset}"
    echo "${dim}\$ ${C[i]}${reset}"
    if ! bash -lc "${C[i]}"; then echo "${red}Task failed:${reset} ${T[i]}"; exit 10; fi
    echo "${green}OK:${reset} ${T[i]}"; echo
  done
  exit 0
}

ensure_visible(){
  (( cursor<0 )) && cursor=0
  (( cursor>${#T[@]}-1 )) && cursor=$(( ${#T[@]}-1 ))
  if (( cursor<offset )); then offset=$cursor
  elif (( cursor>=offset+CONTENT_H )); then offset=$(( cursor - CONTENT_H + 1 )); fi
  (( offset<0 )) && offset=0
}

main(){
  local cfg="${1-}"
  [[ -n "$cfg" ]] && source -- "$cfg" || true
  demo_if_empty
  stty -echo 2>/dev/null || true
  hide_cursor
  draw_all
  trap 'draw_all' SIGWINCH
  while :; do
    case "$(read_key)" in
      UP) ((cursor--)); ensure_visible; draw_all ;;
      DN) ((cursor++)); ensure_visible; draw_all ;;
      TOGGLE) S[cursor]=$((1-${S[cursor]})); draw_all ;;
      ALL) for ((i=0;i<${#S[@]}; i++)); do S[i]=1; done; draw_all ;;
      NONE) for ((i=0;i<${#S[@]}; i++)); do S[i]=0; done; draw_all ;;
      EXEC) run_selected ;;
      QUIT) break ;;
      *) : ;;
    esac
  done
}

main "${1-}"
