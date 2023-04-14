#!/bin/bash

# Define the options for the selection row
options=("~ Primary" " Option 1" " Option 2" " Option 3" " Option 4" "~ Settings" " Config" " Manual" " Exit")

# Use zenity to display the selection dialog with a separator at the bottom
selected_option=$(zenity --list --title="Select an Option" --text="Select an option from the list below:" --column="SZMELC UI" "${options[@]}" --separator="" --height=350)

# Check if an option was selected and the selected option is not empty
if [[ -n "$selected_option" && "$selected_option" != "" ]]; then
    # Execute the corresponding script based on the selected option
    case "$selected_option" in
        "Option 1")
            ./script.sh
            ;;
        "Option 2")
            ./script.sh
            ;;
        "Option 3")
            ./script.sh
            ;;
        "Option 4")
            ./script.sh
            ;;
        "Option 5")
            ./script.sh
            ;;
        *)
            # Display an error message if the selected option is not recognized
            zenity --error --title="Error" --text="Invalid selection."
            ;;
    esac
fi
