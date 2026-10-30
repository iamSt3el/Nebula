import QtQuick
import qs.modules.services

BarStatItem {
    widthTemplate: "100%"
    icon: "memory"
    defaultShape: "cookie12"
    panelKind: "cpu"
    value: ServiceSystemInfo.cpuUsage
    label: Math.round(ServiceSystemInfo.cpuUsage * 100) + "%"
    tip: "CPU " + Math.round(ServiceSystemInfo.cpuUsage * 100) + "%"
}
