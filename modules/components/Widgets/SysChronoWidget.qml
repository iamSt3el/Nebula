import QtQuick
import Quickshell.Services.UPower
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

WidgetHost {
    id: root
    configKey: "sysChrono"
    tile: WidgetSizes.small
    defaultPos: Qt.point(1355, 605)

    readonly property var si: root.preview ? PreviewData : ServiceSystemInfo
    Component.onCompleted: root.si.retain()
    Component.onDestruction: root.si.release()

    function clamp01(v) { return Math.max(0, Math.min(1, v || 0)) }
    function short(bps) {
        if (bps >= 1024 * 1024) return (bps / (1024 * 1024)).toFixed(1) + "M"
        if (bps >= 1024) return Math.round(bps / 1024) + "K"
        return Math.round(bps) + "B"
    }

    readonly property real cpu: root.clamp01(root.si.cpuUsage)
    readonly property bool cpuHot: root.cpu > 0.85
    readonly property color accent: root.cpuHot ? Colors.error : Colors.primary
    readonly property real temp: root.si.cpuTemp ?? 0

    property var cpuLog: []
    readonly property real peak: root.preview ? 0.71
        : root.cpuLog.reduce((m, v) => Math.max(m, v), root.cpu)
    property real peakShown: root.peak
    Behavior on peakShown { SpatialAnim { speed: "slow" } }

    Timer {
        interval: 1000
        repeat: true
        running: !root.preview && root.visible
        onTriggered: {
            const log = root.cpuLog.slice(-59)
            log.push(root.cpu)
            root.cpuLog = log
        }
    }
    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: root.preview || (root.dev?.isLaptopBattery ?? false)
    readonly property real battery: root.preview ? 0.82 : (root.dev?.percentage ?? 0)
    readonly property bool charging: root.preview || ServiceUPower.isCharging

    readonly property var dials: [
        { x: 52, y: 100, icon: "stadia_controller" },
        { x: 148, y: 100, icon: "memory_alt" },
        { x: 100, y: 148, icon: "swap_vert" }
    ]
    readonly property real gpu: root.clamp01(root.si.gpuUsage)
    readonly property real ram: root.clamp01(root.si.memUsage)
    readonly property real net: root.clamp01(Math.log10(1 + (root.si.netDownloadBps ?? 0) / 1024) / 4)

    function dialValue(i) { return i === 0 ? root.gpu : i === 1 ? root.ram : root.net }
    function dialText(i) {
        if (i === 0) return Math.round(root.gpu * 100) + "%"
        if (i === 1) return (root.si.memUsedGb ?? 0).toFixed(1) + "G"
        return root.short(root.si.netDownloadBps ?? 0)
    }

    WidgetCard {
        anchors.fill: parent

        Item {
            id: face
            anchors.centerIn: parent
            width: 200
            height: 200

            Repeater {
                model: 50

                Rectangle {
                    required property int index
                    readonly property bool major: index % 5 === 0
                    readonly property bool lit: (index + 0.5) / 50 <= root.cpu
                    x: 100 - width / 2
                    y: 10
                    width: major ? 2 : 1.3
                    height: major ? 9.5 : 5
                    radius: width / 2
                    antialiasing: true
                    color: lit ? root.accent : major ? Colors.outline : Colors.outlineVariant
                    Behavior on color { EffectsColorAnim {} }
                    transform: Rotation {
                        origin.x: width / 2
                        origin.y: 90
                        angle: index * 7.2
                    }
                }
            }

            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 42
                content: "CPU"
                size: 8
                weight: 600
                font.letterSpacing: 2.2
                customColor: Colors.outline
            }

            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 53
                content: Math.round(root.cpu * 100) + "%"
                size: 15
                weight: 600
                customColor: root.cpuHot ? Colors.error : Colors.surfaceText
            }

            Repeater {
                model: root.dials

                Item {
                    id: dial
                    required property var modelData
                    required property int index
                    readonly property real value: root.dialValue(dial.index)
                    readonly property bool hot: dial.index < 2 && dial.value > 0.85
                    property real shown: dial.value
                    Behavior on shown { SpatialAnim {} }
                    x: dial.modelData.x - width / 2
                    y: dial.modelData.y - height / 2
                    width: 41.5
                    height: 41.5

                    MaterialShapes.ShapeCanvas {
                        anchors.fill: parent
                        roundedPolygon: ShapeLibrary.get("circle")
                        color: "transparent"
                        strokeProgress: dial.shown
                        strokeWidth: 3.5
                        strokeColor: dial.hot ? Colors.error : Colors.tertiary
                        strokeTrackColor: Colors.secondaryContainer
                    }

                    MaterialIconSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 8
                        content: dial.modelData.icon
                        iconSize: 11
                        fill: 1
                        customColor: Colors.surfaceVariantText
                    }

                    CustomText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 20
                        content: root.dialText(dial.index)
                        size: 10
                        weight: 600
                        customColor: dial.hot ? Colors.error : Colors.surfaceText
                    }
                }
            }

            Rectangle {
                x: 141 - width / 2
                y: 141 - height / 2
                width: 30
                height: 16
                radius: 5
                color: Colors.surfaceContainer
                border.width: 1
                border.color: Colors.outlineVariant

                CustomText {
                    anchors.centerIn: parent
                    content: Math.round(root.temp) + "°"
                    size: 10
                    weight: 600
                    customColor: root.temp >= 85 ? Colors.error : Colors.surfaceText
                }
            }

            Rectangle {
                visible: root.hasBattery
                x: 58 - width / 2
                y: 141 - height / 2
                width: batRow.implicitWidth + 12
                height: 16
                radius: 5
                color: Colors.surfaceContainer
                border.width: 1
                border.color: Colors.outlineVariant

                Row {
                    id: batRow
                    anchors.centerIn: parent
                    spacing: 1

                    MaterialIconSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.charging
                        content: "bolt"
                        iconSize: 10
                        fill: 1
                        customColor: Colors.surfaceVariantText
                    }

                    CustomText {
                        anchors.verticalCenter: parent.verticalCenter
                        content: Math.round(root.battery * 100) + "%"
                        size: 10
                        weight: 600
                        customColor: !root.charging && root.battery <= 0.15 ? Colors.error : Colors.surfaceText
                    }
                }
            }

            Item {
                anchors.fill: parent
                rotation: root.peakShown * 360
                opacity: root.peak - root.cpu > 0.03 ? 1 : 0
                Behavior on opacity { EffectsAnim {} }

                Rectangle {
                    x: 100 - width / 2
                    y: 31
                    width: 1.4
                    height: 69
                    radius: width / 2
                    antialiasing: true
                    color: Qt.alpha(root.accent, 0.5)
                }

                Rectangle {
                    x: 100 - width / 2
                    y: 26
                    width: 5
                    height: 5
                    radius: width / 2
                    antialiasing: true
                    color: root.accent
                }
            }

            Item {
                anchors.fill: parent
                rotation: root.cpu * 360
                Behavior on rotation { SpatialAnim { speed: "slow" } }

                Rectangle {
                    x: 100 - width / 2
                    y: 23
                    width: 2.2
                    height: 90
                    radius: width / 2
                    antialiasing: true
                    color: root.accent
                    Behavior on color { EffectsColorAnim {} }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 10
                height: 10
                radius: 5
                color: root.accent
                Behavior on color { EffectsColorAnim {} }

                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    radius: 2
                    color: Colors.surface
                }
            }
        }
    }
}
