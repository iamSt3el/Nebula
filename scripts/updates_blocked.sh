#!/usr/bin/env bash
export LC_ALL=C

pat="$1"
shift || true

[ -z "$pat" ] && { echo eof; exit 0; }
[ "$#" -eq 0 ] && { echo eof; exit 0; }

db="${CHECKUPDATES_DB:-${TMPDIR:-/tmp}/checkup-db-$(id -u)/}"
[ -d "$db" ] || db="$(pacman-conf DBPath 2>/dev/null)"
[ -d "$db" ] || db=/var/lib/pacman/

pacman --dbpath "$db" --logfile /dev/null -Si "$@" 2>/dev/null | awk -v pat="$pat" '
    /^Name[[:space:]]*:/     { n = $3 }
    /^Packager[[:space:]]*:/ { if (index($0, pat) > 0) print "blocked\t" n }
'

echo eof
