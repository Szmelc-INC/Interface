#!/bin/bash

# UNIVERSAL ZENITY SELECTION PANEL

# Define the options for the selection row
options=("1" "2" "3" "b" "y" "e")

# Use zenity to display the selection dialog
selected_option=$(zenity --list --title="Select an Option" --text="Select an option from the list below:" --column="Options" "${options[@]}")

# Check if an option was selected
if [[ -n "$selected_option" ]]; then
    # Execute the corresponding script based on the selected option
    case "$selected_option" in
        "1")
            bash n.sh
            ;;
        "2")
            curl parrot.live
            ;;
        "3")
            ./script.sh
            ;;
        *)
            # Display an error message if the selected option is not recognized
            zenity --error --title="Error" --text="Invalid selection."
            ;;
    esac
fi
