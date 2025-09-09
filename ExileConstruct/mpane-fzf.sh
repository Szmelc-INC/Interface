#!/usr/bin/env bash
# mpane.sh — Multi-pane TUI with fzf
# - Menu left, plain preview right
# - Tab/Space to toggle, Enter runs in order
#
# CONFIG API:
#   add "Title" "Description" "command_to_run" ["preview_command"]
#
# USAGE:
#   ./mpane.sh [config.conf]
# ENV:
#   FZF_HEIGHT   (default 100%)
#   PREVIEW_W    (default 60)
#   RUN_CONFIRM  (default 1)
#   NO_COLOR     (default 0)

set -euo pipefail

# ----- colors -----
if [[ ${NO_COLOR:-0} -eq 1 ]]; then
  bold="" dim="" cyan="" yellow="" green="" red="" reset=""
else
  bold=$'\e[1m'; dim=$'\e[2m'; cyan=$'\e[36m'; yellow=$'\e[33m'
  green=$'\e[32m'; red=$'\e[31m'; reset=$'\e[0m'
fi

# ----- config store (TSV: IDX<TAB>TITLE<TAB>DESC<TAB>CMD<TAB>PV_CMD) -----
ROWS=()
TSV_FILE=""

add() {
  local t="${1:?title}" d="${2:?desc}" c="${3:?cmd}" p="${4-}"
  if [[ "$t$d$c$p" == *$'\t'* ]]; then
    echo "Config error: tabs are forbidden in add();" >&2; exit 2
  fi
  ROWS+=("$t"$'\t'"$d"$'\t'"$c"$'\t'"$p")
}

write_tsv() {
  TSV_FILE="$(mktemp -t mpane.XXXXXX.tsv)"
  local i
  for ((i=0; i<${#ROWS[@]}; i++)); do
    printf '%s\t%s\n' "$i" "${ROWS[i]}" >>"$TSV_FILE"
  done
}

# ----- preview renderer (no boxes, wrapped to FZF_PREVIEW_COLUMNS) -----
preview_mode() {
  local tsv="$1" idx="$2"
  local line
  line=$(awk -v I="$idx" -F'\t' '($1==I){print; exit}' "$tsv") || true
  [[ -z "$line" ]] && { echo "No data."; exit 0; }

  local _title _desc _cmd _pvcmd
  _title=$(printf '%s' "$line" | cut -f2)
  _desc=$( printf '%s' "$line" | cut -f3)
  _cmd=$(  printf '%s' "$line" | cut -f4)
  _pvcmd=$(printf '%s' "$line" | cut -f5)

  local wrap=${FZF_PREVIEW_COLUMNS:-120}
  (( wrap<40 )) && wrap=40

  # Title
  printf '%s\n' "${bold}${_title}${reset}"

  # Description
  printf '\n'
  printf '%s\n' "$_desc" | fold -s -w "$wrap"

  # Optional dynamic preview
  if [[ -n "$_pvcmd" && "$_pvcmd" != ":" && "$_pvcmd" != "-" ]]; then
    printf '\n%s\n' "${dim}Preview:${reset}"
    bash -lc "$_pvcmd" 2>&1 | head -n 200 | fold -s -w "$wrap"
  fi

  # Show command to be run
  printf '\n%s %s\n' "${dim}Command:${reset}" "$_cmd" | fold -s -w "$wrap"
}

# ----- run pipeline -----
run_chain() {
  local tsv="$1"; shift
  local idxs=("$@")
  [[ ${#idxs[@]} -eq 0 ]] && { echo "Nothing selected. Bye."; exit 0; }

  if [[ ${RUN_CONFIRM:-1} -eq 1 ]]; then
    echo
    echo "${bold}Selected to run (in order):${reset}"
    for i in "${idxs[@]}"; do awk -v I="$i" -F'\t' '($1==I){printf " - %s\n",$2}' "$tsv"; done
    read -r -p $'\nProceed? [Y/n] ' ans; ans="${ans:-Y}"
    [[ ! "$ans" =~ ^[Yy]$ ]] && { echo "Cancelled."; exit 1; }
  fi

  for i in "${idxs[@]}"; do
    local title cmd
    title=$(awk -v I="$i" -F'\t' '($1==I){print $2; exit}' "$tsv")
    cmd=$(  awk -v I="$i" -F'\t' '($1==I){print $4; exit}' "$tsv")
    echo
    echo ">>> ${bold}${title}${reset}"
    echo "${dim}\$ ${cmd}${reset}"
    if ! bash -lc "$cmd"; then
      echo "${red}Task failed:${reset} ${title}"
      exit 10
    fi
    echo "${green}OK:${reset} $title"
  done
}

# ----- main UI -----
ui_main() {
  local cfg="${1-}"
  [[ -n "$cfg" ]] && source -- "$cfg"

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
    --preview="bash '$0' --_preview '$TSV_FILE' {1}" \
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

  mapfile -t IDX_ARR < <(printf '%s\n' "$sel" | cut -f1)
  run_chain "$TSV_FILE" "${IDX_ARR[@]}"
  rm -f "$TSV_FILE"
}

# ----- entrypoint switch -----
if [[ "${1-}" == "--_preview" ]]; then shift; preview_mode "$@"; exit 0; fi
ui_main "${1-}"
