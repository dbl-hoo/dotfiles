#!/bin/sh

#import pywal colors
# shellcheck source=/home/master/.cache/wal/colors.sh
source "$HOME/.cache/wal/colors.sh"

swaylock -f \
	--screenshots \
	--clock \
	--indicator \
	--indicator-radius 100 \
	--indicator-thickness 15 \
	--effect-blur 7x5 \
	--effect-vignette 0.5:0.5 \
	--ring-color $color2 \
	--ring-ver-color $color3 \
	--text-color $color7 \
	--key-hl-color $color1 \
	--line-color 00000000 \
	--inside-color $color0 \
	--inside-clear-color $color1\
	--caps-lock-key-hl-color E82809\
	--text-caps-lock-color  E82809\
	--separator-color 00000000 \
	--grace 2 \
	--fade-in 0.2

