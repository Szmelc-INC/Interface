#!/bin/bash

xfce4-terminal --geometry=50x20 &
sleep 1
# Send the `curl parrot.live` command to the terminal window
xdotool type "cmatrix"
xdotool key Return

clear
