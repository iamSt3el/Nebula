#!/bin/sh
lib="$HOME/.local/lib/hyprland/genie.so"
state="${XDG_RUNTIME_DIR:-/tmp}/nebula-genie-${HYPRLAND_INSTANCE_SIGNATURE:-x}.path"

loaded() {
    case "$(hyprctl genie status 2>/dev/null)" in
        open*) return 0 ;;
    esac
    return 1
}

case "$1" in
    unload)
        p="$(cat "$state" 2>/dev/null)"
        [ -n "$p" ] || p="$lib"
        hyprctl plugin unload "$p"
        rm -f "$state"
        ;;
    load)
        if loaded; then
            echo ok
            exit 0
        fi
        [ -e "$lib" ] || { echo "missing $lib"; exit 1; }
        real="$(readlink -f "$lib")"
        r="$(hyprctl plugin load "$real")"
        echo "$r"
        [ "$r" = "ok" ] && printf '%s\n' "$real" > "$state"
        ;;
    reload)
        "$0" unload > /dev/null
        exec "$0" load
        ;;
    *)
        echo "usage: genie-ctl.sh load|unload|reload"
        exit 1
        ;;
esac
