#!/usr/bin/env zsh
# mpane.zsh — Multi-pane TUI with fzf (zsh only)
# - Menu left, plain preview right
# - Tab/Space to toggle, Enter runs in order
#
# CONFIG API:
#   add "Title" "Description" "command_to_run" "preview_command"
#
# USAGE:
#   ./mpane.zsh [config.conf]
# ENV:
#   FZF_HEIGHT   (default 100%)
#   PREVIEW_W    (default 60)
#   RUN_CONFIRM  (default 1)
#   NO_COLOR     (default 0)

emulate -L zsh
setopt errexit nounset pipefail

# ----- script path -----
# ${0:A} = absolute path of script; :h = dirname
typeset -g SCRIPT_PATH="${0:A}"
typeset -g SCRIPT_DIR="${SCRIPT_PATH:h}"

# ----- colors -----
if [[ ${NO_COLOR:-0} -eq 1 ]]; then
  bold="" dim="" cyan="" yellow="" green="" red="" reset=""
else
  bold=$'\e[1m'; dim=$'\e[2m'; cyan=$'\e[36m'; yellow=$'\e[33m'
  green=$'\e[32m'; red=$'\e[31m'; reset=$'\e[0m'
fi

# ----- config store (TSV: IDX<TAB>TITLE<TAB>DESC<TAB>CMD<TAB>PV_CMD) -----
typeset -ga ROWS
ROWS=()
TSV_FILE=""

add() {
  local t="${1:?title}" d="${2:?desc}" c="${3:?cmd}" p="${4-}"
  if [[ "$t$d$c$p" == *$'\t'* ]]; then
    print -u2 "Config error: tabs are forbidden in add();"
    exit 2
  fi
  ROWS+=("$t"$'\t'"$d"$'\t'"$c"$'\t'"$p")
}

write_tsv() {
  TSV_FILE="$(mktemp -t mpane.XXXXXX.tsv)"
  local i
  for (( i = 1; i <= ${#ROWS}; i++ )); do
    printf '%s\t%s\n' "$((i-1))" "$ROWS[i]" >>"$TSV_FILE"
  done
}

# ----- preview renderer (no boxes, wrapped to FZF_PREVIEW_COLUMNS) -----
preview_mode() {
  local tsv="$1" idx="$2"
  local line
  line=$(awk -v I="$idx" -F'\t' '($1==I){print; exit}' "$tsv") || true
  [[ -z "$line" ]] && { print "No data."; exit 0; }

  local _title _desc _cmd _pvcmd
  _title=$(printf '%s' "$line" | cut -f2)
  _desc=$( printf '%s' "$line" | cut -f3)
  _cmd=$(  printf '%s' "$line" | cut -f4)
  _pvcmd=$(printf '%s' "$line" | cut -f5)

  local wrap=${FZF_PREVIEW_COLUMNS:-120}
  (( wrap < 40 )) && wrap=40

  # Title
  printf '%s\n' "${bold}${_title}${reset}"

  # Description
  printf '\n'
  printf '%s\n' "$_desc" | fold -s -w "$wrap"

  # Optional dynamic preview
  if [[ -n "$_pvcmd" && "$_pvcmd" != ":" && "$_pvcmd" != "-" ]]; then
    printf '\n%s\n' "${dim}Preview:${reset}"
    zsh -c "$_pvcmd" 2>&1 | head -n 200 | fold -s -w "$wrap"
  fi

  # Show command to be run
  printf '\n%s %s\n' "${dim}Command:${reset}" "$_cmd" | fold -s -w "$wrap"
}

# ----- run pipeline -----
run_chain() {
  local tsv="$1"; shift
  typeset -a idxs
  idxs=("$@")

  [[ ${#idxs[@]} -eq 0 ]] && { print "Nothing selected. Bye."; exit 0; }

  if [[ ${RUN_CONFIRM:-1} -eq 1 ]]; then
    print
    print "${bold}Selected to run (in order):${reset}"
    local i
    for i in "${idxs[@]}"; do
      awk -v I="$i" -F'\t' '($1==I){printf " - %s\n",$2}' "$tsv"
    done
    local ans
    printf '\nProceed? [Y/n] '
    IFS= read -r ans || ans=""
    ans="${ans:-Y}"
    if ! [[ "$ans" =~ ^[Yy]$ ]]; then
      print "Cancelled."
      exit 1
    fi
  fi

  local i title cmd
  for i in "${idxs[@]}"; do
    title=$(awk -v I="$i" -F'\t' '($1==I){print $2; exit}' "$tsv")
    cmd=$(  awk -v I="$i" -F'\t' '($1==I){print $4; exit}' "$tsv")
    print
    print ">>> ${bold}${title}${reset}"
    print "${dim}\$ ${cmd}${reset}"
    if ! zsh -c "$cmd"; then
      print "${red}Task failed:${reset} ${title}"
      exit 10
    fi
    print "${green}OK:${reset} $title"
  done
}

# ----- main UI -----
ui_main() {
  local cfg="${1-}"

  # Optional config
  if [[ -n "$cfg" ]]; then
    local try1="$cfg"
    local try2="${SCRIPT_DIR}/${cfg}"
    if [[ -r "$try1" ]]; then
      source "$try1"
    elif [[ -r "$try2" ]]; then
      source "$try2"
    else
      print -u2 "Config not readable: $cfg"
      exit 1
    fi
  fi

  # Fallback demo if config did not call add()
  if [[ ${#ROWS[@]} -eq 0 ]]; then
    add "Demo: Echo hello" "Minimal example that just echos hello" "echo hello world" ":"
    add "Demo: Show date"  "Print current date/time"               "date"            ":"
  fi

  write_tsv
  local height="${FZF_HEIGHT:-100%}"
  local pw="${PREVIEW_W:-60}"

  local sel
  sel=$(fzf \
    --ansi --multi --no-mouse \
    --height="$height" \
    --border=rounded \
    --delimiter=$'\t' --with-nth=2 \
    --preview="zsh '$SCRIPT_PATH' --_preview '$TSV_FILE' {1}" \
    --preview-window="right:${pw}%:wrap" \
    --disabled \
    --prompt='' \
    --no-separator \
    --no-info \
    --bind 'space:toggle' \
    --bind 'tab:toggle+down,shift-tab:toggle+up' \
    --bind 'ctrl-a:select-all,ctrl-d:deselect-all' \
    --header $'Space/TAB: select • Enter: run • Ctrl-A: all • Ctrl-D: none' \
    < "$TSV_FILE") || { rm -f "$TSV_FILE"; exit 130; }

  # Split selected lines into array of indices (1st field of TSV)
  typeset -a IDX_ARR
  IDX_ARR=("${(@f)$(printf '%s\n' "$sel" | cut -f1)}")

  run_chain "$TSV_FILE" "${IDX_ARR[@]}"
  rm -f "$TSV_FILE"
}

# ----- entrypoint switch -----
if [[ "${1-}" == "--_preview" ]]; then
  shift
  preview_mode "$@"
  exit 0
fi

ui_main "${1-}"
