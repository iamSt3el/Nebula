import QtQuick
import qs.modules.services

BarStatItem {
    id: root

    readonly property string direction: BarLayout.opt(root.itemId, "direction") ?? "both"
    readonly property string down: "↓ " + ServiceSystemInfo.formatNetSpeed(ServiceSystemInfo.netDownloadBps)
    readonly property string up: "↑ " + ServiceSystemInfo.formatNetSpeed(ServiceSystemInfo.netUploadBps)

    widthTemplate: root.direction === "both" ? "↓ 1023.9 KB/s  ↑ 1023.9 KB/s" : "↓ 1023.9 KB/s"
    icon: "swap_vert"
    label: root.direction === "down" ? root.down : root.direction === "up" ? root.up : root.down + "  " + root.up
    tip: root.down + "   " + root.up
    compactLabel: ServiceSystemInfo.formatNetSpeed(root.direction === "up" ? ServiceSystemInfo.netUploadBps : ServiceSystemInfo.netDownloadBps)
        .replace(" KB/s", "K").replace(" MB/s", "M").replace(" GB/s", "G").replace(" B/s", "")
}
