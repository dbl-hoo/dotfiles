#!/bin/sh
# script for getting sound to work on Artix

/usr/bin/pipewire &
/usr/bin/pipewire-pulse &
/usr/bin/pipewire-media-session &
wireplumber &
