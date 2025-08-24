#!/bin/bash
# Install Szmelc Wizard ~ Simple Install Script in Bash
# Direct mode (no checkboxes)

tput civis
trap "tput cnorm; clear; exit" EXIT

# [X] "Pos Name" "/path/to/script.sh"
title=" [Installer] "

choices=(
"Option 1 " "scripts/script1.sh"
"Option 2" "scripts/script2.sh"
"Option 3" "scripts/script3.sh"
"Option 4" "scripts/script4.sh"
)

# ANSI color escapes (portable)
cyan=$'\e[36m'
reset=$'\e[0m'

count=$(( ${#choices[@]} / 2 ))
cursor=0

draw_menu() {
    clear
    term_width=$(tput cols)

    max_len=0
    for ((i=0; i<count; i++)); do
        len=${#choices[i*2]}
        (( len > max_len )) && max_len=$len
    done

    line_len=$((4 + max_len))  # 2 for arrow space, 2 for margin
    box_width=$((line_len + 4))
    padding=$(( (term_width - box_width) / 2 ))

    echo -e "\n\n"

    title_len=${#title}
    title_pad=$(( (line_len - title_len) / 2 ))

    printf "%*s┌" "$padding" ""
    printf '─%.0s' $(seq 1 $line_len)
    printf '┐\n'

    printf "%*s│" "$padding" ""
    printf "%*s%s%*s" "$title_pad" "" "$title" "$((line_len - title_pad - title_len))" ""
    printf "│\n"

    printf "%*s└" "$padding" ""
    printf '─%.0s' $(seq 1 $line_len)
    printf '┘\n'

    printf "%*s┌" "$padding" ""
    printf '─%.0s' $(seq 1 $line_len)
    printf '┐\n'

    for ((i=0; i<count; i++)); do
        label="${choices[i*2]}"
        padded_label=$(printf "%-${max_len}s" "$label")
        prefix="  "
        [[ $i -eq $cursor ]] && prefix="${cyan}> ${reset}"

        printf "%*s│ %s%s │\n" "$padding" "" "$prefix" "$padded_label"
    done

    printf "%*s└" "$padding" ""
    printf '─%.0s' $(seq 1 $line_len)
    printf '┘\n'

    echo -e "\n\n\n"
}

while true; do
    draw_menu
    IFS= read -rsn1 key

    if [[ $key == $'\x1b' ]]; then
        read -rsn2 -t 0.01 rest
        case "$rest" in
            "[A") ((cursor > 0)) && ((cursor--)) ;;
            "[B") ((cursor < count - 1)) && ((cursor++)) ;;
            *) echo "Exited."; exit ;;
        esac
    elif [[ $key == $'\n' || $key == "" ]]; then
        clear
        echo ">>> Running ${choices[cursor*2]}"
        bash "${choices[cursor*2+1]}"
        exit
    fi
done
