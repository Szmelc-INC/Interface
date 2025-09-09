#!/usr/bin/env zsh
# menu-fzf.zsh — bordered fzf TUI with top title and bottom binds "footer"

set -u
set -o pipefail

command -v fzf >/dev/null 2>&1 || { print -u2 "fzf not found"; exit 1; }

TITLE="${TITLE:-TUI MENU}"  
BINDS="${BINDS:-Space/Tab: toggle • Enter: confirm • q/C-c: abort}"  

typeset -a ENTRIES

ENTRY() {
  local title="$1"
  local desc preview run
  IFS= read -r desc
  IFS= read -r preview
  IFS= read -r run
  ENTRIES+=("$title"$'\t'"$desc"$'\t'"$preview"$'\t'"$run")
}

# ── ENTRIES ──
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

# ── TSV
tsv=$(mktemp)
{
  typeset -i i=0
  for line in "${ENTRIES[@]}"; do
    ((i++))
    printf "%d\t%s\n" "$i" "$line"
  done
} > "$tsv"

# ── Preview script (same as before, box-drawing bars + colors)
preview_sh=$(mktemp)
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

H=$'─'; TEE_L=$'├'; TEE_R=$'┤'

hr() { local n=$1 out=""; while (( n-- > 0 )); do out+="$H"; done; printf "%s" "$out"; }
bar() {
  local label="$1" color="$2"
  local plain="$TEE_R [ ${label} ] $TEE_L"
  local colored="$TEE_R [ ${color}${label}${R} ] $TEE_L"
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

# ── Run fzf with top and bottom labels
set +e
selection="$(
  {
    echo "===FOOTER=== $BINDS"  # special marker row we’ll skip
    cat "$tsv"
  } | \
  fzf --ansi --multi --height=100% --layout=reverse \
      --delimiter=$'\t' --with-nth=2 \
      --preview "$preview_sh $tsv {1}" \
      --preview-window=right,70%,wrap,border-left \
      --marker='x' --pointer='▶ ' --prompt='Select > ' \
      --bind 'space:toggle,tab:toggle,q:abort' \
      --border --border-label=" [ '"$TITLE"' ] " --border-label-pos=top \
      --padding=1,2 \
      --header-lines=1 --header-first
)"
fzf_rc=$?
set -e

if (( fzf_rc != 0 )); then
  rm -f "$tsv" "$preview_sh"
  exit $fzf_rc
fi

# ── Strip the fake footer row if selected accidentally
selection="$(echo "$selection" | grep -v '^===FOOTER===')"

if [[ -z "${selection// }" ]]; then
  print "No selections."
  rm -f "$tsv" "$preview_sh"
  exit 0
fi

# ── Parse and execute (same as before) ...
typeset -a RUN_TITLES RUN_CMDS
while IFS=$'\t' read -r i t d p r; do
  [[ -z "$i" ]] && continue
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
  rm -f "$tsv" "$preview_sh"
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

rm -f "$tsv" "$preview_sh"
exit $ret
