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
"~ == <CAT1> =="
" 1 - <option1>" " 2 - <option2>" " 3 - <option3>" " 4 - <option4>" " 5 - <option5>" 
"~ == <CAT2> ==" 
" C - <option2-1>" " B - <option2-2>" " E - <option2-3>")

# Use zenity to display the selection dialog with a separator at the bottom
selected_option=$(zenity --list --title="<TITLE>" --text="Select an option:" --column="<TITLE>" "${options[@]}" --separator="" --height=350)

# Check if an option was selected and the selected option is not empty
if [[ -n "$selected_option" && "$selected_option" != "" ]]; then
    # Execute the corresponding script based on the selected option
    case "$selected_option" in
        " 1"*)
            bash <script1.sh>
            ;;
        " 2"*)
            bash <script2.sh>
            ;;
        " 3"*)
            bash <script3.sh>
            ;;
        " 4"*)
            bash <script4.sh>
            ;;
        " 5"*)
            bash <script5.sh>
            ;;
        " C"*)
            <C>
            ;;
        " M"*)
            <M>
            ;;
        " B"*)
            <B>
            ;;     
        " E"*)
            <E>
            ;;                        
        *)
            # Display an error message if the selected option is not recognized
            zenity --error --title="Error" --text="Invalid selection."
            ;;
    esac
fi
