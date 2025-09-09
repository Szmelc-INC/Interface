#!/usr/bin/env zsh
# menu-fzf.zsh — entries-based zsh + fzf TUI (sane preview, confirm & run)

set -u
set -o pipefail

command -v fzf >/dev/null 2>&1 || { print -u2 "fzf not found"; exit 1; }

# ── DATA: one entry per line (TAB-separated): title  desc  preview_cmd  run_cmd
typeset -a ENTRIES
ENTRIES+=($'Uname\tKernel and arch information\tuname -a\tuname -a')
ENTRIES+=($'Date\tCurrent system date/time (RFC 2822)\tdate -R\tdate -R')
ENTRIES+=($'Disk Usage\tdf -h for mounted filesystems\tdf -h\tdf -h')
ENTRIES+=($'Memory\tfree -h snapshot\tfree -h\tfree -h')
ENTRIES+=($'Top Processes\tps sorted by CPU\tps -eo pid,ppid,comm,pcpu,pmem --sort=-pcpu | head -n 20\tps -eo pid,ppid,comm,pcpu,pmem --sort=-pcpu | head -n 20')
ENTRIES+=($'Kernel Modules\tlsmod summary\tlsmod | head -n 40\tlsmod')

# ── Build TSV for fzf: idx<TAB>title<TAB>desc<TAB>preview_cmd<TAB>run_cmd
tsv=$(mktemp) || { print -u2 "mktemp failed"; exit 1; }
{
  typeset -i i=0
  for line in "${ENTRIES[@]}"; do
    ((i++))
    clean="${line//$'\n'/' '}"
    printf "%d\t%s\n" "$i" "$clean"
  done
} > "$tsv"

# ── Preview helper script (plain text layout, no box chars)
preview_sh=$(mktemp) || { print -u2 "mktemp failed"; exit 1; }
cat >"$preview_sh" <<'ZSH'
#!/usr/bin/env zsh
set -u
set -o pipefail
file="$1"; idx="$2"

# find the row by index; read fields safely
typeset -a fields
while IFS=$'\t' read -r i t d p r; do
  if [[ "$i" == "$idx" ]]; then
    fields=("$i" "$t" "$d" "$p" "$r")
    break
  fi
done < "$file"

title="${fields[2]:-Item}"
desc="${fields[3]:-}"
pcmd="${fields[4]:-echo no-cmd}"

cols=${FZF_PREVIEW_COLUMNS:-80}
lines=${FZF_PREVIEW_LINES:-24}
(( cols < 20 )) && cols=20
(( lines < 8 )) && lines=8

B=$'\e[1m'; C=$'\e[36m'; R=$'\e[0m'

# Title
print -r -- "${B}${C}${title}${R}"
print -r -- "$(printf '%.0s-' {1..200} | cut -c1-$cols)"

# Description (wrapped)
print -r -- "$desc" | fold -s -w "$cols"
print
print -r -- "Live Preview: $pcmd"
print -r -- "$(printf '%.0s-' {1..200} | cut -c1-$cols)"

# Command output (no sed tricks; just head/cut)
# NOTE: keep commands quick; long-running will block preview refresh.
{
  eval "$pcmd" 2>&1 \
  | head -n $((lines - 8)) \
  | cut -c1-"$cols"
} || true
ZSH
chmod +x "$preview_sh"

# ── Run fzf (use index only in preview; the script reads fields from TSV)
set +e
selection="$(
  FZF_DEFAULT_OPTS='' \
  fzf --ansi --multi --height=100% --layout=reverse \
      --delimiter=$'\t' --with-nth=2 \
      --preview "$preview_sh $tsv {1}" \
      --preview-window=right,70%,wrap \
      --marker='x' --pointer='▶ ' --prompt='Select > ' \
      --header=$'Space/Tab: toggle • Enter: confirm • q/C-c: abort' \
      --bind 'space:toggle,tab:toggle,q:abort' \
      < "$tsv"
)"
fzf_rc=$?
set -e

if (( fzf_rc != 0 )); then
  rm -f "$tsv" "$preview_sh"
  exit $fzf_rc
fi

if [[ -z "${selection// }" ]]; then
  print "No selections."
  rm -f "$tsv" "$preview_sh"
  exit 0
fi

# ── Parse chosen rows; collect titles + run_cmds in order
typeset -a RUN_TITLES RUN_CMDS
while IFS=$'\t' read -r i t d p r; do
  RUN_TITLES+=("$t")
  RUN_CMDS+=("$r")
done <<< "$selection"

# ── Confirmation
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

# ── Execute in order; stream outputs
ret=0
for i in {1..${#RUN_TITLES[@]}}; do
  print
  print -P "%F{green}%B[$i/${#RUN_TITLES[@]}] ${RUN_TITLES[$i]}%b%f"
  print -P "%F{yellow}$ ${RUN_CMDS[$i]}%f"
  set +e
  eval "${RUN_CMDS[$i]}"
  rc=$?
  set -e
  if (( rc != 0 )); then
    print -P "%F{red}Exit $rc%f"
    ret=$rc
  fi
done

rm -f "$tsv" "$preview_sh"
exit $ret
