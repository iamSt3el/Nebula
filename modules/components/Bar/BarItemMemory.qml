import QtQuick
import qs.modules.services

BarStatItem {
    widthTemplate: "100%"
    icon: "memory_alt"
    defaultShape: "cookie9"
    value: ServiceSystemInfo.memUsage
    label: Math.round(ServiceSystemInfo.memUsage * 100) + "%"
    tip: "Memory " + ServiceSystemInfo.memUsedGb.toFixed(1) + " / " + ServiceSystemInfo.memTotalGb.toFixed(1) + " GB"
}
