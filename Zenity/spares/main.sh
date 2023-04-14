#!/bin/bash

# Display the main menu using Zenity
main_menu_choice=$(zenity --list \
                       --title="Main Menu" \
                       --text="Select an option:" \
                       --column="Option" --column="Description" \
                       1 "Get Szmelc" \
                       2 "Run Szmelc" \
                       3 "Config" \
                       4 "Manual" \
                       5 "Quit")

# Check the user's choice and perform the corresponding action
case $main_menu_choice in
    1)
        # Option 1: Execute get.sh script
        bash get.sh
        ;;
    2)
        # Option 2: Execute run.sh script
        bash run.sh
        ;;
    3)
        # Option 3: Open config.yml in default text editor
        xdg-open config.yml
        ;;
    4)
        # Option 4: Open MANUAL.man in default text editor
        xdg-open MANUAL.man
        ;;
    5)
        # Option 5: Quit the script
        exit 0
        ;;
    *)
        # Invalid choice: Display error message
        zenity --error --title="Error" --text="Invalid choice. Please select a valid option."
        ;;
esac
