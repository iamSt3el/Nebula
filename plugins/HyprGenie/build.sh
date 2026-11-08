#!/bin/bash
set -e
cd "$(dirname "$0")"

CXX="${CXX:-g++}"
FLAGS="$(pkg-config --cflags hyprland pixman-1 libdrm hyprutils hyprlang aquamarine hyprgraphics 2>/dev/null || pkg-config --cflags hyprland pixman-1 libdrm)"

mkdir -p build
echo "==> Building genie.so for Hyprland $(pkg-config --modversion hyprland)"
"$CXX" -shared -fPIC -std=c++26 -O2 -Wall -Wno-deprecated-declarations $FLAGS main.cpp -o build/genie.so

dest="$HOME/.local/lib/hyprland"
mkdir -p "$dest"
stamp="$(date +%s)"
rm -f "$dest"/genie-*.so
cp -f build/genie.so "$dest/genie-$stamp.so"
ln -sfn "genie-$stamp.so" "$dest/genie.so"
echo "==> Installed $dest/genie-$stamp.so"


if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && hyprctl genie status 2>/dev/null | head -1 | { read -r l; case "$l" in open*) true ;; *) false ;; esac; }; then
    echo "==> Reloading the running plugin"
    ./genie-ctl.sh reload
    qs ipc call genie refresh >/dev/null 2>&1 || true
fi
