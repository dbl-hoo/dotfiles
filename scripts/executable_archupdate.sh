#!/bin/bash

clear


# Check if yay is installed
if ! command -v yay &> /dev/null; then
    echo "yay not found. Please install yay first."
    exit 1
fi

# Update yay and AUR packages
echo "Updating yay and AUR packages..."
yay -Syu --noconfirm

# Check for and remove orphaned packages
echo "Removing orphaned packages..."
yay -Rns --noconfirm $(yay -Qdtq)

echo "AUR update script completed."
# Prompt user to press any key to continue
read -n 1 -s -r -p "Press any key to continue..."