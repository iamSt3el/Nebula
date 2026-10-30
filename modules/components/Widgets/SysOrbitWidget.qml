import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "sysOrbit"
    tile: WidgetSizes.large
    defaultPos: Qt.point(1355, 55)

    readonly property var si: root.preview ? PreviewData : ServiceSystemInfo
    Component.onCompleted: {
        root.si.retain()
        root.si.getUptime()
    }
    Component.onDestruction: root.si.release()

    Timer {
        interval: 60000
        repeat: true
        running: !root.preview && root.visible
        onTriggered: root.si.getUptime()
    }

    readonly property string display: SettingsConfig.general?.displayFont || "Titan One"
    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: root.preview || (root.dev?.isLaptopBattery ?? false)
    readonly property real battery: root.preview ? 0.82 : (root.dev?.percentage ?? 0)
    readonly property bool charging: root.preview || ServiceUPower.isCharging
    readonly property int rpm: (root.si.fanRpms ?? [])[0] ?? 0
    readonly property string uptime: String(root.si.uptime ?? "")
        .replace(/\s*weeks?/, "w").replace(/\s*days?/, "d").replace(/\s+/g, " ").trim().toUpperCase()

    function short(bps) {
        if (bps >= 1024 * 1024) return (bps / (1024 * 1024)).toFixed(1) + "M"
        if (bps >= 1024) return Math.round(bps / 1024) + "K"
        return Math.round(bps) + "B"
    }

    readonly property var rings: [
        { name: "CPU", value: root.si.cpuUsage, tone: Colors.primary, r: 112, w: 8, wave: 3 },
        { name: "RAM", value: root.si.memUsage, tone: Colors.tertiary, r: 95, w: 9, wave: 0 },
        { name: "GPU", value: root.si.gpuUsage, tone: Colors.secondary, r: 79, w: 9, wave: 0 },
        { name: "Disk", value: root.si.diskUsage, tone: Colors.outline, r: 63, w: 9, wave: 0 }
    ]

    WidgetCard {
        id: card
        anchors.fill: parent

        Item {
            id: orbit
            anchors.fill: parent
            readonly property real k: width / 310
            readonly property real cy: 140 * k

            Repeater {
                model: 4
                SysArc {
                    required property int index
                    readonly property var ring: root.rings[index]
                    anchors.fill: parent
                    cy: orbit.cy
                    radius: ring.r * orbit.k
                    value: ring.value
                    thickness: ring.w
                    wave: ring.wave
                    waves: 30
                    color: ring.value > 0.9 ? Colors.error : ring.tone
                    trackColor: Colors.surfaceContainerHigh
                }
            }

            ColumnLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(orbit.cy - 28 * orbit.k)
                spacing: 3

                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: Math.round(root.si.cpuTemp) + "°"
                    size: 34
                    family: root.display
                    customColor: root.si.cpuTemp >= 85 ? Colors.error : Colors.surfaceText
                }
                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: root.uptime === "" ? "CPU" : "CPU · UP " + root.uptime
                    size: 10
                    weight: 600
                    font.letterSpacing: 0.6
                    customColor: Colors.surfaceVariantText
                }
            }

            Column {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 4
                Chip {
                    visible: root.hasBattery
                    icon: root.charging ? "bolt" : "battery_full"
                    text: Math.round(root.battery * 100) + "%"
                    tone: root.battery <= 0.2 && !root.charging ? Colors.error : Colors.primary
                }
                Chip {
                    visible: root.rpm > 0
                    icon: "mode_fan"
                    text: String(root.rpm)
                    tone: Colors.surfaceVariantText
                }
            }

            Column {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 4
                Chip {
                    anchors.right: parent.right
                    icon: "south"
                    text: root.short(root.si.netDownloadBps)
                    tone: Colors.primary
                }
                Chip {
                    anchors.right: parent.right
                    icon: "north"
                    text: root.short(root.si.netUploadBps)
                    tone: Colors.tertiary
                }
            }

            RowLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                spacing: 14

                Repeater {
                    model: 4
                    RowLayout {
                        required property int index
                        readonly property var ring: root.rings[index]
                        spacing: 4
                        Rectangle {
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: 4
                            color: ring.tone
                        }
                        CustomText {
                            content: ring.name
                            size: 11
                            customColor: Colors.surfaceVariantText
                        }
                        CustomText {
                            content: Math.round(ring.value * 100) + "%"
                            size: 11
                            weight: 600
                        }
                    }
                }
            }
        }
    }

    component Chip: Rectangle {
        id: chip
        property string icon
        property string text
        property color tone
        implicitWidth: chipRow.implicitWidth + 15
        implicitHeight: 24
        radius: 12
        color: Colors.surfaceContainerHigh

        RowLayout {
            id: chipRow
            anchors.verticalCenter: parent.verticalCenter
            x: 6
            spacing: 3
            MaterialIconSymbol {
                content: chip.icon
                iconSize: 14
                fill: 1
                customColor: chip.tone
            }
            CustomText {
                content: chip.text
                size: 11
                weight: 600
                customColor: chip.tone
            }
        }
    }
}
