#!/bin/sh
# Name: Nebula AC Test
# Author: Nebula
# DontUseFBInk
(
DIR=/mnt/us/nebula-dash
CACHE="$DIR/cache"
LOG="$DIR/actest.log"
mkdir -p "$CACHE"
: > "$LOG"
log() {
    echo "$(date '+%T') $*" >> "$LOG"
}
. "$DIR/ac.sh"
(
    i=0
    while [ $i -lt 24 ]; do
        sleep 5
        i=$((i + 1))
        log "watch: $(ps 2>/dev/null | grep -E 'curl|timeout' | grep -v grep | awk '{ print $1, $NF }' | tr '\n' ';')"
    done
) &
URL=https://auth.miraie.in/simplifi/v1/userManagement/login
log "test 1: dummy login"
t0=$(date +%s)
r=$(timeout 40 curl -sS -m 25 --connect-timeout 10 -o "$CACHE/t1.out" -w 'http=%{http_code} total=%{time_total}' \
    -H 'Content-Type: application/json' \
    -d '{"clientId":"PBcMcfG19njNCL8AOgvRzIC8AjQa","mobile":"+910000000000","password":"x","scope":"an_14214235325"}' "$URL" 2>&1)
log "test 1: rc=$? $r ($(( $(date +%s) - t0 ))s) body=$(head -c 120 "$CACHE/t1.out")"
user=$(conf_value PHONE)
pass=$(conf_value PASSWORD)
body="{\"clientId\":\"$CLIENT_ID\",\"mobile\":\"$(jesc "$user")\",\"password\":\"$(jesc "$pass")\",\"scope\":\"an_14214235325\"}"
log "test 2: real login, body ${#body} chars"
t0=$(date +%s)
r=$(timeout 40 curl -sS -v -m 25 --connect-timeout 10 -o "$CACHE/t2.out" -w 'http=%{http_code} total=%{time_total}' \
    -H 'Content-Type: application/json' -d "$body" "$URL" 2> "$CACHE/t2.trace")
log "test 2: rc=$? $r ($(( $(date +%s) - t0 ))s) body=$(head -c 160 "$CACHE/t2.out" | sed 's/"accessToken":"[^"]*"/"accessToken":"<hidden>"/; s/"refreshToken":"[^"]*"/"refreshToken":"<hidden>"/')"
grep -E '^[<>*] (HTTP|Content-Length|Connected|SSL|TLS|upload|Expect|Done|Closing|Operation)' "$CACHE/t2.trace" | head -20 | while read -r line; do log "  $line"; done
rm -f "$CACHE/t2.trace"
log "done"
) > /dev/null 2>&1 &
