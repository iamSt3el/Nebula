import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property var call: ServicePhone.call
    readonly property int missed: ServicePhone.missedCalls.length
    readonly property bool ringing: root.call !== null
    readonly property bool shown: ServicePhone.ready && (root.ringing || root.missed > 0)
    readonly property bool iconSizable: true
    readonly property real box: BarLayout.boxFor(root.itemId, root.host)
    readonly property real iconPx: BarLayout.iconPxFor(root.itemId, root.box, 18)
    readonly property real plate: BarLayout.platePxFor(root.box, root.iconPx, 18, 28)
    readonly property real labelPx: BarLayout.scaleFor(root.iconPx, 18, 13, 8)
    readonly property real inset: 3
    readonly property real dot: root.plate - 2 * root.inset
    readonly property bool open: !!root.host && root.host.panelKind === "phoneCall"
    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property bool verticalReady: true
    readonly property bool hot: hov.containsMouse || root.open
    readonly property color plateColor: root.ringing ? Colors.primary
        : root.hot ? Colors.primaryContainer : Qt.alpha(Colors.primaryContainer, 0)
    readonly property color ink: root.ringing ? Colors.primaryText
        : root.hot ? Colors.primaryContainerText : Colors.error

    implicitWidth: root.vertical ? root.plate
        : root.ringing ? ringRow.implicitWidth + 2 * root.inset
        : missedRow.implicitWidth + root.plate - root.iconPx
    implicitHeight: root.plate
    radius: height / 2
    color: root.plateColor
    Behavior on implicitWidth { SpatialAnim { speed: "fast" } }
    Behavior on color { EffectsColorAnim { speed: "fast" } }

    Rectangle {
        id: ring
        property real spread: 0
        z: -1
        anchors.centerIn: parent
        width: root.width + 2 * ring.spread
        height: root.height + 2 * ring.spread
        radius: height / 2
        color: Qt.alpha(Colors.primary, 0)
        border.width: 2
        border.color: Colors.primary
        opacity: 0
        visible: root.ringing && !ServicePhone.ringerMuted

        SequentialAnimation {
            running: ring.visible
            loops: Animation.Infinite
            onStopped: { ring.spread = 0; ring.opacity = 0 }
            ParallelAnimation {
                NumberAnimation { target: ring; property: "spread"; from: 0; to: 6; duration: 900; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring; property: "opacity"; from: 0.8; to: 0; duration: 900; easing.type: Easing.OutCubic }
            }
            PauseAnimation { duration: 250 }
        }
    }

    Row {
        id: ringRow
        x: root.inset
        anchors.verticalCenter: parent.verticalCenter
        visible: root.ringing
        spacing: 8

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: root.dot
            height: root.dot
            radius: width / 2
            color: Colors.primaryText

            CustomText {
                anchors.centerIn: parent
                visible: photo.status !== Image.Ready
                content: root.call ? root.call.name.charAt(0).toUpperCase() : ""
                size: Math.round(root.dot * 0.5)
                weight: 700
                customColor: Colors.primary
            }

            RoundedImage {
                id: photo
                anchors.fill: parent
                radius: width / 2
                source: root.call ? root.call.photo : ""
                sourceSize: Qt.size(64, 64)
            }
        }

        CustomText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.vertical
            content: root.call ? root.call.name + " is calling" : ""
            size: root.labelPx
            weight: 600
            customColor: root.ink
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 160)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.vertical
            width: root.dot
            height: root.dot
            radius: width / 2
            color: ServicePhone.ringerMuted ? Qt.alpha(Colors.primaryText, 0.35) : Colors.primaryText
            Behavior on color { EffectsColorAnim { speed: "fast" } }

            MaterialIconSymbol {
                anchors.centerIn: parent
                content: "notifications_off"
                fill: ServicePhone.ringerMuted ? 1 : 0
                iconSize: Math.round(root.dot * 0.62)
                customColor: ServicePhone.ringerMuted ? Colors.primaryText : Colors.primary
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: !ServicePhone.ringerMuted
                onClicked: ServicePhone.silenceRinger()
            }
        }
    }

    Row {
        id: missedRow
        anchors.centerIn: parent
        visible: !root.ringing
        spacing: 4

        MaterialIconSymbol {
            anchors.verticalCenter: parent.verticalCenter
            content: "phone_missed"
            iconSize: root.iconPx
            customColor: root.ink
        }

        CustomText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.vertical
            content: String(root.missed)
            size: root.labelPx
            weight: 700
            customColor: root.ink
        }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                ServicePhone.silenceRinger()
            else if (mouse.button === Qt.RightButton && !root.ringing)
                ServicePhone.clearMissed()
            else if (mouse.button === Qt.LeftButton && root.host)
                root.host.openPanel("phoneCall", root)
        }
    }

    CustomToolTip {
        content: root.ringing ? (root.call.name + (root.call.name !== root.call.number ? ", " + root.call.number : ""))
            : root.missed === 1 ? "1 missed call" : root.missed + " missed calls"
        detail: root.ringing ? (ServicePhone.ringerMuted ? "Ringer silenced" : "Middle-click to silence the ringer")
            : "Right-click to clear"
        visible: hov.containsMouse && !root.open
    }
}
