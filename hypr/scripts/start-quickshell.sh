#!/bin/bash

# Wait for Hyprland to be fully ready
sleep 0.5

# Ensure Wayland environment is available
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

exec /usr/bin/quickshell -p "$HOME/.config/quickshell"
