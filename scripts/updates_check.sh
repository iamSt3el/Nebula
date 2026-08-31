#!/usr/bin/env bash
export LC_ALL=C

mode="${1:-all}"

if [ "$mode" != "aur" ]; then
    if command -v checkupdates >/dev/null 2>&1; then
        checkupdates 2>/dev/null | awk -F'[[:space:]]+' '$4 != "" { print "repo\t" $1 "\t" $2 "\t" $4 }'
    fi
fi

if [ "$mode" != "repo" ]; then
    helper=""
    for h in yay paru; do
        command -v "$h" >/dev/null 2>&1 && { helper="$h"; break; }
    done
    if [ -n "$helper" ]; then
        "$helper" -Qua 2>/dev/null | awk -F'[[:space:]]+' '$4 != "" { print "aur\t" $1 "\t" $2 "\t" $4 }'
    fi
fi

if [ "$mode" != "aur" ]; then
    db="${CHECKUPDATES_DB:-${TMPDIR:-/tmp}/checkup-db-$(id -u)/}"
    if [ -d "$db" ]; then
        pacman --dbpath "$db" --logfile /dev/null -Sup --print-format '%s' 2>/dev/null \
            | awk '{ n += 1; t += $1 } END { print "totals\t" n+0 "\t" t+0 }'
    fi
fi

echo "eof"
