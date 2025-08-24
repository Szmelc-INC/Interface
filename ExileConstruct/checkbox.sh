#!/bin/bash
# Install Szmelc Wizard ~ Simple Install Script in Bash
# Checkbox mode (multiple choice list)

tput civis
trap "tput cnorm; clear; exit" EXIT

# [X] "Pos Name" "/path/to/script.sh"
choices=(
"StrapON" "inst.sh"
"ConfigStall" "szmelc/configstal.sh"
"Entropy Package Manager" "szmelc/epm.sh"
)

# ANSI color escapes (portable)
yellow=$'\e[33m'
cyan=$'\e[36m'
reset=$'\e[0m'

count=$(( ${#choices[@]} / 2 ))
declare -a checked
for ((i=0; i<count; i++)); do checked[i]=false; done

cursor=0

draw_menu() {
    clear
    term_width=$(tput cols)

    # Longest label length
    max_len=0
    for ((i=0; i<count; i++)); do
        len=${#choices[i*2]}
        (( len > max_len )) && max_len=$len
    done

    line_len=$((8 + max_len + 2))  # checkbox + label + cursor space
    box_width=$((line_len + 4))
    padding=$(( (term_width - box_width) / 2 ))

    echo -e "\n\n"  # Top padding

    #### ── TITLE BOX ──
    title="[Install Szmelc Wizard]"
    title_len=${#title}
    title_pad=$(( (line_len - title_len) / 2 ))
    title_left_pad=$(( padding + 1 ))

    # Top border
    printf "%*s┌" "$padding" ""
    printf '─%.0s' $(seq 1 $line_len)
    printf '┐\n'

    # Title line (centered inside box)
    printf "%*s│" "$padding" ""
    printf "%*s%s%*s" "$title_pad" "" "$title" "$((line_len - title_pad - title_len))" ""
    printf "│\n"

    # Bottom border
    printf "%*s└" "$padding" ""
    printf '─%.0s' $(seq 1 $line_len)
    printf '┘\n'

    #### ── CHECKBOX MENU ──

    # Top border
    printf "%*s" "$padding" ""
    printf '┌'
    printf '─%.0s' $(seq 1 $line_len)
    printf '┐\n'

    # Menu lines
    for ((i=0; i<count; i++)); do
        checkbox="[ ]"
        [[ ${checked[i]} == true ]] && checkbox="[$yellow"x"$reset]"

        label="${choices[i*2]}"
        padded_label=$(printf "%-${max_len}s" "$label")

        cursor_marker="  "
        [[ $i -eq $cursor ]] && cursor_marker=" ${cyan}<${reset}"

        printf "%*s│ %s \"%s\"%s │\n" "$padding" "" "$checkbox" "$padded_label" "$cursor_marker"
    done

    # Bottom border
    printf "%*s" "$padding" ""
    printf '└'
    printf '─%.0s' $(seq 1 $line_len)
    printf '┘\n'

    echo -e "\n\n\n"  # Bottom padding
}

run_selected() {
    echo -e "\nSelected:"
    for ((i=0; i<count; i++)); do
        [[ ${checked[i]} == true ]] && echo "- ${choices[i*2]}"
    done

    echo -ne "\nRun these? (Y/n): "
    read -r confirm
    confirm=${confirm:-y}
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "Cancelled." && exit

    echo -e "\nRunning:\n"
    for ((i=0; i<count; i++)); do
        if [[ ${checked[i]} == true ]]; then
            echo ">>> Running ${choices[i*2]}"
            bash "${choices[i*2+1]}"
        fi
    done
}

while true; do
    draw_menu
    IFS= read -rsn1 key

    if [[ $key == $'\x1b' ]]; then
        read -rsn2 -t 0.01 rest
        case "$rest" in
            "[A") ((cursor > 0)) && ((cursor--)) ;;   # Up
            "[B") ((cursor < count - 1)) && ((cursor++)) ;; # Down
            *) echo "Exited."; exit ;;
        esac
    elif [[ $key == " " ]]; then
        checked[$cursor]=$([[ ${checked[$cursor]} == true ]] && echo false || echo true)
    elif [[ $key == $'\n' || $key == "" ]]; then
        run_selected
        exit
    fi
done
