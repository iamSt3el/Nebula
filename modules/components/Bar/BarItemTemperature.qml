import QtQuick
import qs.modules.services

BarStatItem {
    widthTemplate: "100°"
    icon: "device_thermostat"
    defaultShape: "sunny"
    value: ServiceSystemInfo.cpuTemp / 100
    label: Math.round(ServiceSystemInfo.cpuTemp) + "°"
    tip: "CPU " + Math.round(ServiceSystemInfo.cpuTemp) + " °C"
}
