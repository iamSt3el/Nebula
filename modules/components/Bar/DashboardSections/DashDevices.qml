import QtQuick
import Quickshell.Services.UPower
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services

DashItem {
    id: root

    card: true

    function iconFor(name) {
        const n = (name ?? "").toLowerCase()
        if (n.includes("headset") || n.includes("headphone")) return "headphones"
        if (n.includes("mouse")) return "mouse"
        if (n.includes("keyboard")) return "keyboard"
        if (n.includes("phone")) return "smartphone"
        if (n.includes("gamepad") || n.includes("joystick")) return "sports_esports"
        if (n.includes("audio") || n.includes("speaker")) return "speaker"
        if (n.includes("watch")) return "watch"
        return "bluetooth"
    }

    readonly property var entries: {
        const out = []
        if (UPower.displayDevice.isLaptopBattery)
            out.push({ name: "This laptop", icon: "laptop", level: ServiceUPower.powerLevel, charging: ServiceUPower.isCharging })
        for (const d of ServiceBluetooth.connectedDevicesList) {
            if (d.batteryAvailable)
                out.push({ name: d.name, icon: root.iconFor(d.icon), level: d.battery, charging: false })
        }
        if (ServicePhone.ready && ServicePhone.battery >= 0)
            out.push({ name: ServicePhone.name || "Phone", icon: "smartphone",
                       level: ServicePhone.battery / 100, charging: ServicePhone.charging })
        return out
    }

    readonly property int fits: Math.max(1, Math.floor((root.width - 20) / 84))
    readonly property var shown: root.entries.slice(0, root.fits)
    readonly property real ring: Math.max(34, Math.min(62, root.height - 44))

    Row {
        anchors.centerIn: parent
        visible: root.shown.length > 0
        spacing: root.shown.length > 1 ? Math.min(40, (root.width - 20 - root.shown.length * root.ring) / root.shown.length) : 0

        Repeater {
            model: root.shown

            delegate: Column {
                id: dev
                required property var modelData
                spacing: 6

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.ring
                    height: root.ring

                    MeterSegmentRing {
                        anchors.fill: parent
                        segments: 10
                        gapDegrees: 8
                        thickness: Math.max(4, root.ring * 0.12)
                        value: dev.modelData.level
                        color: dev.modelData.level < 0.2 ? Colors.error
                            : dev.modelData.level < 0.35 ? Colors.tertiary : Colors.primary
                        fillColor: Qt.tint(Colors.surfaceContainerHighest, Qt.alpha(color, 0.6))
                    }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: dev.modelData.charging ? "bolt" : dev.modelData.icon
                        iconSize: root.ring * 0.4
                        customColor: Colors.surfaceText
                    }
                }

                CustomText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    content: Math.round(dev.modelData.level * 100) + "%"
                    size: 12
                    weight: 700
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        visible: root.shown.length === 0
        spacing: 6
        MaterialIconSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            content: "battery_unknown"
            iconSize: 24
            customColor: Colors.outline
        }
        CustomText {
            anchors.horizontalCenter: parent.horizontalCenter
            content: "No devices report a battery"
            size: 12
            weight: 500
            customColor: Colors.outline
        }
    }
}
