import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true

    readonly property bool showPrivacy: BarLayout.opt(root.itemId, "privacy") !== false
    readonly property bool showBattery: BarLayout.opt(root.itemId, "battery") !== false && ServiceUPower.powerLevel > 0
    readonly property bool low: ServiceUPower.powerLevel < 0.2 && !ServiceUPower.isCharging
    readonly property real iconPx: 17

    implicitWidth: row.implicitWidth + root.implicitHeight - row.implicitHeight
    implicitHeight: 30
    radius: height / 2
    color: Colors.surfaceContainerHigh

    component Glyph: Rectangle {
        id: g
        property string icon: ""
        property string tip: ""
        property bool tipOff: false
        signal activated()
        signal wheel(real delta)
        signal middle()

        width: 26
        height: 26
        radius: 13
        color: area.containsMouse ? Colors.primaryContainer : "transparent"
        Behavior on color { EffectsColorAnim {} }

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: g.icon
            iconSize: 17
            customColor: area.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    g.middle()
                else
                    g.activated()
            }
            onWheel: wheel => g.wheel(wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x)
        }

        CustomToolTip {
            content: g.tip
            visible: area.containsMouse && g.tip !== "" && !g.tipOff
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0

        Item {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showPrivacy && privacy.active
            width: privacy.implicitWidth + height - privacy.iconPx
            height: 26

            BarPrivacyDots {
                id: privacy
                anchors.centerIn: parent
                iconPx: 14
            }

            MouseArea {
                id: privHov
                anchors.fill: parent
                hoverEnabled: true
            }

            CustomToolTip {
                content: privacy.tip
                visible: privHov.containsMouse && privacy.tip !== ""
            }
        }

        Glyph {
            id: netGlyph
            anchors.verticalCenter: parent.verticalCenter
            tipOff: !!root.host && root.host.panelKind === "network"
            onActivated: if (root.host) root.host.openPanel("network", netGlyph)
            icon: ServiceNetwork.icon
            tip: ServiceNetwork.connectionLabel.length > 0 ? ServiceNetwork.connectionLabel : "No network"
        }

        Glyph {
            id: btGlyph
            anchors.verticalCenter: parent.verticalCenter
            tipOff: !!root.host && root.host.panelKind === "bluetooth"
            onActivated: if (root.host) root.host.openPanel("bluetooth", btGlyph)
            icon: ServiceBluetooth.state ? "bluetooth" : "bluetooth_disabled"
            tip: ServiceBluetooth.connectedDevices + " connected"
        }

        Glyph {
            id: volGlyph
            anchors.verticalCenter: parent.verticalCenter
            tipOff: !!root.host && root.host.panelKind === "sound"
            onActivated: if (root.host) root.host.openPanel("sound", volGlyph)
            icon: ServicePipewire.muted ? "volume_off"
                : ServicePipewire.volume > 0.6 ? "volume_up"
                : ServicePipewire.volume > 0.2 ? "volume_down" : "volume_mute"
            tip: ServicePipewire.muted ? "Muted" : "Volume " + Math.round(ServicePipewire.volume * 100) + "%"
            onMiddle: ServicePipewire.toggleMute()
            onWheel: d => {
                if (d > 0)
                    ServicePipewire.incrementVolume(0.05)
                else if (d < 0)
                    ServicePipewire.decrementVolume(0.05)
            }
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showBattery
            width: batt.width + height - batt.chipHeight
            height: 26

            BarFillChip {
                id: batt
                anchors.centerIn: parent
                value: ServiceUPower.powerLevel
                icon: ServiceUPower.isCharging ? "bolt" : ""
                label: Math.round(ServiceUPower.powerLevel * 100) + ""
                widthTemplate: "100"
                iconPx: 11
                labelPx: 10
                chipHeight: 16
                minWidth: 38
                trackColor: root.low ? Colors.errorContainer : Colors.surfaceContainerHighest
                fillColor: root.low ? Colors.error : Colors.primary
                ink: root.low ? Colors.errorContainerText : Colors.surfaceText
                fillInk: root.low ? Colors.errorText : Colors.primaryText
            }

            MouseArea {
                id: battHov
                anchors.fill: parent
                hoverEnabled: true
            }

            CustomToolTip {
                content: (ServiceUPower.isCharging ? "Charging · " : "")
                       + Math.round(ServiceUPower.powerLevel * 100) + "%"
                visible: battHov.containsMouse
            }
        }
    }
}
