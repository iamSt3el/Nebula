#!/bin/bash
wallpaper="$1"
scheme="$2"
theme="$3"
transition="${4:-fade}"

# Set wallpaper with awww
awww img "$wallpaper" --transition-type "$transition" --transition-duration 4

# Generate color scheme with matugen
matugen image "$wallpaper" -t "$scheme" -m "$theme"

echo "Wallpaper set and colors generated!"
