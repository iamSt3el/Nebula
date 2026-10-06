import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true
    readonly property bool iconSizable: true
    readonly property real box: BarLayout.boxFor(root.itemId, root.host)
    readonly property real iconPx: BarLayout.iconPxFor(root.itemId, root.box, 18)
    readonly property real plate: BarLayout.platePxFor(root.box, root.iconPx, 18, 26)
    readonly property color plateColor: volHov.containsMouse ? Colors.primaryContainer : "transparent"
    readonly property bool plateless: BarLayout.chipHovers(root.itemId, root.implicitWidth,
                                                           root.implicitHeight)
    readonly property bool plateOn: root.plateColor.a > 0.01
    readonly property real labelPx: BarLayout.scaleFor(root.iconPx, 18, 13, 8)
    readonly property real gapPx: BarLayout.scaleFor(root.iconPx, 18, 6, 3)
    readonly property real padPx: root.plate - root.iconPx
    readonly property bool fill: BarLayout.opt(root.itemId, "style") === "fill"
    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property bool verticalReady: true

    implicitWidth: volPill.width
    implicitHeight: volPill.height

    Rectangle {
        id: volPill
        anchors.verticalCenter: parent.verticalCenter
        width: root.fill ? fillChip.implicitWidth : root.vertical ? Math.max(root.plate, volRow.implicitWidth + 8)
            : volRow.implicitWidth + root.padPx
        height: root.fill ? fillChip.implicitHeight : root.plate
        radius: Math.min(width, height) / 2
        color: root.plateless || root.fill ? "transparent" : root.plateColor
        Behavior on color { ColorAnimation { duration: 150 } }

        BarFillChip {
            id: fillChip
            anchors.fill: parent
            visible: root.fill
            value: ServicePipewire.muted ? 0 : ServicePipewire.volume
            icon: ServicePipewire.muted ? "volume_off" : "volume_up"
            label: ServicePipewire.muted ? (root.vertical ? "" : "Muted") : Math.round(ServicePipewire.volume * 100) + ""
            vertical: root.vertical
            widthTemplate: "Muted"
            iconPx: root.iconPx - 2
            chipHeight: root.plate
            hovered: volHov.containsMouse
        }

        GridLayout {
            id: volRow
            visible: !root.fill
            anchors.centerIn: parent
            columns: root.vertical ? 1 : -1
            rowSpacing: 1
            columnSpacing: root.gapPx

            MaterialIconSymbol {
                Layout.alignment: Qt.AlignHCenter
                content: ServicePipewire.muted ? "volume_off"
                       : ServicePipewire.volume > 0.6 ? "volume_up"
                       : ServicePipewire.volume > 0.2 ? "volume_down"
                       : "volume_mute"
                iconSize: root.iconPx
                customColor: volHov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                Behavior on customColor { ColorAnimation { duration: 150 } }
            }

            CustomText {
                visible: BarLayout.opt(root.itemId, "showPercent") !== false && !root.vertical
                Layout.alignment: Qt.AlignHCenter
                content: ServicePipewire.muted ? "Muted"
                       : Math.round(ServicePipewire.volume * 100) + (root.vertical ? "" : "%")
                size: root.vertical ? root.labelPx - 2 : root.labelPx; weight: 700
                customColor: volHov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                Behavior on customColor { ColorAnimation { duration: 150 } }
            }
        }

        MouseArea {
            id: volHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    ServicePipewire.toggleMute()
                else if (root.host)
                    root.host.openPanel("sound", root)
            }
            onWheel: wheel => {
                const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                if (d > 0)
                    ServicePipewire.incrementVolume(0.05)
                else if (d < 0)
                    ServicePipewire.decrementVolume(0.05)
            }
        }
    }
}
