#!/bin/bash

# Load configuration from config.json file
config_file="config.json"
title=$(jq -r '.TITLE' "$config_file")
options=($(jq -r '.OPTIONS[].TITLE' "$config_file"))
scripts=($(jq -r '.OPTIONS[].SCRIPT' "$config_file"))

# Use zenity to display the selection dialog with the title and options from the config.json file
selected_option=$(zenity --list --title="$title" --text="Select an option from the list below:" --column="Options" "${options[@]}" --separator="" --height=250)

# Check if an option was selected and the selected option is not empty
if [[ -n "$selected_option" && "$selected_option" != "" ]]; then
    # Find the index of the selected option in the options array
    selected_index=-1
    for i in "${!options[@]}"; do
        if [[ "${options[i]}" == "$selected_option" ]]; then
            selected_index=$i
            break
        fi
    done

    # If a valid index is found, execute the corresponding script based on the selected option
    if [[ $selected_index -ge 0 ]]; then
        script_to_execute="${scripts[selected_index]}"
        if [[ -x "$script_to_execute" ]]; then
            "$script_to_execute"
        else
            # Display an error message if the script is not executable
            zenity --error --title="Error" --text="Script '$script_to_execute' is not executable."
        fi
    else
        # Display an error message if the selected option is not recognized
        zenity --error --title="Error" --text="Invalid selection."
    fi
fi
