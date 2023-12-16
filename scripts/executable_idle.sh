#!/bin/bash

# Set the timeout values in seconds (5 minutes = 300 seconds, 6 minutes = 360 seconds)
lock_timeout=300
total_timeout=360

# Start swayidle with the specified timeouts
swayidle -w \
    timeout $lock_timeout '~/scripts/screenlock.sh' \
    timeout $total_timeout 'hyprctl dispatch dpms off' \
    resume 'hyprctl dispatch dpms on'
