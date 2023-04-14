#!/bin/bash

# Set the theme for Zenity dialogs
export GTK_THEME="Win98"

# Function to list packages
list_packages() {
    # Use find command to search for exec.sh files inside packages folder and its subfolders
    packages=$(find packages -name "exec.sh" -exec dirname {} \;)

    # Display the list of packages using Zenity
    zenity --list \
           --title="List Packages" \
           --text="Packages found:" \
           --column="Package" \
           "${packages[@]}" \
           --height=250 \
           --width=300 \
           --ok-label="OK"
}

# Display the main menu using Zenity with classic Windows 98 theme
main_menu_choice=$(zenity --list \
                       --title="Main Menu" \
                       --text="Select an option:" \
                       --column="Option" --column="Description" \
                       1 "Get Szmelc" \
                       2 "Run Szmelc" \
                       3 "List Packages" \
                       4 "Config" \
                       5 "Manual" \ 
                       6 "Quit" \
                       --height=250 \
                       --width=300 \
                       --ok-label="Select" \
                       --cancel-label="Quit")

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
    4)
        # Option 3: Open config.yml in default text editor
        xdg-open config.yml
        ;;
    5)
        # Option 4: Open MANUAL.man in default text editor
        xdg-open MANUAL.man
        ;;
    3)
        # Option 5: List Packages
        list_packages
        ;;
    6)
        # Option 6: Quit the script
        exit 0
        ;;
    *)
        # Invalid choice: Display error message
        zenity --error --title="Error" --text="Invalid selection" \
            --height=150 \
            --width=300 \
            --ok-label="OK"
        ;;
esac
