#!/usr/bin/env bash
export LC_ALL=C

keep="${1:-2}"

pacman -Qtdq 2>/dev/null | while IFS= read -r p; do
    [ -n "$p" ] && printf 'orphan\t%s\n' "$p"
done

orphanList="$(pacman -Qtdq 2>/dev/null)"
if [ -n "$orphanList" ]; then
    cascade="$(pacman -Rs --print --print-format '%n' $orphanList 2>/dev/null | wc -l)"
    printf 'cascade\t%s\n' "${cascade:-0}"
fi

cacheDir="$(pacman-conf CacheDir 2>/dev/null | head -1)"
[ -n "$cacheDir" ] || cacheDir=/var/cache/pacman/pkg

bytes="$(du -sb "$cacheDir" 2>/dev/null | cut -f1)"
files="$(find "$cacheDir" -maxdepth 1 -name '*.pkg.tar*' ! -name '*.sig' 2>/dev/null | wc -l)"
printf 'cache\t%s\t%s\t%s\n' "${bytes:-0}" "${files:-0}" "$cacheDir"

parse_dryrun() {
    awk -v tag="$1" '
        /no candidate packages found/ { print tag "\t0\t"; found=1 }
        /finished dry run:/ {
            n = $0; sub(/.*finished dry run:[[:space:]]*/, "", n); sub(/[[:space:]].*/, "", n)
            s = $0; sub(/.*disk space saved:[[:space:]]*/, "", s); sub(/\).*/, "", s)
            print tag "\t" n "\t" s; found=1
        }
        END { if (!found) print tag "\t0\t" }
    '
}

if command -v paccache >/dev/null 2>&1; then
    paccache -d -k "$keep" 2>/dev/null | parse_dryrun prune
    paccache -d -u -k 0    2>/dev/null | parse_dryrun uninstalled
fi

find /etc /boot /opt /usr/share -xdev \( -name '*.pacnew' -o -name '*.pacsave' \) 2>/dev/null \
    | sort | while IFS= read -r f; do
    [ -n "$f" ] && printf 'pacnew\t%s\n' "$f"
done

grep -a 'starting full system upgrade' /var/log/pacman.log 2>/dev/null \
    | tail -1 | sed -n 's/^\[\([^]]*\)\].*/lastupgrade\t\1/p'

echo "eof"
