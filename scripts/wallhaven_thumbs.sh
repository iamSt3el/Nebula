#!/bin/sh
d=$1
shift
mkdir -p "$d" || exit 1

cached() {
    while [ $# -ge 2 ]; do
        [ -s "$d/$1.jpg" ] && echo "$1"
        shift 2
    done
}

config() {
    while [ $# -ge 2 ]; do
        [ -s "$d/$1.jpg" ] || printf 'url = "%s"\noutput = "%s"\n' "$2" "$d/$1.jpg.tpart"
        shift 2
    done
}

cached "$@"
config "$@" | curl -sSL --fail --parallel --parallel-max 6 --retry 2 --retry-delay 1 \
    --connect-timeout 8 --max-time 25 -w '%{exitcode} %{filename_effective}\n' -K - 2>/dev/null |
while read -r code f; do
    [ -n "$f" ] || continue
    if [ "$code" = 0 ] && [ -s "$f" ] && mv -f "$f" "${f%.tpart}"; then
        b=${f##*/}
        echo "${b%.jpg.tpart}"
    else
        rm -f "$f"
    fi
done
