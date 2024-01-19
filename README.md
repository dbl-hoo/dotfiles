# dotfiles
# This repo houses my dotfiles for my hyperland config on Artix
It is managed using Chezmoi

Artix install:  https://wiki.artixlinux.org/Main/Installation

su # change to root

mkfs.ext4 /dev/nvme0n1pX # format the root partition

mkfs.fat -F 32 /dev/nvme0n1p1 # format EFI partition

mount /dev/nvme0n1pX /mnt # mount the root partion

mkdir -p /mnt/boot/efi # create /boot/efi directory

mount /dev/nvme0n1p1 /mnt/boot/efi #mount /boot/efi directory

ip link set wlan0 up # set wlan0 connection up

rfkill unblock wlan0 # make sure rfkill isn't blocking anything

nano /etc/wpa_supplicant/wpa_supplicant.conf
  ctrl_interface=/run/wpa_supplicant
  update_config=1

 wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf

 wpa_cli

 add_network

set_network 0 ssid "Kirkham"

set_network 0 psk "redoctober3290"

enable_network 0

save_config

quit

dhcpcd

sv up ntpd
 
