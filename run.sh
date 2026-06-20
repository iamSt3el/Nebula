#!/usr/bin/env bash

SRC_DIR="shaders"
DST_DIR="shaders/qsb"

NAMES=("parallax.vert" "parallax.frag")

main() {
    mkdir -p "$DST_DIR" || return 1
    if ! command -v qsb >/dev/null 2>&1; then
        echo "qsb not found, skipping shader compilation" >&2
    else
        for shader in "${NAMES[@]}"
        do
            qsb --qt6 -o "$DST_DIR/$shader.qsb" "$SRC_DIR/$shader"
        done
        echo "shaders compiled" >&2
    fi

    echo "done" >&2
}

main "$@"
