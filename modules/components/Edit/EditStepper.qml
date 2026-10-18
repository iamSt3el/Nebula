pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

RowLayout {
    id: st
    spacing: 6

    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string unit: "px"
    property var presets: []
    property bool canAuto: false
    property bool isAuto: false
    property string autoLabel: "Auto"
    property string autoText: "Auto"
    property bool lead: false
    property real offValue: st.presets.length > 0 ? st.presets[Math.floor(st.presets.length / 2)].value : st.from
    signal picked(real v)
    signal autoPicked

    function clamp(v) {
        const snapped = st.from + Math.round((v - st.from) / st.stepSize) * st.stepSize
        return Math.max(st.from, Math.min(st.to, Math.round(snapped * 100) / 100))
    }

    function nudge(dir) {
        const base = st.isAuto ? st.offValue : st.value
        const next = st.isAuto ? st.clamp(base) : st.clamp(base + dir * st.stepSize)
        if (next !== st.value || st.isAuto)
            st.picked(next)
    }

    function fmt(v) {
        return (Math.round(v * 100) / 100) + (st.unit !== "" ? " " + st.unit : "")
    }

    component Nudge: Rectangle {
        id: nb
        property int dir: 1
        width: 34
        height: 34
        radius: 17
        color: nbArea.pressed ? Qt.alpha(Colors.surfaceText, 0.16)
            : nbArea.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
        opacity: (nb.dir < 0 ? st.isAuto || st.value > st.from : st.isAuto || st.value < st.to) ? 1 : 0.35

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: nb.dir < 0 ? "remove" : "add"
            iconSize: 18
            customColor: Colors.surfaceVariantText
        }

        Timer {
            id: repeat
            interval: 90
            repeat: true
            running: false
            onTriggered: st.nudge(nb.dir)
        }

        MouseArea {
            id: nbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            pressAndHoldInterval: 380
            onClicked: st.nudge(nb.dir)
            onPressAndHold: repeat.start()
            onReleased: repeat.stop()
            onCanceled: repeat.stop()
        }
    }

    Row {
        visible: st.presets.length > 0 || st.canAuto
        Layout.fillWidth: true
        spacing: 3

        Repeater {
            model: (st.canAuto ? [{ label: st.autoLabel, auto: true }] : []).concat(st.presets)

            delegate: Rectangle {
                id: chip
                required property var modelData
                required property int index
                readonly property int count: (st.canAuto ? 1 : 0) + st.presets.length
                readonly property bool on: chip.modelData.auto ? st.isAuto : (!st.isAuto && st.value === chip.modelData.value)
                readonly property real outer: 17
                readonly property real inner: 6
                width: Math.max(56, chipText.implicitWidth + 22)
                height: 34
                color: chip.on ? Colors.secondaryContainer
                    : chipArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
                topLeftRadius: chip.index === 0 ? chip.outer : chip.inner
                bottomLeftRadius: chip.index === 0 ? chip.outer : chip.inner
                topRightRadius: chip.index === chip.count - 1 ? chip.outer : chip.inner
                bottomRightRadius: chip.index === chip.count - 1 ? chip.outer : chip.inner
                Behavior on color { EffectsColorAnim { speed: "fast" } }

                CustomText {
                    id: chipText
                    anchors.centerIn: parent
                    content: chip.modelData.label
                    size: 12
                    weight: chip.on ? 700 : 500
                    customColor: chip.on ? Colors.secondaryContainerText : Colors.surfaceText
                }

                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (chip.modelData.auto) {
                            if (st.isAuto) st.picked(st.clamp(st.offValue))
                            else st.autoPicked()
                        } else {
                            st.picked(chip.modelData.value)
                        }
                    }
                }

                CustomToolTip {
                    content: chip.modelData.auto ? "" : st.fmt(chip.modelData.value)
                    visible: chipArea.containsMouse && !chip.modelData.auto
                }
            }
        }
    }

    Item {
        visible: st.presets.length === 0 && !st.canAuto && !st.lead
        Layout.fillWidth: true
    }

    Rectangle {
        id: box
        implicitWidth: 132
        implicitHeight: 34
        radius: 17
        color: Colors.surfaceContainerHigh
        opacity: st.isAuto ? 0.6 : 1

        WheelStep {
            onStepped: dir => st.nudge(dir)
        }

        Nudge {
            anchors.left: parent.left
            dir: -1
        }

        Nudge {
            anchors.right: parent.right
            dir: 1
        }

        CustomText {
            anchors.centerIn: parent
            visible: !field.visible
            content: st.isAuto ? st.autoText : st.fmt(st.value)
            size: 13
            weight: 600
            font.features: { "tnum": 1 }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    field.text = String(st.value)
                    field.visible = true
                    field.forceActiveFocus()
                    field.selectAll()
                }
            }
        }

        TextInput {
            id: field
            visible: false
            anchors.centerIn: parent
            width: 56
            horizontalAlignment: TextInput.AlignHCenter
            font.family: SettingsConfig.general.defaultFont ?? "Rubik"
            font.pixelSize: 13
            font.weight: 600
            color: Colors.surfaceText
            selectionColor: Qt.alpha(Colors.primary, 0.4)
            selectedTextColor: Colors.surfaceText
            validator: DoubleValidator { bottom: st.from; top: st.to }

            function commit() {
                const v = parseFloat(field.text)
                field.visible = false
                if (!isNaN(v))
                    st.picked(st.clamp(v))
            }

            Keys.onReturnPressed: field.commit()
            Keys.onEnterPressed: field.commit()
            Keys.onEscapePressed: field.visible = false
            onActiveFocusChanged: if (!field.activeFocus && field.visible) field.commit()
        }
    }

    Item {
        visible: st.presets.length === 0 && !st.canAuto && st.lead
        Layout.fillWidth: true
    }
}
