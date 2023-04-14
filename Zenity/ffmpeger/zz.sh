#!/bin/bash

###########################
#  TEMPLATE SHELL SCR UI  #
# 4 INTERFACE BUILDER 1.0 #
###########################
#     By Silverainox      #
#    a.k.a Szmelc.INC     #
###########################

# Define the options for the selection row

options=(
# Makeshift Separator & Category
"~ == Image =="
" 1 - png / jpg -> gif" " 2 - everything -> png" " 3 - png / jpg -> svg" " 4 - mp4 / webm / mkv -> gif" " 5 - rthfghfgh" 
"~ == Settings ==" 
" C - Open Config.yml" " M - Read Manual.man" " B - Back To Main Menu" " E - Exit")

# Use zenity to display the selection dialog with a separator at the bottom
selected_option=$(zenity --list --title="Select an Option" --text="Select an option from the list below:" --column="FFMPEGER" "${options[@]}" --separator="" --height=350)

# Check if an option was selected and the selected option is not empty
if [[ -n "$selected_option" && "$selected_option" != "" ]]; then
    # Execute the corresponding script based on the selected option
    case "$selected_option" in
        " 1"*)
            bash script1.sh
            ;;
        " 2"*)
            bash script2.sh
            ;;
        " 3"*)
            bash script3.sh
            ;;
        " 4"*)
            bash script4.sh
            ;;
        " 5"*)
            bash script5.sh
            ;;
        " C"*)
            xdg-open config.yml
            ;;
        " M"*)
            xdg-open MANUAL.man
            ;;
        " B"*)
            bash zz.sh
            ;;     
        " E"*)
            exit 0
            ;;                        
        *)
            # Display an error message if the selected option is not recognized
            zenity --error --title="Error" --text="Invalid selection."
            ;;
    esac
fi
