pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings
import "../../MatrialShapes/" as MaterialShapes

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

    readonly property real secondsLeft: root.cell.timeToEmpty > 0 ? root.cell.timeToEmpty
        : root.rate > 0 ? root.cell.energy / root.rate * 3600 : 0

    readonly property string status: {
        if (root.charging)
            return root.dev.timeToFull > 0 ? "Charging, full in " + root.duration(root.dev.timeToFull) : "Charging"
        if (root.full)
            return "Fully charged, on AC"
        if (root.plugged)
            return "Plugged in, not charging"
        const left = root.secondsLeft > 0 ? ", " + root.duration(root.secondsLeft) + " left" : ""
        return (root.low ? "Battery low" : "On battery") + left
    }

    readonly property var chips: {
        const out = []
        if (ServiceUPower.health > 0)
            out.push({ k: "Health", v: Math.round(ServiceUPower.health * 100) + "%", accent: true })
        if (root.cell.energyCapacity > 0)
            out.push({ k: "", v: root.cell.energyCapacity.toFixed(1) + " Wh", accent: false })
        if (root.rate > 0.05)
            out.push({ k: root.charging ? "In" : "Draw", v: root.rate.toFixed(1) + " W", accent: false })
        return out
    }

    function iconFor(d) {
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

    function shapeFor(d) {
        switch (d.type) {
        case UPowerDeviceType.Keyboard: return "squircle"
        case UPowerDeviceType.Mouse: return "pill"
        case UPowerDeviceType.Headset:
        case UPowerDeviceType.Headphones: return "cookie6"
        case UPowerDeviceType.Speakers: return "cookie9"
        case UPowerDeviceType.Phone: return "gem"
        case UPowerDeviceType.GamingInput: return "clover4"
        case UPowerDeviceType.Tablet: return "arch"
        }
        return "cookie4"
    }

    readonly property var devices: UPower.devices.values.filter(d => d && !d.isLaptopBattery
        && d.type !== UPowerDeviceType.LinePower && d.isPresent !== false && d.percentage > 0)

    readonly property var lowest: root.devices.find(d => root.lowDevice(d)) ?? null

    readonly property int columns: Math.max(1, Math.min(3, root.devices.length))

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

    function statusOf(d) {
        if (d.state === UPowerDeviceState.Charging) return "Charging"
        if (d.state === UPowerDeviceState.FullyCharged) return "Full"
        if (root.lowDevice(d)) return "Charge soon"
        if (d.state === UPowerDeviceState.Discharging) return "On battery"
        return root.kindOf(d)
    }

    function detailOf(d) {
        const out = [root.kindOf(d)]
        const link = root.connectionOf(d)
        if (link !== "")
            out.push(link)
        if (d.state === UPowerDeviceState.Charging && d.timeToFull > 0)
            out.push("full in " + root.duration(d.timeToFull))
        else if (d.timeToEmpty > 0)
            out.push("about " + root.duration(d.timeToEmpty) + " left")
        if (d.healthSupported && d.healthPercentage > 0)
            out.push("health " + Math.round(d.healthPercentage > 1 ? d.healthPercentage : d.healthPercentage * 100) + "%")
        return out.join(", ")
    }

    readonly property real devicesMax: 332

    implicitWidth: 400
    implicitHeight: col.implicitHeight + 40

    ColumnLayout {
        id: col
        x: 20
        y: 20
        width: root.width - 40
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            spacing: 2
            CustomText { Layout.fillWidth: true; content: "Battery"; size: 20; weight: 600 }
            CustomText {
                Layout.fillWidth: true
                readonly property int count: root.devices.length + 1
                content: count + (count === 1 ? " device" : " devices") + " with a battery"
                size: 13
                weight: 400
                customColor: Colors.surfaceVariantText
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: heroRow.implicitHeight + 32
            radius: 28
            color: Colors.surfaceContainer

            RowLayout {
                id: heroRow
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 16

                LiquidShape {
                    Layout.preferredWidth: 112
                    Layout.preferredHeight: 112
                    shape: "cookie12"
                    level: root.level
                    fill: root.tint
                    onInk: root.onTint
                    label: Math.round(root.level * 100)
                    icon: root.plugged ? "bolt" : ""
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    CustomText { Layout.fillWidth: true; content: "This laptop"; size: 17; weight: 600 }
                    CustomText {
                        Layout.fillWidth: true
                        content: root.status
                        size: 13
                        weight: 400
                        wrapMode: Text.WordWrap
                        customColor: root.low ? Colors.error : Colors.surfaceVariantText
                    }

                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        visible: root.chips.length > 0
                        spacing: 6

                        Repeater {
                            model: root.chips

                            delegate: Rectangle {
                                id: chip
                                required property var modelData
                                width: chipRow.implicitWidth + 20
                                height: 28
                                radius: 10
                                color: Colors.surfaceContainerHighest

                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    CustomText {
                                        visible: chip.modelData.k !== ""
                                        content: chip.modelData.k
                                        size: 12
                                        weight: 400
                                        customColor: Colors.surfaceVariantText
                                    }
                                    CustomText {
                                        content: chip.modelData.v
                                        size: 12
                                        weight: 600
                                        customColor: chip.modelData.accent ? Colors.tertiary : Colors.surfaceText
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(grid.implicitHeight, root.devicesMax)
            visible: root.devices.length > 0

            Flickable {
                id: devFlick
                anchors.fill: parent
                contentWidth: width
                contentHeight: grid.implicitHeight
                interactive: devFlick.contentHeight > devFlick.height + 1
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                ScrollBar.vertical: CustomScrollBar {}

                GridLayout {
                    id: grid
                    width: devFlick.width
                    columns: root.columns
                    columnSpacing: 8
                    rowSpacing: 8

                    Repeater {
                        model: root.devices

                        delegate: Rectangle {
                            id: tile
                            required property var modelData
                            readonly property bool low: root.lowDevice(tile.modelData)
                            readonly property bool wide: root.columns < 3
                            readonly property real pct: Math.max(0, Math.min(1, tile.modelData.percentage))
                            Layout.fillWidth: true
                            Layout.preferredWidth: (grid.width - (root.columns - 1) * grid.columnSpacing) / root.columns
                            implicitHeight: tileBody.implicitHeight + (tile.wide ? 28 : 26)
                            radius: 24
                            color: Colors.surfaceContainer

                            GridLayout {
                                id: tileBody
                                x: tile.wide ? 14 : 10
                                y: tile.wide ? 14 : 14
                                width: tile.width - 2 * x
                                columns: tile.wide ? 2 : 1
                                columnSpacing: 14
                                rowSpacing: 8

                                LiquidShape {
                                    Layout.preferredWidth: tile.wide ? 64 : 76
                                    Layout.preferredHeight: tile.wide ? 64 : 76
                                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                    shape: root.shapeFor(tile.modelData)
                                    level: tile.pct
                                    fill: tile.low ? Colors.error : Colors.secondary
                                    onInk: tile.low ? Colors.errorText : Colors.secondaryText
                                    icon: root.iconFor(tile.modelData)
                                    iconSize: 26
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 1

                                    CustomText {
                                        Layout.fillWidth: true
                                        horizontalAlignment: tile.wide ? Text.AlignLeft : Text.AlignHCenter
                                        content: Math.round(tile.pct * 100) + "%"
                                        size: 18
                                        weight: 600
                                        customColor: tile.low ? Colors.error : Colors.surfaceText
                                    }
                                    CustomText {
                                        Layout.fillWidth: true
                                        horizontalAlignment: tile.wide ? Text.AlignLeft : Text.AlignHCenter
                                        content: root.nameOf(tile.modelData)
                                        size: 12
                                        weight: 500
                                        elide: Text.ElideRight
                                    }
                                    CustomText {
                                        Layout.fillWidth: true
                                        horizontalAlignment: tile.wide ? Text.AlignLeft : Text.AlignHCenter
                                        content: root.statusOf(tile.modelData)
                                        size: 11
                                        weight: 400
                                        elide: Text.ElideRight
                                        customColor: tile.low ? Colors.error : Colors.surfaceVariantText
                                    }
                                }
                            }

                            HoverHandler { id: tileHover }

                            CustomToolTip {
                                content: root.nameOf(tile.modelData)
                                detail: root.detailOf(tile.modelData)
                                visible: tileHover.hovered
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

        Rectangle {
            Layout.fillWidth: true
            visible: root.lowest !== null
            implicitHeight: alertRow.implicitHeight + 24
            radius: 20
            color: Colors.errorContainer

            RowLayout {
                id: alertRow
                x: 16
                y: 12
                width: parent.width - 32
                spacing: 12

                MaterialIconSymbol {
                    content: "battery_alert"
                    iconSize: 22
                    fill: 1
                    customColor: Colors.errorContainerText
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    CustomText {
                        Layout.fillWidth: true
                        content: root.lowest ? root.nameOf(root.lowest) + " at " + Math.round(root.lowest.percentage * 100) + "%" : ""
                        size: 14
                        weight: 600
                        elide: Text.ElideRight
                        customColor: Colors.errorContainerText
                    }
                    CustomText {
                        Layout.fillWidth: true
                        content: "Charge it soon to keep using it"
                        size: 12
                        weight: 400
                        customColor: Colors.errorContainerText
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 52

            M3ButtonGroup {
                anchors.left: parent.left
                anchors.right: parent.right
                height: 52
                fillWidth: true
                iconSize: 20
                textSize: 14
                inactiveColor: Colors.surfaceContainerHigh
                model: ServiceUPower.availableProfiles.map(p => ({ value: p.id, label: p.name, icon: p.icon }))
                activeCheck: value => ServiceUPower.powerProfile === value
                onSegmentClicked: value => ServiceUPower.setPowerProfile(value)
            }
        }
    }
}
