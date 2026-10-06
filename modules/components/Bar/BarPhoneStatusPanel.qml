pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings

Item {
    id: root

    signal closed()

    readonly property bool ready: ServicePhone.ready
    readonly property real level: Math.max(0, Math.min(1, ServicePhone.battery / 100))
    readonly property color tint: ServicePhone.low ? Colors.error : Colors.primary
    property string flashed: ""

    readonly property string sub: {
        if (ServicePhone.charging && ServicePhone.minutesToFull > 0) {
            const m = ServicePhone.minutesToFull
            return "Full in about " + (m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " minutes")
        }
        if (ServicePhone.charging) return ServicePhone.battery >= 100 ? "Fully charged" : "Charging"
        if (ServicePhone.low) return "Battery low, plug it in"
        return "On battery"
    }

    readonly property var actions: [
        { key: "ring",  icon: "vibration",     label: "Ring",      done: "Ringing" },
        { key: "clip",  icon: "content_paste", label: "Clipboard", done: "Sent" },
        { key: "browse", icon: "folder_open",  label: "Browse",    done: "Opening" },
        { key: "send",  icon: "upload_file",   label: "Send files", done: "" }
    ]

    function act(key) {
        if (key === "ring") ServicePhone.ring()
        else if (key === "clip") ServicePhone.sendClipboard()
        else if (key === "browse") ServicePhone.browse()
        else if (key === "send") {
            GlobalStates.phoneOpen = true
            root.closed()
            return
        }
        root.flashed = key
        flashTimer.restart()
    }

    Timer {
        id: flashTimer
        interval: 2200
        onTriggered: root.flashed = ""
    }

    readonly property var recent: ServicePhone.transfers.slice(0, 3)

    implicitWidth: 400
    implicitHeight: col.implicitHeight + 32

    ColumnLayout {
        id: col
        x: 16
        y: 16
        width: root.width - 32
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Item {
                Layout.preferredWidth: 84
                Layout.preferredHeight: 84

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Colors.surfaceContainerHighest
                        strokeWidth: 9
                        capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 42; centerY: 42; radiusX: 37.5; radiusY: 37.5; startAngle: 0; sweepAngle: 360 }
                    }
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: root.ready ? root.tint : Colors.outline
                        strokeWidth: 9
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 42; centerY: 42; radiusX: 37.5; radiusY: 37.5
                            startAngle: -90
                            sweepAngle: root.level * 360
                            Behavior on sweepAngle { SpatialAnim { speed: "slow" } }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0
                    CustomText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        content: ServicePhone.battery >= 0 ? String(ServicePhone.battery) : "–"
                        family: SettingsConfig.general?.displayFont || "Titan One"
                        renderType: Text.QtRendering
                        size: 22
                        weight: 400
                        customColor: root.ready ? Colors.surfaceText : Colors.surfaceVariantText
                    }
                    CustomText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        content: !root.ready ? "last seen" : ServicePhone.charging ? "charging" : "left"
                        size: 10
                        weight: 500
                        customColor: Colors.surfaceVariantText
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                CustomText {
                    Layout.fillWidth: true
                    content: ServicePhone.label
                    size: 16
                    weight: 600
                    elide: Text.ElideRight
                }
                CustomText {
                    Layout.fillWidth: true
                    content: !ServicePhone.paired ? "Not paired yet"
                        : !root.ready ? (ServicePhone.looking ? "Looking for it…" : "Not on this Wi-Fi")
                        : root.sub
                    size: 12
                    weight: 400
                    customColor: ServicePhone.low && root.ready ? Colors.error : Colors.surfaceVariantText
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 6

                    Repeater {
                        model: root.ready
                            ? [ServicePhone.signalText, ServicePhone.ip !== "" ? "Same Wi-Fi" : ""].filter(t => t !== "")
                            : []
                        delegate: Rectangle {
                            id: chip
                            required property string modelData
                            implicitWidth: chipText.implicitWidth + 20
                            implicitHeight: 24
                            radius: 12
                            color: Colors.surfaceContainerHigh
                            CustomText {
                                id: chipText
                                anchors.centerIn: parent
                                content: chip.modelData
                                size: 12
                                weight: 500
                            }
                        }
                    }

                    M3Button {
                        visible: !root.ready
                        size: "xsmall"
                        variant: "tonal"
                        icon: ServicePhone.paired ? "refresh" : "smartphone"
                        label: ServicePhone.paired ? "Look again" : "Pair a phone"
                        onClicked: {
                            if (ServicePhone.paired) {
                                ServicePhone.lookAgain()
                            } else {
                                GlobalStates.phoneOpen = true
                                root.closed()
                            }
                        }
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 8
            rowSpacing: 8
            enabled: root.ready
            opacity: root.ready ? 1 : 0.45

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool lit: root.flashed === tile.modelData.key
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 64
                    radius: tileArea.pressed ? 10 : 16
                    color: tile.lit ? Colors.primary : tileArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                    Behavior on radius { SpatialAnim { speed: "fast" } }
                    Behavior on color { EffectsColorAnim { speed: "fast" } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialIconSymbol {
                            anchors.horizontalCenter: parent.horizontalCenter
                            content: tile.lit ? "check" : tile.modelData.icon
                            iconSize: 20
                            customColor: tile.lit ? Colors.primaryText : Colors.primary
                        }
                        CustomText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            content: tile.lit ? tile.modelData.done : tile.modelData.label
                            size: 12
                            weight: 500
                            customColor: tile.lit ? Colors.primaryText : Colors.surfaceText
                        }
                    }

                    MouseArea {
                        id: tileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.act(tile.modelData.key)
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.recent.length > 0
            spacing: 4

            CustomText {
                Layout.leftMargin: 2
                content: "Recent"
                size: 12
                weight: 600
                customColor: Colors.primary
            }

            Repeater {
                model: root.recent

                delegate: RowLayout {
                    id: tr
                    required property var modelData
                    readonly property bool incoming: tr.modelData.kind === "in" || tr.modelData.kind === "textIn"
                    Layout.fillWidth: true
                    Layout.leftMargin: 2
                    Layout.rightMargin: 2
                    spacing: 8

                    MaterialIconSymbol {
                        content: tr.incoming ? "download" : "upload"
                        iconSize: 16
                        customColor: tr.modelData.ok === false ? Colors.error : Colors.surfaceVariantText
                    }
                    CustomText {
                        Layout.fillWidth: true
                        content: tr.modelData.name
                        size: 13
                        weight: 400
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                    }
                    CustomText {
                        content: tr.modelData.ok === false ? "failed" : tr.incoming ? "from phone" : "to phone"
                        size: 12
                        weight: 400
                        customColor: tr.modelData.ok === false ? Colors.error : Colors.outline
                    }
                }
            }
        }
    }
}
