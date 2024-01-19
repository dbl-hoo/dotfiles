# dotfiles
# This repo houses my dotfiles for my hyperland config on Artix
It is managed using Chezmoi

Artix install:  https://wiki.artixlinux.org/Main/Installation
su # change to root
mkfs.ext4 /dev/nvme0n1pX # format the root partition
mkfs.fat -F 32 /dev/nvme0n1p1 # format EFI partition
mount /dev/nvme0n1pX /mnt # mount the root partion
mkdir -p /mnt/boot/efi # create /boot/efi directory
mount /dev/nvme0n1p1 /mnt/boot/efi #mount /boot/efi director
