#!/bin/bash

# Function to show the selection panel using dialog
show_selection_panel() {
  local options=("Option 1" "Option 2" "Option 3")
  local selected=()
  local result

  while true; do
    result=$(dialog --stdout \
      --title "Select Options" \
      --checklist "Select options using SPACE and Enter:" 0 0 0 \
      "${options[@]}" \
      "${selected[@]}")

    # If user cancels or presses ESC, exit the script
    if [ $? -ne 0 ]; then
      exit 0
    fi

    # If user selects options, break the loop
    if [ ! -z "$result" ]; then
      break
    fi
  done

  # Set the selected options to an array
  selected=($result)

  # Loop through the selected options and execute corresponding scripts in new terminal windows
  for option in "${selected[@]}"; do
    case $option in
      "Option 1")
        gnome-terminal -- bash -c "cd scripts && bash interface-option1.sh; exec bash"
        ;;
      "Option 2")
        gnome-terminal -- bash -c "cd scripts && bash interface-option2.sh; exec bash"
        ;;
      "Option 3")
        gnome-terminal -- bash -c "cd scripts && bash interface-option3.sh; exec bash"
        ;;
    esac
  done
}

# Call the function to show the selection panel
show_selection_panel

clear
