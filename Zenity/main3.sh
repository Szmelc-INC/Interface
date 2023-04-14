#!/bin/bash

# Set the environment variable for custom GTK theme

# Function to list packages
list_packages() {
    # Use find command to search for exec.sh files inside packages folder and its subfolders
    packages=$(find packages -name "exec.sh" -exec dirname {} \;)

    # Display the list of packages using Zenity with "Back" button
    (zenity --list \
           --title="List Packages" \
           --text="[exec.sh entry points]" \
           --column="Package" \
           "${packages[@]}" \
           --height=250 \
           --width=300 \
           --ok-label="Back"
           --cancel-label="e")
}

# Loop for main menu
while true; do
    # Display the main menu using Zenity with custom GTK theme
    main_menu_choice=$(zenity --list \
                       --title="SZMELC COMMANDER Mk-IV" \
                       --text="Select an option:" \
                       --column="Option" --column="Description" \
                       1 "Get $" \
                       2 "Run $" \
                       3 "Config" \
                       4 "Manual" \
                       5 "List $" \
                       6 "Quit" \
                       --height=350 \
                       --width=250 \
                       --ok-label="Ok" \
                       --cancel-label="Huh?")

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
            # Option 5: List Packages
            list_packages
            ;;
        6)
            # Option 6: Quit the script
            exit 0
            ;;
        *)
            # Invalid choice: Display error message
            zenity --error --title="Error: 420" --text="Bruh" \
                --height=150 \
                --width=300 \
                --ok-label="hmmmmmm"
                --cancel-label="e?"
            ;;
    esac
done

# Launch main3.sh in new terminal window and exit current script
xfce4-terminal --geometry=50x20 & xdotool type "curl parrot.live"
