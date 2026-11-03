#!/bin/sh
DIR=${DASH_DIR:-/mnt/us/nebula-dash}
. "$DIR/config.sh"
[ -n "$NEBULA_VIEW" ] && PAGE=ac START_VIEW=$NEBULA_VIEW
. "$DIR/place.sh"
. "$DIR/layout.sh"
FB=${FB:-/var/local/kmc/bin/fbink}
FD="$DIR/fonts"
LOG="$DIR/dash.log"
CACHE="$DIR/cache"
PIDFILE=/tmp/nebula-dash.pid
MARK=/tmp/nebula-dash.mark
DRAW=/tmp/nebula-dash.draw
mkdir -p "$CACHE"

log() {
    echo "$(date '+%F %T') $*" >> "$LOG"
}

if [ -z "$DASH_DRYRUN" ] && [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    exit 0
fi
echo $$ > "$PIDFILE"
touch "$MARK"

WATCHER=""
cleanup() {
    [ -n "$WATCHER" ] && kill "$WATCHER" 2>/dev/null
    [ -n "$POLLER" ] && kill "$POLLER" 2>/dev/null
    [ -n "$TAPPER" ] && kill "$TAPPER" 2>/dev/null
    [ -n "$NAPPER" ] && kill "$NAPPER" 2>/dev/null
    for a in /sys/class/rtc/rtc*/wakealarm; do { echo 0 > "$a"; } 2>/dev/null; done
    lipc-set-prop com.lab126.cmd wirelessEnable 1
    killall taps nebula-taps 2>/dev/null
    $FB -q -m -M -t "regular=$FD/Rubik-Medium.ttf,px=24" "Back to the library…" >/dev/null 2>&1
    lipc-set-prop com.lab126.powerd preventScreenSaver 0
    lipc-set-prop com.lab126.pillow disableEnablePillow enable
    start statusbar 2>/dev/null
    rm -f "$PIDFILE" "$DRAW"
    log "exit"
    drop_crash_dumps
    start framework
    exit 0
}

drop_crash_dumps() {
    find /mnt/us/documents -maxdepth 1 -name 'KPPMainApp*crash*' -newer "$MARK" -exec rm -rf {} \; 2>/dev/null
}

wait_wifi() {
    i=0
    while [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" != "CONNECTED" ] && [ $i -lt 45 ]; do
        sleep 1
        i=$((i + 1))
    done
}

UNITQ=""
[ "$UNITS" = "imperial" ] && UNITQ="&temperature_unit=fahrenheit&wind_speed_unit=mph"
WURL="https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,uv_index,is_day&hourly=temperature_2m,precipitation_probability&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&timezone=auto&forecast_days=3&format=csv$UNITQ"

fetch_weather() {
    [ "$LAT" = 0 ] && [ "$LON" = 0 ] && return 1
    if curl -fsS -m 30 -o "$CACHE/weather.part" "$WURL" 2>> "$LOG"; then
        mv "$CACHE/weather.part" "$CACHE/weather.csv"
        date +%H:%M > "$CACHE/weather.stamp"
        return 0
    fi
    rm -f "$CACHE/weather.part"
    return 1
}

parse_weather() {
    awk -F, '
    function r(x) { return x < 0 ? int(x - 0.5) : int(x + 0.5) }
    function hdr(   i, n) {
        delete col
        for (i = 1; i <= NF; i++) { n = $i; sub(/ \(.*/, "", n); col[n] = i }
    }
    /^time,/ {
        hdr()
        sec = ("is_day" in col) ? "cur" : ("precipitation_probability" in col) ? "hour" : ("sunrise" in col) ? "day" : ""
        next
    }
    NF < 2 { next }
    sec == "cur" {
        now = $col["time"]
        printf "NOW=%s\nTEMP=%d\nFEELS=%d\nHUM=%d\nCODE=%d\nWIND=%d\nUV=%d\nISDAY=%d\n", now, r($col["temperature_2m"]), r($col["apparent_temperature"]), r($col["relative_humidity_2m"]), $col["weather_code"], r($col["wind_speed_10m"]), r($col["uv_index"]), $col["is_day"]
        today = substr(now, 1, 10); nowh = substr(now, 12, 2) + 0
        next
    }
    sec == "hour" {
        t = $col["time"]
        if (substr(t, 1, 10) != today) next
        h = substr(t, 12, 2) + 0
        if (h % 3 == 0) printf "H_%d=%d\n", h / 3, r($col["temperature_2m"])
        if (h == nowh) printf "RAIN=%d\n", r($col["precipitation_probability"])
        next
    }
    sec == "day" {
        printf "D%d_DATE=%s\nD%d_CODE=%d\nD%d_HI=%d\nD%d_LO=%d\nD%d_RISE=%s\nD%d_SET=%s\n", d, $col["time"], d, $col["weather_code"], d, r($col["temperature_2m_max"]), d, r($col["temperature_2m_min"]), d, substr($col["sunrise"], 12, 5), d, substr($col["sunset"], 12, 5)
        d++
    }
    ' "$CACHE/weather.csv" | tr -d '\r'
}

fetch_holidays() {
    [ "$(cat "$CACHE/holidays.day" 2>/dev/null)" = "$1" ] && [ -s "$CACHE/holidays.txt" ] && return 0
    [ -n "$ICS" ] || return 1
    curl -fsS -m 40 -o "$CACHE/holidays.part" "$ICS" 2>> "$LOG" || { rm -f "$CACHE/holidays.part"; return 1; }
    tr -d '\r' < "$CACHE/holidays.part" | awk '
    /^[ \t]/ { line = line substr($0, 2); next }
    { if (line != "") emit(line); line = $0 }
    END { if (line != "") emit(line) }
    function emit(l,   v) {
        if (l ~ /^BEGIN:VEVENT/) { ds = ""; sm = "" }
        else if (l ~ /^DTSTART/) { v = l; sub(/^[^:]*:/, "", v); ds = substr(v, 1, 8) }
        else if (l ~ /^SUMMARY/) { v = l; sub(/^[^:]*:/, "", v); gsub(/\\,/, ",", v); gsub(/\\;/, ";", v); gsub(/\\n/, " ", v); sm = v }
        else if (l ~ /^END:VEVENT/ && ds != "" && sm != "") print ds "|" sm
    }' | sort -u > "$CACHE/holidays.txt"
    rm -f "$CACHE/holidays.part"
    echo "$1" > "$CACHE/holidays.day"
}

describe() {
    case "$1" in
        0) [ "$2" = 1 ] && echo "Sunny sun" || echo "Clear moon" ;;
        1) [ "$2" = 1 ] && echo "Mostly_sunny partly" || echo "Mostly_clear moon" ;;
        2) echo "Partly_cloudy partly" ;;
        3) echo "Cloudy cloud" ;;
        45|48) echo "Fog fog" ;;
        51|53|55|56|57) echo "Drizzle rain" ;;
        61|80) echo "Light_rain rain" ;;
        63|66|81) echo "Rain rain" ;;
        65|67|82) echo "Heavy_rain rain" ;;
        71|73|75|77|85|86) echo "Snow snow" ;;
        95|96|99) echo "Thunderstorm storm" ;;
        *) echo "– cloud" ;;
    esac
}

measure() {
    out=$($FB -E -b -T -t "regular=$FD/$2.ttf,px=$1,top=0,left=0" "$3" 2>/dev/null)
    w=$(echo "$out" | sed -n 's/.*lastRect_Width=\([0-9]*\).*/\1/p' | head -n 1)
    [ -n "$w" ] && echo "$w" || echo $(( ${#3} * $1 * 11 / 20 ))
}

queue() {
    printf '%s|%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$DRAW"
}

slot() {
    eval "set -- \$S_$1 \"\$2\""
    x=$1 y=$2 px=$4 font=$5 color=$6 align=$7 text=$8
    case "$align" in
        right) x=$((x - $(measure "$px" "$font" "$text"))) ;;
        center) x=$((x - $(measure "$px" "$font" "$text") / 2)) ;;
    esac
    SLOT_X=$x
    queue "$x" "$y" "$px" "$font" "$color" "$text"
}

hm() {
    echo "$1" | awk -F: '{ print ($1 + 0) * 60 + ($2 + 0) }'
}

compose() {
    : > "$DRAW"
    $FB -q -b -k >/dev/null 2>&1

    D0="${NOW%%T*}"
    eval "set -- $(describe "$CODE" "$ISDAY")"
    DESC=$(echo "$1" | tr '_' ' ')
    ICON=$2

    day=$(( $(date -d "$D0" +%d | sed 's/^0*//') + 0 ))
    slot weekday "$(date -d "$D0" +%A)"
    slot longdate "$day $(date -d "$D0" +%B) $(date -d "$D0" +%Y)"
    slot place "$PLACE"
    batt=$(lipc-get-prop com.lab126.powerd battLevel 2>/dev/null)
    slot stamp "$STAMP · $batt%"
    slot temp "$TEMP°"
    slot desc "$DESC"
    slot feels "feels $FEELS°"
    slot hilo "$D0_HI° / $D0_LO°"
    slot humidity "$HUM%"
    slot wind "$WIND"
    wx=$SLOT_X
    ww=$(measure "$(set -- $S_wind; echo "$4")" "$(set -- $S_wind; echo "$5")" "$WIND")
    set -- $S_windunit
    queue $((wx + ww + 6)) "$2" "$4" "$5" "$6" "$([ "$UNITS" = imperial ] && echo mph || echo km/h)"
    slot uv "$UV"
    slot rain "${RAIN:-0}%"

    lo=999; hi=-999; i=0
    while [ $i -lt 8 ]; do
        eval "t=\${H_$i:-0}"
        [ "$t" -lt "$lo" ] && lo=$t
        [ "$t" -gt "$hi" ] && hi=$t
        i=$((i + 1))
    done
    lo=$((lo - 4)); hi=$((hi + 1)); span=$((hi - lo)); [ $span -lt 1 ] && span=1
    cur=$(( $(hm "${NOW#*T}") / 180 ))
    BARS=""
    i=0
    while [ $i -lt 8 ]; do
        eval "t=\${H_$i:-0}; set -- \$C_$i"
        bx=$1 bottom=$2 bw=$3
        bh=$(( BAR_BASE + (t - lo) * BAR_SPAN / span ))
        fill="#999999"; [ $i -eq $cur ] && fill="#000000"
        BARS="$BARS $bx,$((bottom - bh)),$bw,$bh,$fill"
        set -- $(eval echo "\$S_bart$i")
        th=$3
        S_tmp="$((bx + bw / 2)) $((bottom - bh - BAR_GAP - th)) $th $4 $5 $6 center"
        eval "S_bartdyn$i=\"\$S_tmp\""
        slot "bartdyn$i" "$t°"
        i=$((i + 1))
    done

    slot sunrise "$D0_RISE"
    slot sunset "$D0_SET"
    dl=$(( $(hm "$D0_SET") - $(hm "$D0_RISE") ))
    slot daylight "$((dl / 60)) h $(printf '%02d' $((dl % 60))) m light"

    for n in 1 2; do
        eval "dd=\$D${n}_DATE dc=\$D${n}_CODE dh=\$D${n}_HI dlo=\$D${n}_LO"
        eval "set -- $(describe "$dc" 1)"
        slot "d${n}name" "$(date -d "$dd" +%A)"
        slot "d${n}desc" "$(echo "$1" | tr '_' ' ')"
        slot "d${n}lo" "$dlo°"
        lox=$SLOT_X
        eval "set -- \$S_d${n}hi"
        hw=$(measure "$4" "$5" "$dh°")
        queue $((lox - 6 - hw)) "$2" "$4" "$5" "$6" "$dh°"
    done

    HOL=""
    tstamp=$(echo "$D0" | tr -d '-')
    [ -s "$CACHE/holidays.txt" ] && HOL=$(awk -F'|' -v t="$tstamp" '$1 >= t { print; exit }' "$CACHE/holidays.txt")
    if [ -n "$HOL" ]; then
        hd=${HOL%%|*}; hname=${HOL#*|}
        hiso="$(echo "$hd" | cut -c1-4)-$(echo "$hd" | cut -c5-6)-$(echo "$hd" | cut -c7-8)"
        diff=$(( ($(date -d "$hiso" +%s) - $(date -d "$D0" +%s)) / 86400 ))
        if [ $diff -le 0 ]; then when="Today"; elif [ $diff -eq 1 ]; then when="Tomorrow"
        else when="$(date -d "$hiso" +%a) $(date -d "$hiso" +%d | sed 's/^0//') $(date -d "$hiso" +%b)"; fi
        slot when "$when"
        set -- $S_when
        wl=$(measure "$4" "$5" "$when")
        set -- $S_hname
        queue $((SLOT_X + wl + 10)) "$2" "$4" "$5" "$6" "$hname"
    else
        set -- $S_footer
        HIDE_FOOTER="$1,$2,$3,$4"
    fi
}

paint() {
    $FB -q -b -g file="$DIR/template.png",x=0,y=0 >/dev/null 2>&1
    [ -n "$HIDE_FOOTER" ] && { IFS=, read fx fy fw fh <<EOF
$HIDE_FOOTER
EOF
        $FB -q -b -B WHITE -k top=$fy,left=$fx,width=$fw,height=$fh >/dev/null 2>&1; }
    set -- $S_icon
    $FB -q -b -g file="$DIR/icons/$ICON.png",x=$1,y=$2 >/dev/null 2>&1
    for b in $BARS; do
        IFS=, read bx by bw bh fill <<EOF
$b
EOF
        $FB -q -b -B "$fill" -k top=$by,left=$bx,width=$bw,height=$bh >/dev/null 2>&1
    done
    while IFS='|' read -r x y px font color text; do
        under=WHITE
        [ "$color" = "#FFFFFF" ] && under=BLACK
        $FB -q -b -O -C "$color" -B "$under" -t "regular=$FD/$font.ttf,px=$px,top=$y,left=$x" "$text" >/dev/null 2>&1
    done < "$DRAW"
    $FB -q -f -s >/dev/null 2>&1
}

sys_vals() {
    SYS_B=$(lipc-get-prop com.lab126.powerd battLevel 2>/dev/null | tr -cd '0-9')
    [ -z "$SYS_B" ] && SYS_B=0
    SYS_C=$(lipc-get-prop com.lab126.powerd isCharging 2>/dev/null | tr -cd '0-9')
    [ "$SYS_C" = 1 ] || SYS_C=0
    SYS_W=off
    if [ "$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)" = CONNECTED ]; then
        q=$(awk '/wlan0/ { gsub(/\./, "", $3); print $3 + 0 }' /proc/net/wireless 2>/dev/null)
        if [ -z "$q" ] || [ "$q" -ge 50 ]; then SYS_W=3; elif [ "$q" -ge 30 ]; then SYS_W=2; else SYS_W=1; fi
    fi
}

cycle() {
    wait_wifi
    if fetch_weather; then STAMP="updated $(cat "$CACHE/weather.stamp")"
    else STAMP="offline · $(cat "$CACHE/weather.stamp" 2>/dev/null)"; fi
    [ -s "$CACHE/weather.csv" ] || { log "no weather yet"; return 1; }
    eval "$(parse_weather)"
    fetch_holidays "${NOW%%T*}"
    HIDE_FOOTER=""
    compose
    paint
    drop_crash_dumps
    log "drawn $STAMP temp=$TEMP code=$CODE hol=${HOL%%|*}"
}

nap() {
    if [ "$SUSPEND" = 1 ]; then
        rtcwake -d /dev/rtc1 -m no -s "$INTERVAL" >/dev/null 2>&1
        echo mem > /sys/power/state
        sleep 3
    else
        sleep "$INTERVAL" &
        wait $!
    fi
}

if [ "$DASH_DRYRUN" = ac ]; then
    . "$DIR/ac.sh"
    ac_main
    exit 0
fi

if [ -n "$DASH_DRYRUN" ]; then
    fetch_weather
    eval "$(parse_weather)"
    fetch_holidays "${NOW%%T*}"
    STAMP="updated $(date +%H:%M)"
    compose
    paint
    exit 0
fi

tail -n 300 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
log "start"
trap cleanup INT TERM HUP
sleep 4
lipc-set-prop com.lab126.pillow disableEnablePillow disable
stop statusbar 2>/dev/null
stop framework
sleep 3
lipc-set-prop com.lab126.powerd preventScreenSaver 1
MAIN=$$
if [ "$PAGE" = ac ]; then
    . "$DIR/ac.sh"
    ac_main
    cleanup
fi
cycle
(
    sleep 2
    dd if=/dev/input/event0 of=/dev/null bs=16 count=1 2>/dev/null
    log "tap"
    kill -TERM "$MAIN"
) &
WATCHER=$!
while :; do
    nap
    cycle
done
