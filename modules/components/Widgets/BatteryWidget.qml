import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MaterialShapeFn

Item {
    id: root
    implicitWidth: 200
    implicitHeight: 200

    property bool editMode: false

    readonly property real pct: ServiceUPower.powerLevel
    readonly property bool charging: ServiceUPower.isCharging
    readonly property color levelColor: {
        if (pct < 0.15) return Qt.color(Colors.error)
        if (pct < 0.30) return Qt.color(Colors.tertiary)
        return Qt.color(Colors.primary)
    }

    Component.onCompleted: {
        root.x = SettingsConfig.widgets.batteryX ?? 600
        root.y = SettingsConfig.widgets.batteryY ?? 200
    }

    Connections {
        target: SettingsConfig
        function onWidgetsChanged() {
            if (!root.editMode) {
                root.x = SettingsConfig.widgets.batteryX ?? 600
                root.y = SettingsConfig.widgets.batteryY ?? 200
            }
        }
    }

    onXChanged: if (editMode) saveTimer.restart()
    onYChanged: if (editMode) saveTimer.restart()

    Timer {
        id: saveTimer
        interval: 500
        repeat: false
        onTriggered: {
            SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, {
                batteryX: root.x, batteryY: root.y
            })
        }
    }

    MouseArea {
        anchors.fill: parent
        drag.target: root.editMode ? root : undefined
        cursorShape: root.editMode ? Qt.SizeAllCursor : Qt.ArrowCursor
        onDoubleClicked: root.editMode = !root.editMode
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: root.editMode ? "#aaffffff" : "transparent"
        border.width: 2
        radius: 12
        visible: root.editMode
    }

    // ── Square mask ───────────────────────────────────────────────────
    // getSquare() = rounded rectangle with 30% corner rounding (squircle).
    // Square parent → width: parent.height = height: parent.width = 200.
    Item {
        id: squareMask
        anchors.fill: parent
        layer.enabled: true
        visible: false

        MaterialShapes.ShapeCanvas {
            anchors.centerIn: parent
            width: parent.height
            height: parent.width
            roundedPolygon: MaterialShapeFn.getSquare()
            color: "white"
        }
    }

    // ── Background + wavy fill, masked to the square shape ───────────
    Item {
        id: batteryContent
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            color: Colors.surface
        }

        Canvas {
            id: waveCanvas
            anchors.fill: parent
            antialiasing: true

            // Smooth fill level transition
            property real smoothPct: 0
            Behavior on smoothPct {
                id: smoothBehavior
                enabled: false
                NumberAnimation { duration: 800; easing.type: Easing.OutCubic }
            }

            // Wave animation phase
            property real phase: 0

            // Colors as properties so they're accessible inside onPaint
            property color fillColor: Qt.rgba(root.levelColor.r, root.levelColor.g, root.levelColor.b, 0.22)
            property color crestColor: Qt.rgba(root.levelColor.r, root.levelColor.g, root.levelColor.b, 0.40)

            Component.onCompleted: {
                smoothPct = root.pct       // instant — behavior is off
                smoothBehavior.enabled = true  // animate all future changes
            }

            Connections {
                target: root
                function onPctChanged() { waveCanvas.smoothPct = root.pct }
            }

            // 60 fps wave animation — phase grows unboundedly so Math.sin()
            // stays continuous with no wrap-around snap
            Timer {
                interval: 16
                repeat: true
                running: root.pct < 1.0
                onTriggered: {
                    waveCanvas.phase += 0.02
                    waveCanvas.requestPaint()
                }
            }

            onSmoothPctChanged: requestPaint()
            onFillColorChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                if (smoothPct <= 0) return

                if (smoothPct >= 1.0) {
                    ctx.fillStyle = fillColor
                    ctx.fillRect(0, 0, width, height)
                    return
                }

                const fillY = height * (1 - smoothPct)
                const amp   = 7   // wave amplitude px
                const freq1 = Math.PI * 4 / width   // ~2 full waves
                const freq2 = Math.PI * 7 / width   // secondary harmonic

                // Build the wave path
                const wavePath = (offsetY) => {
                    ctx.moveTo(0, height)
                    ctx.lineTo(0, fillY + amp * Math.sin(phase) + offsetY)
                    for (let x = 1; x <= width; x++) {
                        const y = fillY + offsetY
                            + amp       * Math.sin(freq1 * x + phase)
                            + amp * 0.4 * Math.sin(freq2 * x - phase * 1.7)
                        ctx.lineTo(x, y)
                    }
                    ctx.lineTo(width, height)
                    ctx.closePath()
                }

                // Main fill body
                ctx.beginPath()
                wavePath(0)
                ctx.fillStyle = fillColor
                ctx.fill()

                // Bright crest line on top of the wave
                ctx.beginPath()
                ctx.moveTo(0, fillY + amp * Math.sin(phase))
                for (let x = 1; x <= width; x++) {
                    const y = fillY
                        + amp       * Math.sin(freq1 * x + phase)
                        + amp * 0.4 * Math.sin(freq2 * x - phase * 1.7)
                    ctx.lineTo(x, y)
                }
                ctx.strokeStyle = crestColor
                ctx.lineWidth = 1.5
                ctx.lineJoin = "round"
                ctx.stroke()
            }
        }
    }

    MultiEffect {
        source: batteryContent
        anchors.fill: batteryContent
        maskEnabled: true
        maskSource: squareMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    // ── Percentage + status — top-right ───────────────────────────────
    Column {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 30
        anchors.rightMargin: 24
        spacing: 2

        CustomText {
            anchors.right: parent.right
            content: Math.round(root.pct * 100) + "%"
            size: 52
            weight: 400
            customColor: root.levelColor
            font.family: SettingsConfig.general.displayFont ?? "Titan One"
        }

        CustomText {
            anchors.right: parent.right
            content: root.charging
                ? (ServiceUPower.timeToFull.length > 0 ? ServiceUPower.timeToFull : "Charging")
                : "On Battery"
            size: 13
            customColor: Colors.outline
        }
    }

    // ── Battery icon — bottom-left ────────────────────────────────────
    Item {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: 32
        anchors.leftMargin: 32
        implicitWidth: 54
        implicitHeight: 54

        MaterialShapes.ShapeCanvas {
            anchors.fill: parent
            roundedPolygon: MaterialShapeFn.getCookie6Sided()
            color: Qt.rgba(root.levelColor.r, root.levelColor.g, root.levelColor.b, 0.28)
        }

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: root.charging ? "bolt" : (
                root.pct < 0.15 ? "battery_alert" :
                root.pct < 0.35 ? "battery_2_bar" :
                root.pct < 0.55 ? "battery_3_bar" :
                root.pct < 0.75 ? "battery_5_bar" : "battery_full"
            )
            iconSize: 26
            customColor: root.levelColor

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.charging
                NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }
        }
    }

    // ── Health — bottom-right ─────────────────────────────────────────
    Row {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 38
        anchors.rightMargin: 26
        spacing: 5

        MaterialIconSymbol {
            content: "favorite"
            iconSize: 13
            customColor: ServiceUPower.health > 0.8 ? Colors.primary : Colors.error
        }

        CustomText {
            content: Math.round(ServiceUPower.health * 100) + "%"
            size: 13
            customColor: Colors.outline
        }
    }
}
