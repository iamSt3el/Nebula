import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool plateless: BarLayout.chipHovers(root.itemId, 0, 0)
    readonly property bool iconSizable: true
    readonly property real box: BarLayout.boxFor(root.itemId, root.host)
    readonly property real iconPx: BarLayout.iconPxFor(root.itemId, root.box, 16)
    readonly property real plate: BarLayout.platePxFor(root.box, root.iconPx, 16, 26)
    readonly property bool shown: ServiceTools.isRecording
    readonly property bool showTime: BarLayout.opt(root.itemId, "showTime") !== false

    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: root.plate

    Loader {
        id: loader
        active: root.shown
        anchors.verticalCenter: parent.verticalCenter

        sourceComponent: Rectangle {
            implicitWidth: recRow.implicitWidth + BarLayout.scaleFor(root.iconPx, 16, 18, 8)
            implicitHeight: root.plate
            radius: root.plate / 2
            color: recHov.containsMouse && !root.plateless ? Colors.primaryContainer : root.showTime ? Colors.errorContainer : Qt.alpha(Colors.errorContainer, 0)

            Behavior on color         { ColorAnimation  { duration: 150 } }
            Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            RowLayout {
                id: recRow
                anchors.centerIn: parent
                spacing: recHov.containsMouse || root.showTime ? BarLayout.scaleFor(root.iconPx, 16, 6, 3) : 0

                MaterialIconSymbol {
                    content: "screen_record"
                    iconSize: root.iconPx
                    customColor: recHov.containsMouse ? Colors.primaryContainerText
                               : root.showTime ? Colors.errorContainerText : Colors.error
                    Behavior on customColor { ColorAnimation { duration: 150 } }

                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.45; duration: 850; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.00; duration: 850; easing.type: Easing.InOutSine }
                    }
                }

                CustomText {
                    visible: recHov.containsMouse || root.showTime
                    font.features: { "tnum": 1 }
                    content: {
                        const s = ServiceTools.recordingSeconds
                        return String(Math.floor(s / 60)).padStart(2, "0") + ":" +
                               String(s % 60).padStart(2, "0")
                    }
                    size: BarLayout.scaleFor(root.iconPx, 16, 13, 8); weight: 700
                    customColor: recHov.containsMouse ? Colors.primaryContainerText : Colors.errorContainerText
                }
            }

            MouseArea {
                id: recHov
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ServiceTools.stopRecording()
            }

            CustomToolTip { content: "Click to stop recording"; visible: recHov.containsMouse }
        }
    }
}
