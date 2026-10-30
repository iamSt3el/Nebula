import QtQuick
import Quickshell.Io

Item {
    id: link

    property string iface: ""
    property string connection: ""
    property bool wifi: false
    property bool active: false
    property int interval: 3000

    property var info: ({})
    property var ap: []

    readonly property string ipv4: link.first("IP4.ADDRESS")
    readonly property string ipv6: (link.values("IP6.ADDRESS").find(a => !a.startsWith("fe80")) ?? "").split("/")[0]
    readonly property string gateway: link.first("IP4.GATEWAY")
    readonly property string dns: link.values("IP4.DNS").join(", ")
    readonly property string mac: link.first("GENERAL.HWADDR")
    readonly property string mtu: link.first("GENERAL.MTU")
    readonly property string speed: {
        const mb = parseInt(link.first("SPEED")) || 0
        return mb <= 0 ? "" : mb >= 1000 ? (mb / 1000) + " Gbit/s" : mb + " Mbit/s"
    }
    readonly property int metric: parseInt(link.first("METRIC")) || 0
    readonly property real rx: parseFloat(link.first("RX")) || 0
    readonly property real tx: parseFloat(link.first("TX")) || 0
    readonly property bool autoconnect: link.first("connection.autoconnect") !== "no"
    readonly property string metered: link.first("connection.metered")
    readonly property int routeMetric: parseInt(link.first("ipv4.route-metric")) || -1
    readonly property string channel: link.ap[1] ?? ""
    readonly property string freq: link.ap[2] ?? ""
    readonly property string rate: link.ap[3] ?? ""
    readonly property string security: link.ap[5] ?? ""
    readonly property string bssid: link.ap[6] ?? ""

    function first(key) {
        return (link.info[key] ?? [])[0] ?? ""
    }

    function values(key) {
        return link.info[key] ?? []
    }

    function unquote(v) {
        return v.replace(/\\:/g, ":").replace(/\\\\/g, "\\")
    }

    function parse(text) {
        const res = {}
        let fields = []
        for (const raw of text.split("\n")) {
            const at = raw.indexOf(":")
            if (at <= 0)
                continue
            const key = raw.slice(0, at).replace(/\[\d+\]$/, "")
            const value = raw.slice(at + 1)
            if (key === "AP") {
                fields = value.replace(/\\:/g, "\u0001").split(":").map(f => f.replace(/\u0001/g, ":"))
                continue
            }
            if (value === "" || value === "--")
                continue
            if (!res[key])
                res[key] = []
            res[key].push(link.unquote(value))
        }
        link.info = res
        link.ap = fields
    }

    function refresh() {
        if (proc.running || link.iface === "")
            return
        proc.running = true
    }

    function report() {
        const rows = [
            ["Interface", link.iface], ["IPv4", link.ipv4], ["IPv6", link.ipv6], ["Gateway", link.gateway],
            ["DNS", link.dns], ["MAC", link.mac], ["Speed", link.speed || link.rate]
        ]
        return rows.filter(r => r[1] !== "").map(r => r[0] + ": " + r[1]).join("\n")
    }

    onIfaceChanged: link.refresh()
    onConnectionChanged: link.refresh()

    Timer {
        interval: link.interval
        repeat: true
        running: link.active && link.iface !== ""
        triggeredOnStart: true
        onTriggered: link.refresh()
    }

    Process {
        id: proc
        command: ["sh", "-c",
            "nmcli -t dev show \"$1\" 2>/dev/null; "
            + "echo \"SPEED:$(cat /sys/class/net/$1/speed 2>/dev/null)\"; "
            + "echo \"RX:$(cat /sys/class/net/$1/statistics/rx_bytes 2>/dev/null)\"; "
            + "echo \"TX:$(cat /sys/class/net/$1/statistics/tx_bytes 2>/dev/null)\"; "
            + "echo \"METRIC:$(ip -o route show default dev \"$1\" 2>/dev/null | sed -n 's/.* metric \\([0-9]*\\).*/\\1/p' | head -n1)\"; "
            + "c=\"${2:-$(nmcli -g GENERAL.CONNECTION dev show \"$1\" 2>/dev/null)}\"; "
            + "[ -n \"$c\" ] && nmcli -t -f connection.autoconnect,connection.metered,ipv4.route-metric connection show id \"$c\" 2>/dev/null; "
            + "[ \"$3\" = 1 ] && nmcli -t -f ACTIVE,CHAN,FREQ,RATE,SIGNAL,SECURITY,BSSID dev wifi list ifname \"$1\" --rescan no 2>/dev/null | sed -n 's/^yes:/AP:yes:/p' | head -n1; true",
            "sh", link.iface, link.connection, link.wifi ? "1" : "0"]
        stdout: StdioCollector {
            id: out
            onStreamFinished: link.parse(out.text)
        }
    }
}
