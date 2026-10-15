pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings

Item {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property var cell: UPower.devices.values.find(d => d && d.isLaptopBattery) ?? UPower.displayDevice
    readonly property real rate: Math.abs(root.cell.changeRate)
    readonly property real level: Math.max(0, Math.min(1, root.dev.percentage))
    readonly property int state: root.dev.state
    readonly property bool charging: root.state === UPowerDeviceState.Charging
    readonly property bool full: root.state === UPowerDeviceState.FullyCharged
    readonly property bool plugged: !UPower.onBattery
    readonly property bool low: root.level < 0.2 && !root.plugged
    readonly property bool saver: ServiceUPower.powerProfile === 0
    readonly property color tint: root.low ? Colors.error : root.plugged ? Colors.primary
        : root.saver ? Colors.tertiary : Colors.secondary
    readonly property color onTint: root.low ? Colors.errorText : root.plugged ? Colors.primaryText
        : root.saver ? Colors.tertiaryText : Colors.secondaryText

    readonly property string title: root.charging ? "Charging"
        : root.full ? "Fully charged"
        : root.plugged ? "Plugged in, not charging"
        : root.low ? "Battery low" : "On battery"

    function span(seconds) {
        if (!seconds || seconds <= 0)
            return root.plugged ? "Unplug to see" : "–"
        const h = Math.floor(seconds / 3600)
        const m = Math.round((seconds % 3600) / 60)
        return h > 0 ? h + " h " + m + " min" : m + " min"
    }

    readonly property var stats: [
        { icon: "schedule", tint: Colors.primary,
          label: root.charging ? "Full in" : root.plugged ? "On battery" : "Left",
          value: root.charging ? root.span(root.dev.timeToFull)
               : root.span(root.cell.timeToEmpty > 0 ? root.cell.timeToEmpty
                           : root.rate > 0 ? root.cell.energy / root.rate * 3600 : 0) },
        { icon: "bolt", tint: Colors.tertiary, label: root.charging ? "Charging at" : "Draw",
          value: root.rate > 0.05 ? root.rate.toFixed(1) + " W" : root.plugged ? "Idle on AC" : "–" },
        { icon: "favorite", tint: Colors.secondary, label: "Health",
          value: ServiceUPower.health > 0 ? Math.round(ServiceUPower.health * 100) + "%" : "–" },
        { icon: "battery_full_alt", tint: Colors.primary, label: "Capacity",
          value: root.cell.energyCapacity > 0 ? root.cell.energyCapacity.toFixed(1) + " Wh" : "–" }
    ]

    function iconFor(d) {
        if (d.isLaptopBattery) return "laptop"
        switch (d.type) {
        case UPowerDeviceType.Keyboard: return "keyboard"
        case UPowerDeviceType.Mouse: return "mouse"
        case UPowerDeviceType.Headset:
        case UPowerDeviceType.Headphones: return "headphones"
        case UPowerDeviceType.Phone: return "smartphone"
        case UPowerDeviceType.Tablet: return "tablet"
        case UPowerDeviceType.GamingInput: return "sports_esports"
        case UPowerDeviceType.Speakers: return "speaker"
        case UPowerDeviceType.Pen: return "stylus"
        case UPowerDeviceType.Touchpad: return "touchpad_mouse"
        }
        return "battery_full"
    }

    readonly property var devices: UPower.devices.values.filter(d => d && !d.isLaptopBattery
        && d.type !== UPowerDeviceType.LinePower && d.isPresent !== false && d.percentage > 0)

    function nameOf(d) {
        return d.model || UPowerDeviceType.toString(d.type)
    }

    function kindOf(d) {
        switch (d.type) {
        case UPowerDeviceType.GamingInput: return "Controller"
        case UPowerDeviceType.Headphones: return "Headphones"
        case UPowerDeviceType.Touchpad: return "Touchpad"
        }
        return UPowerDeviceType.toString(d.type)
    }

    function lowDevice(d) {
        return d.percentage < 0.2 && d.state !== UPowerDeviceState.Charging
    }

    function duration(seconds) {
        const h = Math.floor(seconds / 3600)
        const m = Math.round((seconds % 3600) / 60)
        return h > 0 ? (m > 0 ? h + " h " + m + " min" : h + " h") : m + " min"
    }

    function connectionOf(d) {
        const p = (d.nativePath || "").toLowerCase()
        if (p.indexOf("hidpp") >= 0)
            return "USB receiver"
        if (p.indexOf("bluez") >= 0 || /([0-9a-f]{2}:){5}[0-9a-f]{2}/.test(p))
            return "Bluetooth"
        if (p.indexOf("usb") >= 0)
            return "USB"
        return ""
    }

    function factsOf(d) {
        const out = []
        const link = root.connectionOf(d)
        if (link !== "")
            out.push({ k: "Connection", v: link, tone: "" })
        if (d.state === UPowerDeviceState.Charging)
            out.push({ k: "Status", v: "Charging", tone: "primary" })
        else if (d.state === UPowerDeviceState.FullyCharged)
            out.push({ k: "Status", v: "Full", tone: "" })
        else if (root.lowDevice(d))
            out.push({ k: "Status", v: "Charge soon", tone: "error" })
        else if (d.state === UPowerDeviceState.Discharging)
            out.push({ k: "Status", v: "On battery", tone: "" })
        if (d.state === UPowerDeviceState.Charging && d.timeToFull > 0)
            out.push({ k: "Full in", v: root.duration(d.timeToFull), tone: "" })
        else if (d.timeToEmpty > 0)
            out.push({ k: "Time left", v: "About " + root.duration(d.timeToEmpty), tone: "" })
        if (d.healthSupported && d.healthPercentage > 0)
            out.push({ k: "Health", v: Math.round(d.healthPercentage > 1 ? d.healthPercentage : d.healthPercentage * 100) + "%", tone: "" })
        return out
    }

    readonly property real devicesMax: 344

    implicitWidth: 400
    implicitHeight: col.implicitHeight + 36

    ColumnLayout {
        id: col
        x: 18
        y: 18
        width: root.width - 36
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Item {
                id: cell
                Layout.preferredWidth: 136
                Layout.preferredHeight: 232

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 42
                    height: 14
                    topLeftRadius: 8
                    topRightRadius: 8
                    bottomLeftRadius: 3
                    bottomRightRadius: 3
                    color: Colors.surfaceContainerHighest
                }

                Rectangle {
                    id: body
                    y: 10
                    width: parent.width
                    height: parent.height - 10
                    radius: 32
                    color: Colors.surfaceContainerHighest
                    clip: true

                    Canvas {
                        id: liquid
                        anchors.fill: parent
                        property real phase: 0
                        readonly property real surfaceY: body.height * (1 - root.level)
                        onSurfaceYChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()

                        Connections {
                            target: root
                            function onTintChanged() { liquid.requestPaint() }
                        }

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            ctx.beginPath()
                            ctx.roundedRect(0, 0, width, height, body.radius, body.radius)
                            ctx.clip()
                            const amp = root.level >= 0.995 ? 0 : 6
                            const wl = width / 1.5
                            ctx.beginPath()
                            ctx.moveTo(0, height)
                            for (let x = 0; x <= width; x += 2)
                                ctx.lineTo(x, liquid.surfaceY + amp * Math.sin((x / wl) * Math.PI * 2 + liquid.phase))
                            ctx.lineTo(width, height)
                            ctx.closePath()
                            ctx.fillStyle = root.tint
                            ctx.fill()
                        }

                        NumberAnimation on phase {
                            running: root.charging && root.visible
                            from: 0
                            to: Math.PI * 2
                            duration: 2400
                            loops: Animation.Infinite
                        }
                        onPhaseChanged: requestPaint()
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        CustomText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            content: Math.round(root.level * 100)
                            family: SettingsConfig.general?.displayFont || "Titan One"
                            renderType: Text.QtRendering
                            size: 40
                            weight: 400
                            customColor: root.level > 0.55 ? root.onTint : Colors.surfaceText
                        }
                        MaterialIconSymbol {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: root.plugged
                            content: "bolt"
                            iconSize: 22
                            customColor: root.level > 0.45 ? root.onTint : Colors.primary
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    CustomText { Layout.fillWidth: true; content: root.title; size: 17; weight: 600 }
                    CustomText {
                        Layout.fillWidth: true
                        content: root.plugged ? "Plugged in" : "Unplugged"
                        size: 12
                        weight: 400
                        customColor: Colors.surfaceVariantText
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Repeater {
                        model: root.stats

                        delegate: CustomCard {
                            id: statRow
                            required property var modelData
                            required property int index
                            autoRadius: false
                            topRadius: statRow.index === 0 ? 20 : 5
                            bottomRadius: statRow.index === root.stats.length - 1 ? 20 : 5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                MaterialIconSymbol { content: statRow.modelData.icon; iconSize: 18; customColor: statRow.modelData.tint }
                                CustomText {
                                    Layout.fillWidth: true
                                    content: statRow.modelData.label
                                    size: 12
                                    weight: 400
                                    customColor: Colors.surfaceVariantText
                                }
                                CustomText { content: statRow.modelData.value; size: 13; weight: 700 }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: ServiceUPower.availableProfiles

                delegate: Rectangle {
                    id: mode
                    required property var modelData
                    required property int index
                    readonly property bool on: ServiceUPower.powerProfile === mode.modelData.id
                    Layout.fillWidth: true
                    implicitHeight: 64
                    radius: modeArea.pressed ? 14 : mode.on ? 22 : 32
                    color: mode.on ? Colors.primary : modeArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                    Behavior on radius { SpatialAnim { speed: "fast" } }
                    Behavior on color { EffectsColorAnim { speed: "fast" } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        MaterialIconSymbol {
                            anchors.horizontalCenter: parent.horizontalCenter
                            content: mode.modelData.icon
                            iconSize: 22
                            customColor: mode.on ? Colors.primaryText : Colors.surfaceText
                        }
                        CustomText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            content: mode.modelData.name
                            size: 11
                            weight: 600
                            customColor: mode.on ? Colors.primaryText : Colors.surfaceText
                        }
                    }

                    MouseArea {
                        id: modeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ServiceUPower.setPowerProfile(mode.modelData.id)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            visible: root.devices.length > 0
            CustomText { Layout.fillWidth: true; content: "Your devices"; size: 14; weight: 600 }
            CustomText {
                content: root.devices.length + " connected"
                size: 12
                weight: 400
                customColor: Colors.surfaceVariantText
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(devCol.implicitHeight, root.devicesMax)
            visible: root.devices.length > 0

            Flickable {
                id: devFlick
                anchors.fill: parent
                contentWidth: width
                contentHeight: devCol.implicitHeight
                interactive: devFlick.contentHeight > devFlick.height + 1
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                ScrollBar.vertical: CustomScrollBar {}

                ColumnLayout {
                    id: devCol
                    width: devFlick.width
                    spacing: 3

                    Repeater {
                        model: root.devices

                        delegate: CustomCard {
                            id: devCard
                            required property var modelData
                            required property int index
                            readonly property bool low: root.lowDevice(devCard.modelData)
                            readonly property var facts: root.factsOf(devCard.modelData)
                            autoRadius: false
                            topRadius: devCard.index === 0 ? 20 : 5
                            bottomRadius: devCard.index === root.devices.length - 1 ? 20 : 5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Rectangle {
                                    implicitWidth: 38
                                    implicitHeight: 38
                                    radius: 19
                                    color: Colors.surfaceContainerHighest
                                    MaterialIconSymbol {
                                        anchors.centerIn: parent
                                        content: root.iconFor(devCard.modelData)
                                        iconSize: 20
                                        customColor: Colors.surfaceText
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    CustomText { Layout.fillWidth: true; content: root.nameOf(devCard.modelData); size: 14; weight: 600 }
                                    CustomText {
                                        Layout.fillWidth: true
                                        content: root.kindOf(devCard.modelData)
                                        size: 12
                                        weight: 400
                                        customColor: Colors.surfaceVariantText
                                    }
                                }

                                CustomText {
                                    content: Math.round(Math.max(0, Math.min(1, devCard.modelData.percentage)) * 100) + "%"
                                    size: 20
                                    weight: 600
                                    customColor: devCard.low ? Colors.error : Colors.surfaceText
                                }
                            }

                            Flow {
                                Layout.fillWidth: true
                                visible: devCard.facts.length > 0
                                spacing: 6

                                Repeater {
                                    model: devCard.facts

                                    delegate: Rectangle {
                                        id: fact
                                        required property var modelData
                                        width: factRow.implicitWidth + 20
                                        height: 28
                                        radius: 10
                                        color: Colors.surfaceContainer

                                        Row {
                                            id: factRow
                                            anchors.centerIn: parent
                                            spacing: 6
                                            CustomText {
                                                content: fact.modelData.k
                                                size: 11
                                                weight: 400
                                                customColor: Colors.surfaceVariantText
                                            }
                                            CustomText {
                                                content: fact.modelData.v
                                                size: 11
                                                weight: 600
                                                customColor: fact.modelData.tone === "error" ? Colors.error
                                                    : fact.modelData.tone === "primary" ? Colors.primary : Colors.surfaceText
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            NumberAnimation {
                id: devScroll
                target: devFlick
                property: "contentY"
                duration: 240
                easing.type: Easing.OutCubic
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                enabled: devFlick.interactive
                onWheel: wheel => {
                    const goal = devScroll.running ? devScroll.to : devFlick.contentY
                    const max = Math.max(0, devFlick.contentHeight - devFlick.height)
                    devScroll.stop()
                    devScroll.from = devFlick.contentY
                    devScroll.to = Math.max(0, Math.min(max, goal - wheel.angleDelta.y * 0.9))
                    devScroll.start()
                }
            }

            ScrollFade {
                anchors.fill: parent
                flickable: devFlick
                color: Colors.surface
            }
        }
    }
}
