#!/bin/bash

# Load configuration from config.json file
config_file="config.json"
title=$(jq -r '.TITLE' "$config_file")
options=($(jq -r '.OPTIONS[]' "$config_file"))

# Use zenity to display the selection dialog with the title and options from the config.json file
selected_option=$(zenity --list --title="$title" --text="Select an option from the list below:" --column="Options" "${options[@]}" --separator=" " --height=250)

# Check if an option was selected and the selected option is not empty
if [[ -n "$selected_option" && "$selected_option" != "" ]]; then
    # Execute the corresponding script based on the selected option
    case "$selected_option" in
        "1-"*)
            ./script.sh
            ;;
        "2-"*)
            ./script2.sh
            ;;
        "3-"*)
            ./script.sh
            ;;
        "4-"*)
            ./script.sh
            ;;
        "5-"*)
            ./script.sh
            ;;
        "6-"*)
            ./script.sh
            ;;
        "7-"*)
            ./script.sh
            ;;
        "8-"*)
            ./script.sh
            ;;                        
        *)
            # Display an error message if the selected option is not recognized
            zenity --error --title="Error" --text="Invalid selection."
            ;;
    esac
fi
