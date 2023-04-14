#!/bin/bash

# Function to show the selection panel using dialog
show_selection_panel() {
  local options=(
  "1" "Szmelc-Commander" 
  "2" "Git-NForcer" 
  "3" "Szmelc-Organizer" 
  "4" "Dir-Dismantler"
  )
  local selected=()
  local result

  while true; do
    result=$(dialog --stdout \
      --title "Select Options" \
      --no-tags \
      --menu "Select an option using arrow keys and Enter:" 24 0 0 \
      "${options[@]}" \
      "${selected[@]}")

    # If user cancels or presses ESC, exit the script
    if [ $? -ne 0 ]; then
      exit 0
    fi

    # If user selects an option, break the loop
    if [ ! -z "$result" ]; then
      break
    fi
  done

  # Set the selected option to a variable
  selected=$result

  # Execute the corresponding script in a new xterm window
  case $selected in
    "1")
      xterm -e "bash run.sh"
      ;;
    "2")
      xterm -e "curl parrot.live"
      ;;
    "3")
      xterm -e "bash main3.sh"
      ;;
    "4")
      xterm -e "bash get2.sh"
      ;;
  esac
}

# Call the function to show the selection panel
show_selection_panel

clear
