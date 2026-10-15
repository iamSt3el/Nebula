SECRET_DIR=${SECRET_DIR:-/var/local/nebula}
SECRET="$SECRET_DIR/miraie.conf"
TOKEN="$SECRET_DIR/miraie.token"
ACDEV="$SECRET_DIR/miraie.device"
ACD="$DIR/ac"
CA=/etc/ssl/certs/ca-certificates.crt
LOGIN_URL=https://auth.miraie.in/simplifi/v1/userManagement/login
HOMES_URL=https://app.miraie.in/simplifi/v1/homeManagement/homes
DEV_URL=https://app.miraie.in/simplifi/v1/deviceManagement/devices
CLIENT_ID=PBcMcfG19njNCL8AOgvRzIC8AjQa
FIFO=/tmp/nebula-ui
CKD="$DIR/clock"
SYSD="$DIR/sys"
. "$SYSD/layout.sh"
. "$ACD/layout.sh"
. "$CKD/layout.sh"

jget() {
    awk -v k="\"$1\"" '{ s = s $0 } END {
        i = index(s, k); if (!i) exit
        r = substr(s, i + length(k)); sub(/^[ \t]*:[ \t]*\[?[ \t]*/, "", r)
        if (substr(r, 1, 1) == "\"") { r = substr(r, 2); sub(/".*/, "", r) } else { sub(/[],} \t].*/, "", r) }
        print r }'
}

jesc() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

ac_setup() {
    if [ -s "$DIR/miraie.conf" ] && grep -q '^PASSWORD="..*"' "$DIR/miraie.conf"; then
        mkdir -p "$SECRET_DIR" && chmod 700 "$SECRET_DIR"
        cp "$DIR/miraie.conf" "$SECRET" && chmod 600 "$SECRET"
        printf 'PHONE="+91"\nPASSWORD=""\n' > "$DIR/miraie.conf"
        rm -f "$TOKEN" "$ACDEV"
        log "miraie: credentials moved to $SECRET_DIR"
    fi
    [ -s "$SECRET" ]
}

conf_value() {
    sed -n "s/^$1=\"\(.*\)\"[[:space:]]*\$/\1/p" "$SECRET" | head -n 1
}

ac_login() {
    PHONE=$(conf_value PHONE)
    EMAIL=$(conf_value EMAIL)
    PASSWORD=$(conf_value PASSWORD)
    user=${PHONE:-$EMAIL}
    log "miraie: logging in (${#user}-char id, ${#PASSWORD}-char password)"
    case "$user" in *@*) field=email ;; *) field=mobile ;; esac
    body="{\"clientId\":\"$CLIENT_ID\",\"$field\":\"$(jesc "$user")\",\"password\":\"$(jesc "$PASSWORD")\",\"scope\":\"an_14214235325\"}"
    resp=$(timeout 45 curl -sS -m 30 --connect-timeout 15 -H 'Content-Type: application/json' -d "$body" "$LOGIN_URL" 2> "$CACHE/curl.err")
    rc=$?
    tok=$(echo "$resp" | jget accessToken)
    if [ -z "$tok" ]; then
        log "miraie: login failed rc=$rc err=$(tr '\n' ' ' < "$CACHE/curl.err" | cut -c1-160) resp=$(echo "$resp" | cut -c1-160)"
        return 1
    fi
    exp=$(echo "$resp" | jget expiresIn | tr -cd '0-9')
    printf 'AC_TOKEN="%s"\nAC_EXP=%s\n' "$tok" $(( $(date +%s) + ${exp:-3600} - 300 )) > "$TOKEN"
    chmod 600 "$TOKEN"
    log "miraie: logged in"
}

ac_token() {
    AC_TOKEN="" AC_EXP=0
    [ -s "$TOKEN" ] && . "$TOKEN"
    if [ -z "$AC_TOKEN" ] || [ "$AC_EXP" -le "$(date +%s)" ]; then
        ac_login || return 1
        . "$TOKEN"
    fi
}

ac_discover() {
    [ -s "$ACDEV" ] && { . "$ACDEV"; return 0; }
    ac_token || return 1
    resp=$(timeout 45 curl -sS -m 30 --connect-timeout 15 -H "Authorization: Bearer $AC_TOKEN" "$HOMES_URL" 2>> "$LOG")
    did=$(echo "$resp" | jget deviceId)
    if [ -z "$did" ]; then
        log "miraie: no AC found: $(echo "$resp" | cut -c1-160)"
        return 1
    fi
    det=$(timeout 45 curl -sS -m 30 --connect-timeout 15 -H "Authorization: Bearer $AC_TOKEN" "$DEV_URL/deviceId/$did" 2>> "$LOG")
    printf 'AC_HOME="%s"\nAC_DEV="%s"\nAC_TOPIC="%s"\nAC_NAME="%s"\nAC_FW="%s"\n' \
        "$(echo "$resp" | jget homeId)" "$did" "$(echo "$resp" | jget topic)" \
        "$(echo "$resp" | jget deviceName)" "$(echo "$det" | jget firmwareVersion)" > "$ACDEV"
    . "$ACDEV"
    log "miraie: found $AC_NAME fw=$AC_FW"
}

room_temp() {
    awk -v v="$1" -v fw="$AC_FW" 'BEGIN {
        gsub(/[^0-9.]/, "", fw); split(fw, f, ".")
        packed = (f[1] + 0 > 3) || (f[1] + 0 == 3 && f[2] + 0 >= 2)
        if (v == "") { print "na"; exit }
        if (packed && index(v, ".")) { split(v, p, "."); if (length(p[2]) >= 2 && p[2] + 0 >= 5 && p[2] + 0 <= 60) { printf "%d\n", p[2] + p[1] / 256 + 0.5; exit } }
        printf "%d\n", v + 0.5 }'
}

ac_status() {
    if [ -n "$AC_MOCK" ]; then
        cat "$CACHE/mock.status" > "$CACHE/ac.json"
    else
        ac_token && ac_discover || { HEAD=login; return 1; }
        code=$(timeout 35 curl -sS -m 20 --connect-timeout 15 -o "$CACHE/ac.json" -w '%{http_code}' -H "Authorization: Bearer $AC_TOKEN" \
            "$DEV_URL/$AC_DEV/mobile/status" 2>> "$LOG")
        if [ "$code" = 401 ]; then
            rm -f "$TOKEN"
            ac_token || { HEAD=login; return 1; }
            code=$(timeout 35 curl -sS -m 20 --connect-timeout 15 -o "$CACHE/ac.json" -w '%{http_code}' -H "Authorization: Bearer $AC_TOKEN" \
                "$DEV_URL/$AC_DEV/mobile/status" 2>> "$LOG")
        fi
        [ "$code" = 200 ] || { HEAD=offline; log "miraie: status http $code"; return 1; }
    fi
    j=$(cat "$CACHE/ac.json")
    AC_PS=$(echo "$j" | jget ps)
    AC_MODE=$(echo "$j" | jget acmd)
    AC_TEMP=$(echo "$j" | jget actmp | awk '{ printf "%d", $1 + 0.5 }')
    AC_ROOM=$(room_temp "$(echo "$j" | jget rmtmp)")
    AC_FAN=$(echo "$j" | jget acfs)
    AC_VS=$(echo "$j" | jget acvs)
    AC_ECO=$(echo "$j" | jget acem)
    AC_DISP=$(echo "$j" | jget acdc)
    AC_PM=$(echo "$j" | jget acpm)
    AC_CLEAN=$(echo "$j" | jget acec)
    AC_NANOE=$(echo "$j" | jget acngs)
    [ -z "$AC_NANOE" ] && AC_NANOE=$(echo "$j" | jget acng)
    case "$AC_TEMP" in ''|*[!0-9]*) AC_TEMP=24 ;; esac
    AC_VS=$(echo "$AC_VS" | tr -cd '0-9')
    AC_ONLINE=$(echo "$j" | jget onlineStatus)
    HEAD=online
    [ "$AC_ONLINE" = "false" ] && HEAD=offline
    return 0
}

u8() {
    printf "\\$(printf '%03o' "$1")"
}

u16() {
    u8 $(($1 / 256))
    u8 $(($1 % 256))
}

mstr() {
    u16 ${#1}
    printf '%s' "$1"
}

mlen() {
    n=$1
    while :; do
        b=$((n % 128))
        n=$((n / 128))
        [ $n -gt 0 ] && b=$((b + 128))
        u8 $b
        [ $n -eq 0 ] && break
    done
}

mqtt_packets() {
    cid="nebula-kindle-$$"
    u8 16
    mlen $((10 + 2 + ${#cid} + 2 + ${#AC_HOME} + 2 + ${#AC_TOKEN}))
    u16 4
    printf 'MQTT'
    u8 4
    u8 194
    u16 60
    mstr "$cid"
    mstr "$AC_HOME"
    mstr "$AC_TOKEN"
    sleep 1
    topic="$AC_TOPIC/control"
    u8 48
    mlen $((2 + ${#topic} + ${#1}))
    mstr "$topic"
    printf '%s' "$1"
    sleep 1
    u8 224
    u8 0
    sleep 1
}

ac_send() {
    payload="{\"ki\":1,\"cnt\":\"an\",\"sid\":\"1\",$1}"
    if [ -n "$AC_MOCK" ]; then
        echo "$payload" >> "$CACHE/mock.sent"
        return 0
    fi
    ac_token && ac_discover || return 1
    mqtt_packets "$payload" | timeout 25 openssl s_client -quiet -connect mqtt.miraie.in:8883 \
        -servername mqtt.miraie.in -CAfile "$CA" > "$CACHE/mqtt.out" 2> "$CACHE/mqtt.err"
    ack=$(od -An -tx1 "$CACHE/mqtt.out" | tr -d ' \n' | cut -c1-8)
    if [ "$ack" != "20020000" ]; then
        log "miraie: send failed ack=$ack $(tail -n 2 "$CACHE/mqtt.err" | tr '\n' ' ')"
        return 1
    fi
    log "miraie: sent $1"
}

draw_region() {
    eval "cur=\$SHOWN_$1"
    [ "$cur" = "$2" ] && return 0
    sdir=${3:-$ACD}
    eval "set -- \$R_$1 \"$1\" \"$2\""
    $FB -q -b -g file="$sdir/$6.png",x=$1,y=$2 >/dev/null 2>&1
    eval "SHOWN_$5=\$6"
    DIRTY="$DIRTY $5"
}

flush_dirty() {
    for r in $DIRTY; do
        eval "set -- \$R_$r"
        case " ${CLEAN_REGIONS-khour kmin} " in
            *" $r "*) $FB -q -f -W GC16 -s top=$2,left=$1,width=$3,height=$4 >/dev/null 2>&1 ;;
            *) $FB -q -W GC16 -s top=$2,left=$1,width=$3,height=$4 >/dev/null 2>&1 ;;
        esac
    done
    DIRTY=""
}

pick() {
    v=$1
    shift
    for o in "$@"; do [ "$o" = "$v" ] && { echo "$v"; return; }; done
    echo none
}

render_ac() {
    pw=on
    [ "$AC_PS" = on ] || pw=off
    t=${AC_TEMP:-24}
    [ "$t" -lt 16 ] && t=16
    [ "$t" -gt 30 ] && t=30
    draw_region dial "dial-$pw-$t"
    r=$AC_ROOM
    case "$r" in ''|na|*[!0-9]*) r=na ;; *) { [ "$r" -lt 10 ] || [ "$r" -gt 45 ]; } && r=na ;; esac
    draw_region room "room-$r"
    o=${OUTSIDE:-na}
    case "$o" in ''|na|*[!0-9]*) o=na ;; *) [ "$o" -gt 50 ] && o=na ;; esac
    draw_region out "out-$o"
    if [ "$HEAD" = offline ] && [ "$AC_ONLINE" = false ]; then st=offline
    elif [ "$pw" = off ]; then st=off
    else st=$(pick "$AC_MODE" cool dry fan auto heat); [ "$st" = none ] && st=cool; fi
    draw_region power "power-$st"
    draw_region mode "mode-$pw-$(pick "$AC_MODE" cool dry fan auto)"
    draw_region fan "fan-$pw-$(pick "$AC_FAN" auto quiet low medium high)"
    [ "$AC_VS" = 0 ] && draw_region swing swing-on || draw_region swing swing-off
    [ "$AC_ECO" = on ] && draw_region eco eco-on || draw_region eco eco-off
    [ "$AC_DISP" = off ] && draw_region display display-off || draw_region display display-on
    [ "$AC_PM" = on ] && draw_region powerful powerful-on || draw_region powerful powerful-off
    [ "$AC_NANOE" = on ] && draw_region nanoe nanoe-on || draw_region nanoe nanoe-off
    [ "$AC_CLEAN" = on ] && draw_region clean clean-on || draw_region clean clean-off
    draw_region head "head-${HEAD:-online}"
    draw_sys
    flush_dirty
}

ac_full() {
    $FB -q -b -g file="$ACD/background.png",x=0,y=0 >/dev/null 2>&1
    for r in dial room out power mode fan swing eco display powerful nanoe clean head sys; do eval "SHOWN_$r="; done
    render_ac
    $FB -q -f -s >/dev/null 2>&1
    LAST_FLASH=$(date +%s)
}

hit() {
    for h in tab_ac tab_clock tab_frame minus plus power preset_cool preset_night swing eco display powerful nanoe clean \
        mode_cool mode_dry mode_fan mode_auto fan_auto fan_quiet fan_low fan_medium fan_high; do
        eval "set -- \$T_$h"
        if [ "$1" -le "$X" ] && [ "$X" -lt $(($1 + $3)) ] && [ "$2" -le "$Y" ] && [ "$Y" -lt $(($2 + $4)) ]; then
            echo "$h"
            return
        fi
    done
}

send_bg() {
    HEAD=busy
    render_ac
    ( ac_send "$1"; sleep 6; echo r ) >&3 &
}

on_tap() {
    X=$1 Y=$2
    h=$(hit)
    [ -z "$h" ] && return
    log "tap $X,$Y -> $h ($VIEW)"
    case "$h" in
        tab_ac) [ "$VIEW" != ac ] && show_ac; return ;;
        tab_clock) [ "$VIEW" != clock ] && show_clock; return ;;
        tab_frame) rest_enter frame; return ;;
    esac
    [ "$VIEW" = ac ] || return
    case "$h" in
        minus|plus)
            t=${AC_TEMP:-24}
            [ "$h" = plus ] && t=$((t + 1)) || t=$((t - 1))
            [ $t -lt 16 ] && t=16
            [ $t -gt 30 ] && t=30
            AC_TEMP=$t
            SEQ=$((SEQ + 1))
            render_ac
            ( sleep 2; echo "f $SEQ" ) >&3 & ;;
        power)
            [ "$AC_PS" = on ] && AC_PS=off || AC_PS=on
            send_bg "\"ps\":\"$AC_PS\"" ;;
        mode_*)
            AC_MODE=${h#mode_}
            send_bg "\"acmd\":\"$AC_MODE\"" ;;
        fan_*)
            AC_FAN=${h#fan_}
            send_bg "\"acfs\":\"$AC_FAN\"" ;;
        preset_cool)
            AC_PS=on AC_MODE=cool AC_TEMP=24 AC_FAN=auto
            send_bg '"ps":"on","acmd":"cool","actmp":"24","acfs":"auto"' ;;
        preset_night)
            AC_PS=on AC_MODE=cool AC_TEMP=26 AC_FAN=low
            send_bg '"ps":"on","acmd":"cool","actmp":"26","acfs":"low"' ;;
        swing)
            if [ "$AC_VS" = 0 ]; then AC_VS=1; else AC_VS=0; fi
            send_bg "\"acvs\":$AC_VS" ;;
        eco)
            if [ "$AC_ECO" = on ]; then
                AC_ECO=off
                send_bg '"acem":"off","acpm":"off","acec":"off","cnv":0'
            else
                AC_ECO=on AC_PM=off AC_CLEAN=off AC_TEMP=26
                send_bg '"acem":"on","acpm":"off","acec":"off","actmp":26.0,"cnv":0'
            fi ;;
        powerful)
            if [ "$AC_PM" = on ]; then
                AC_PM=off
                send_bg '"acem":"off","acpm":"off","acec":"off","cnv":0'
            else
                AC_PM=on AC_ECO=off AC_CLEAN=off
                send_bg '"acem":"off","acpm":"on","acec":"off","cnv":0'
            fi ;;
        clean)
            if [ "$AC_CLEAN" = on ]; then
                AC_CLEAN=off
                send_bg '"acem":"off","acpm":"off","acec":"off","cnv":0'
            else
                AC_CLEAN=on AC_ECO=off AC_PM=off
                send_bg '"acem":"off","acpm":"off","acec":"on","cnv":0'
            fi ;;
        display)
            [ "$AC_DISP" = off ] && AC_DISP=on || AC_DISP=off
            send_bg "\"acdc\":\"$AC_DISP\"" ;;
        nanoe)
            [ "$AC_NANOE" = on ] && AC_NANOE=off || AC_NANOE=on
            send_bg "\"acng\":\"$AC_NANOE\"" ;;
    esac
}

outside_temp() {
    fetch_weather > /dev/null 2>&1
    [ -s "$CACHE/weather.csv" ] || return 1
    eval "$(parse_weather)"
    OUTSIDE=$TEMP
    OUTSIDE_AT=$(date +%s)
    eval "set -- $(describe "$CODE" "$ISDAY")"
    case "$2" in
        sun) OUT_COND=sunny ;; moon) OUT_COND=clear ;; partly) OUT_COND=partly ;; cloud) OUT_COND=cloudy ;;
        fog|rain|snow|storm) OUT_COND=$2 ;; *) OUT_COND=na ;;
    esac
}

show_ac() {
    VIEW=ac
    ac_full
    ( echo r ) >&3 &
}

clock_full() {
    $FB -q -b -g file="$CKD/background.png",x=0,y=0 >/dev/null 2>&1
    for r in khour kmin kday khol koutv koutc sys; do eval "SHOWN_$r="; done
    render_clock
    $FB -q -f -s >/dev/null 2>&1
    LAST_FLASH=$(date +%s)
}

show_clock() {
    VIEW=clock
    clock_full
}

render_clock() {
    set -- $(date '+%H %M %Y%m%d')
    draw_region khour "hour-$1" "$CKD"
    draw_region kmin "min-$2" "$CKD"
    if [ -f "$CKD/day-$3.png" ]; then
        draw_region kday "day-$3" "$CKD"
        draw_region khol "hol-$3" "$CKD"
    else
        draw_region kday day-none "$CKD"
        draw_region khol hol-none "$CKD"
    fi
    o=${OUTSIDE:-na}
    case "$o" in ''|na|*[!0-9]*) o=na ;; *) [ "$o" -gt 50 ] && o=na ;; esac
    draw_region koutv "outv-$o" "$CKD"
    draw_region koutc "outc-${OUT_COND:-na}" "$CKD"
    draw_sys
    flush_dirty
}

draw_sys() {
    [ -n "$SYS_FRESH" ] || { sys_vals; SYS_FRESH=1; }
    b=$(( (SYS_B + 2) / 5 * 5 ))
    [ $b -gt 100 ] && b=100
    draw_region sys "sys-$SYS_W-$b-$SYS_C" "$SYSD"
}

wifi() {
    lipc-set-prop com.lab126.cmd wirelessEnable "$1" >/dev/null 2>&1
}

start_poller() {
    ( while :; do sleep 5; echo p; done ) >&3 &
    POLLER=$!
}

idle_face() {
    f=${1:-${IDLE_FACE:-auto}}
    case "$f" in
        auto|frame) [ -s "$DIR/frame.png" ] && echo frame || echo clock ;;
        *) echo "$f" ;;
    esac
}

pull_frame() {
    [ -n "$SERVER" ] || return 0
    lm="Thu, 01 Jan 1970 00:00:00 GMT"
    [ -s "$DIR/frame.png" ] && [ -s "$CACHE/frame.lm" ] && lm=$(cat "$CACHE/frame.lm")
    code=$(curl -sS --connect-timeout 3 -m 30 -D "$CACHE/frame.hdr" -o "$CACHE/frame.part" -w '%{http_code}' \
        -H "If-Modified-Since: $lm" "$SERVER/frame.png?rotate=$ROTATE" 2>/dev/null)
    if [ "$code" = 200 ] && [ -s "$CACHE/frame.part" ]; then
        mv "$CACHE/frame.part" "$DIR/frame.png"
        sed -n 's/^Last-Modified: *//p' "$CACHE/frame.hdr" | tr -d '\r' > "$CACHE/frame.lm"
        log "frame: new image from laptop"
    fi
    rm -f "$CACHE/frame.part" "$CACHE/frame.hdr"
}

rest_suspend() {
    if [ -n "$SUSPEND_CMD" ]; then eval "$SUSPEND_CMD"; else echo mem > /sys/power/state; fi
}

suspend_for() {
    for a in /sys/class/rtc/rtc*/wakealarm; do
        { echo 0 > "$a"; } 2>/dev/null
        [ "$1" -gt 0 ] && { echo "+$1" > "$a"; } 2>/dev/null
    done
    t0=$(date +%s)
    sync
    rest_suspend "$1" 2>/dev/null || return 2
    el=$(( $(date +%s) - t0 ))
    [ $el -lt 2 ] && return 2
    [ "$1" -gt 0 ] && [ $el -ge $(($1 - 2)) ] && return 0
    return 1
}

rest_nap() {
    n=0
    if [ "$VIEW" = clock ]; then
        s=$(date +%S)
        s=${s#0}
        n=$((60 - s))
        [ $n -lt 6 ] && n=$((n + 60))
    fi
    g=$REST_GEN
    if [ "${IDLE_MODE:-sleep}" = sleep ]; then
        a=0
        [ $n -gt 0 ] && a=$((n - 3))
        ( sleep 3; suspend_for $a; echo "s $g $?" ) >&3 &
    elif [ $n -gt 0 ]; then
        ( sleep $n; echo "s $g 0" ) >&3 &
    else
        NAPPER=""
        return
    fi
    NAPPER=$!
}

rest_enter() {
    [ "$RESTING" = 1 ] && return
    RESTING=1
    REST_GEN=$((REST_GEN + 1))
    [ "$VIEW" = frame ] || WAKE_VIEW=$VIEW
    [ -n "$POLLER" ] && kill "$POLLER" 2>/dev/null
    POLLER=""
    pull_frame
    face=$(idle_face "$1")
    wifi 0
    SYS_FRESH=""
    REST_SYNC_AT=$(date +%s)
    log "rest: $face face, ${IDLE_MODE:-sleep} mode"
    case "$face" in
        frame)
            VIEW=frame
            $FB -q -c -f -W GC16 -g file="$DIR/frame.png",x=0,y=0 >/dev/null 2>&1 ;;
        clock)
            VIEW=clock
            clock_full ;;
    esac
    rest_nap
}

rest_sync() {
    log "rest: sync"
    wifi 1
    wait_wifi
    outside_temp
    wifi 0
    REST_SYNC_AT=$(date +%s)
}

rest_tick() {
    if [ "$VIEW" = clock ]; then
        [ "${REST_SYNC:-3600}" -gt 0 ] && [ $(( $(date +%s) - REST_SYNC_AT )) -ge "${REST_SYNC:-3600}" ] && rest_sync
        SYS_FRESH=""
        render_clock
    fi
    rest_nap
}

rest_wake() {
    RESTING=0
    REST_GEN=$((REST_GEN + 1))
    [ -n "$NAPPER" ] && kill "$NAPPER" 2>/dev/null
    NAPPER=""
    log "wake: $1"
    wifi 1
    LAST_TAP=$(date +%s)
    SYS_FRESH=""
    VIEW=${WAKE_VIEW:-ac}
    full_view
    start_poller
    [ "$VIEW" = ac ] && ( wait_wifi; echo r ) >&3 &
    [ $((LAST_TAP - ${OUTSIDE_AT:-0})) -ge 900 ] && ( wait_wifi; outside_temp; echo o "$OUTSIDE" "$OUT_COND" ) >&3 &
}

render_view() {
    case "$VIEW" in
        ac) render_ac ;;
        clock) render_clock ;;
    esac
}

full_view() {
    case "$VIEW" in
        ac) ac_full ;;
        clock) clock_full ;;
    esac
}

ac_main() {
    rm -f "$FIFO"
    mkfifo "$FIFO"
    exec 3<> "$FIFO"
    log "ac: start"
    HEAD=busy AC_PS=off AC_TEMP=24
    [ "${START_VIEW:-ac}" = frame ] || ac_full
    log "ac: drawn placeholder"
    if [ -z "$TAPS_CMD" ]; then
        cp "$DIR/bin/taps" /tmp/nebula-taps && chmod 755 /tmp/nebula-taps
        TAPS_CMD=/tmp/nebula-taps
    fi
    ( $TAPS_CMD | while read -r x y ms; do echo "t $x $y $ms"; done ) >&3 &
    TAPPER=$!
    log "ac: taps reader $TAPPER"
    ( if ac_setup; then ac_status; else echo "login missing" > "$CACHE/ac.err"; fi; echo r ) >&3 &
    ( outside_temp; echo o "$OUTSIDE" "$OUT_COND" ) >&3 &
    drop_crash_dumps
    VIEW=${START_VIEW:-ac} SEQ=0 TICK=0 RESTING=0 REST_GEN=0 WAKE_VIEW=ac
    LAST_TAP=$(date +%s)
    if [ "$VIEW" = frame ]; then
        VIEW=ac
        rest_enter frame
    else
        start_poller
        [ "$VIEW" = ac ] || full_view
    fi
    while read -r kind a b c <&3; do
        if [ "$RESTING" = 1 ]; then
            case "$kind" in
                t)
                    [ "${c:-0}" -ge 1200 ] && cleanup
                    rest_wake tap ;;
                s)
                    [ "$a" = "$REST_GEN" ] || continue
                    case "$b" in
                        1) rest_wake button ;;
                        2) log "rest: suspend refused, holding instead"; IDLE_MODE=hold; rest_nap ;;
                        *) rest_tick ;;
                    esac ;;
                o)
                    [ -n "$a" ] && OUTSIDE=$a OUTSIDE_AT=$(date +%s)
                    [ -n "$b" ] && OUT_COND=$b ;;
                q)
                    break ;;
            esac
            continue
        fi
        case "$kind" in
            t)
                [ "${c:-0}" -ge 1200 ] && cleanup
                LAST_TAP=$(date +%s)
                on_tap "$a" "$b" ;;
            f)
                [ "$a" = "$SEQ" ] && send_bg "\"actmp\":\"$AC_TEMP\"" ;;
            r)
                ac_status; render_view ;;
            o)
                [ -n "$a" ] && OUTSIDE=$a OUTSIDE_AT=$(date +%s)
                [ -n "$b" ] && OUT_COND=$b
                render_view ;;
            p)
                TICK=$((TICK + 1))
                now=$(date +%s)
                if [ "${IDLE_AFTER:-120}" -gt 0 ] && [ $((now - LAST_TAP)) -ge "${IDLE_AFTER:-120}" ]; then
                    rest_enter
                    continue
                fi
                [ $((TICK % 12)) -eq 0 ] && SYS_FRESH=""
                [ $((TICK % 180)) -eq 0 ] && outside_temp
                [ "$VIEW" = ac ] && [ $((TICK % 6)) -eq 0 ] && ac_status
                if [ $((now - ${LAST_FLASH:-0})) -ge "${FLASH_EVERY:-600}" ]; then full_view; else render_view; fi ;;
            q)
                break ;;
        esac
    done
}
