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

# Function to execute cmatrix command in a new terminal window
execute_cmatrix() {
    # Launch xfce4-terminal in fullscreen mode with always-on-top flag and execute cmatrix command
    xfce4-terminal --fullscreen --title="Matrix" --hide-scrollbar --hide-toolbar --hide-menubar --hide-borders --always-on-top --execute cmatrix
}

# Loop for main menu
while true; do
    # Display the main menu using Zenity with custom GTK theme
    main_menu_choice=$(zenity --list \
                       --title="SZMELC COMMANDER Mk-IV" \
                       --text="Select an option:" \
                       --column="No" --column="Selection" \
                       1 "Get $" \
                       2 "Run $" \
                       3 "Settings" \
                       4 "Config" \
                       5 "Manual" \
                       6 "List $" \
                       7 "Quit" \
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
            # Option 3: Open settings panel
            settings_menu_choice=$(zenity --list \
                                   --title="Settings" \
                                   --text="Select a setting:" \
                                   --column="Setting" --column="Value" \
                                   "is_matrix" <boolean> "is_silver" <bolean> \
                                   --height=250 \
                                   --width=300 \
                                   --editable \
                                   --ok-label="Ok")
                                   #--cancel-label="Back")
            case $settings_menu_choice in
                "is_matrix=true")
                    # Execute cmatrix in a new terminal window
                    execute_cmatrix
                    ;;
                *)
                    # Invalid choice: Display error message
                    zenity --error --title="Error: 420" --text="Bruh" \
                        --height=150 \
                        --width=300 \
                        --ok-label="hmmmmmm" \
                        --cancel-label="e?"
                    ;;
            esac
            ;;
        4)
            # Option 4: Open config.yml in default text editor
            xdg-open config.yml
            ;;
        5)
            # Option 5: Open MANUAL.man in default text editor
            xdg-open MANUAL.man
            ;;
        6)
            # Option 6: List Packages
            list_packages
            ;;
        7)
            # Option 7: Quit the script
            exit 0
            ;;
        666)
            # Option 7: Quit the script
            exit 0
            ;;    
        *)
            # Invalid choice: Display error message
            zenity --error --title="Error: 420" --text="Hmmmmmmmmmmmmmmmmmmmmmmmmmmmm" \
                --height=150 \
                --width=300 \
                --ok-label="Bruh"
                --cancel-label="e?"
            ;;
    esac
done

