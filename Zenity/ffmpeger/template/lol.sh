#!/bin/bash

# Load configuration from config.json file
config_file="config.json"
title=$(jq -r '.TITLE' "$config_file")
options=$(jq -r '.OPTIONS[].TITLE' "$config_file" | tr '\n' ' ')

# Use zenity to display the selection dialog with the title and options from the config.json file
selected_option=$(zenity --list --title="$title" --text="Select an option from the list below:" --column="Options" $options --separator="" --height=250)

# Get the corresponding script to run
script_to_run=$(jq -r '.OPTIONS[] | select(.TITLE=="'$selected_option'") | .RUN' "$config_file")

# Execute the selected script
eval "$script_to_run"
