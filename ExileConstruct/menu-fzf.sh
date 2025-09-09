#!/usr/bin/env zsh
# menu-fzf.zsh — bordered fzf TUI with config support
# - If --config/-c is provided, ONLY entries from that file are used.

set -u
set -o pipefail

command -v fzf >/dev/null 2>&1 || { print -u2 "fzf not found"; exit 1; }

# -------------------- defaults / CLI flags --------------------
TITLE="TUI MENU"
BINDS="Space/Tab: toggle • Enter: confirm • q/C-c: abort"
CONFIG_FILE=""           # if set, built-ins are ignored

print_help() {
  cat <<'USAGE'
menu-fzf.zsh — entries-based TUI (fzf)

Usage:
  menu-fzf.zsh [options]

Options:
  -c, --config FILE   Load entries from FILE (ENTRY blocks). When provided,
                      built-in entries in the script are *ignored*.
                      Use "-" to read the config from stdin.
  --title TEXT        Set top border title (default: "TUI MENU")
  --binds TEXT        Set bottom binds text (default shown above)
  -h, --help          Show this help and exit

Config file format (zsh):
  ENTRY "Title" <<EOF
  Description line
  preview_command
  run_command
  EOF
USAGE
}

# arg parsing
while (( $# )); do
  case "$1" in
    -c|--config)
      (( $# >= 2 )) || { print -u2 "error: --config needs a file"; exit 2; }
      CONFIG_FILE="$2"; shift 2;;
    --title)
      (( $# >= 2 )) || { print -u2 "error: --title needs a string"; exit 2; }
      TITLE="$2"; shift 2;;
    --binds)
      (( $# >= 2 )) || { print -u2 "error: --binds needs a string"; exit 2; }
      BINDS="$2"; shift 2;;
    -h|--help)
      print_help; exit 0;;
    --) shift; break;;
    -*)
      print -u2 "unknown option: $1"; print_help; exit 2;;
    *) break;;
  esac
done

# -------------------- entries API --------------------
typeset -a ENTRIES

ENTRY() {
  local title="$1"
  local desc preview run
  IFS= read -r desc
  IFS= read -r preview
  IFS= read -r run
  ENTRIES+=("$title"$'\t'"$desc"$'\t'"$preview"$'\t'"$run")
}

# -------------------- load entries --------------------
if [[ -n "$CONFIG_FILE" ]]; then
  # Config provided → ignore built-ins entirely
  if [[ "$CONFIG_FILE" == "-" ]]; then
    cfg_tmp=$(mktemp) || { print -u2 "mktemp failed"; exit 1; }
    cat > "$cfg_tmp"
    source "$cfg_tmp"
    rm -f "$cfg_tmp"
  else
    [[ -r "$CONFIG_FILE" ]] || { print -u2 "config not readable: $CONFIG_FILE"; exit 2; }
    source "$CONFIG_FILE"
  fi
else
  # Built-in defaults (used only when no --config given)
  ENTRY "Uname" <<EOF
Kernel and arch information
uname -a
uname -a
EOF

  ENTRY "Date" <<EOF
Current system date/time (RFC 2822)
date -R
date -R
EOF

  ENTRY "Disk Usage" <<EOF
df -h for mounted filesystems
df -h
df -h
EOF

  ENTRY "Memory" <<EOF
free -h snapshot
free -h
free -h
EOF

  ENTRY "Top Processes" <<EOF
ps sorted by CPU
ps -eo pid,ppid,comm,pcpu,pmem --sort=-pcpu | head -n 20
ps -eo pid,ppid,comm,pcpu,pmem --sort=-pcpu | head -n 20
EOF

  ENTRY "Kernel Modules" <<EOF
lsmod summary
lsmod | head -n 40
lsmod
EOF
fi

(( ${#ENTRIES[@]} > 0 )) || { print -u2 "no entries loaded"; exit 3; }

# -------------------- TSV for fzf --------------------
tsv=$(mktemp) || { print -u2 "mktemp failed"; exit 1; }
{
  typeset -i i=0
  for line in "${ENTRIES[@]}"; do
    ((i++))
    printf "%d\t%s\n" "$i" "$line"
  done
} > "$tsv"

# -------------------- preview script (box-drawing bars, no brackets) --------------------
preview_sh=$(mktemp) || { print -u2 "mktemp failed"; exit 1; }
cat >"$preview_sh" <<'ZSH'
#!/usr/bin/env zsh
set -u
set -o pipefail
file="$1"; idx="$2"

typeset -a fields
while IFS=$'\t' read -r i t d p r; do
  [[ "$i" == "$idx" ]] || continue
  fields=("$i" "$t" "$d" "$p" "$r")
  break
done < "$file"

title="${fields[2]:-Item}"
desc="${fields[3]:-}"
pcmd="${fields[4]:-echo no-cmd}"

cols=${FZF_PREVIEW_COLUMNS:-80}
lines=${FZF_PREVIEW_LINES:-24}
(( cols < 20 )) && cols=20
(( lines < 8 )) && lines=8

B=$'\e[1m'; R=$'\e[0m'
CYAN=$'\e[36m'
ORANGE=$'\e[38;5;208m'
GREEN=$'\e[32m'

H=$'─'       # U+2500
TEE_L=$'├'   # U+251C
TEE_R=$'┤'   # U+2524

hr() { local n=$1 out=""; while (( n-- > 0 )); do out+="$H"; done; printf "%s" "$out"; }
bar() {
  # centered bar: ───┤ Info ├───  (no brackets)
  local label="$1" color="$2"
  local plain="$TEE_R ${label} $TEE_L"             # width w/o ANSI
  local colored="$TEE_R ${color}${label}${R} $TEE_L"
  local L=$(( (cols - ${#plain}) / 2 )); (( L < 0 )) && L=0
  local Rpad=$(( cols - L - ${#plain} )); (( Rpad < 0 )) && Rpad=0
  hr "$L"; printf "%s" "$colored"; hr "$Rpad"; printf "\n"
}

bar "Info" "$ORANGE"
print -r -- "${B}${CYAN}${title}${R}"
print -r -- "$desc" | fold -s -w "$cols"
printf "\n"

bar "Preview" "$GREEN"
{
  eval "$pcmd" 2>&1 \
  | head -n $((lines - 6)) \
  | cut -c1-"$cols"
} || true
ZSH
chmod +x "$preview_sh"

# -------------------- Run fzf --------------------
set +e
selection="$(
  {
    # Fake footer line (kept at bottom via --header-lines with --layout=reverse)
    echo "===FOOTER=== $BINDS"
    cat "$tsv"
  } | \
  fzf --ansi --multi --height=100% --layout=reverse \
      --delimiter=$'\t' --with-nth=2 \
      --preview "$preview_sh $tsv {1}" \
      --preview-window=right,70%,wrap,border-left \
      --marker='x' --pointer='▶ ' --prompt='Select > ' \
      --bind 'space:toggle,tab:toggle,q:abort' \
      --border --border-label=" $TITLE " --border-label-pos=top \
      --padding=1,2 \
      --header-lines=1 --header-first
)"
fzf_rc=$?
set -e

rm -f "$preview_sh"

if (( fzf_rc != 0 )); then
  rm -f "$tsv"; exit $fzf_rc
fi

# Strip the fake footer row if selected accidentally
selection="$(print -r -- "$selection" | grep -v '^===FOOTER===')"

if [[ -z "${selection// }" ]]; then
  print "No selections."
  rm -f "$tsv"
  exit 0
fi

# -------------------- Parse & execute --------------------
typeset -a RUN_TITLES RUN_CMDS
while IFS=$'\t' read -r i t d p r; do
  [[ -z "${i:-}" ]] && continue
  RUN_TITLES+=("$t")
  RUN_CMDS+=("$r")
done <<< "$selection"

print
print -P "%F{cyan}%BAbout to execute ${#RUN_TITLES[@]} selection(s) in order:%b%f"
print "------------------------------------------------------------"
for i in {1..${#RUN_TITLES[@]}}; do
  printf "%2d) %s\n    → %s\n" "$i" "$RUN_TITLES[$i]" "$RUN_CMDS[$i]"
done
print "------------------------------------------------------------"
print -n "Proceed? [Y/n] "
read -rk 1 reply || reply=""
print

if [[ -n "$reply" && "$reply" != $'\n' && "$reply" != 'Y' && "$reply" != 'y' ]]; then
  print "Aborted."
  rm -f "$tsv"
  exit 0
fi

ret=0
for i in {1..${#RUN_TITLES[@]}}; do
  print
  print -P "%F{green}%B[$i/${#RUN_TITLES[@]}] ${RUN_TITLES[$i]}%b%f"
  print -P "%F{yellow}$ ${RUN_CMDS[$i]}%f"
  set +e
  eval "${RUN_CMDS[$i]}"
  rc=$?
  set -e
  (( rc != 0 )) && { print -P "%F{red}Exit $rc%f"; ret=$rc; }
done

rm -f "$tsv"
exit $ret
