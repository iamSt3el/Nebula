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
    readonly property color plateColor: hov.containsMouse ? Colors.primaryContainer : Qt.alpha(Colors.primaryContainer, 0)
    readonly property bool plateless: BarLayout.chipHovers(root.itemId, root.implicitWidth, root.implicitHeight)
    readonly property bool plateOn: root.plateColor.a > 0.01
    readonly property real labelPx: BarLayout.scaleFor(root.iconPx, 18, 13, 8)
    readonly property real gapPx: BarLayout.scaleFor(root.iconPx, 18, 6, 3)
    readonly property real padPx: BarLayout.scaleFor(root.iconPx, 18, 18, 8)
    readonly property bool showLabel: BarLayout.opt(root.itemId, "showLabel") === true

    readonly property int profile: ServiceUPower.powerProfile ?? 1
    readonly property var entry: ServiceUPower.powerProfiles[root.profile] ?? ServiceUPower.powerProfiles[1]

    implicitWidth: pill.width
    implicitHeight: root.plate

    Rectangle {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        width: root.showLabel ? row.implicitWidth + root.padPx : root.plate
        height: root.plate
        radius: root.plate / 2
        color: root.plateless ? Qt.alpha(root.plateColor, 0) : root.plateColor
        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: root.gapPx

            MaterialIconSymbol {
                content: root.entry.icon
                iconSize: root.iconPx
                customColor: hov.containsMouse ? Colors.primaryContainerText
                           : root.profile === 2 ? Colors.error
                           : root.profile === 0 ? Colors.tertiary : Colors.surfaceText
                Behavior on customColor { ColorAnimation { duration: 150 } }
            }

            CustomText {
                visible: root.showLabel
                content: root.entry.name
                size: root.labelPx
                weight: 700
                customColor: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
            }
        }

        MouseArea {
            id: hov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.host) root.host.openPanel("powerMode", root)
            onWheel: wheel => {
                const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                if (d === 0)
                    return
                const ids = ServiceUPower.availableProfiles.map(p => p.id)
                const at = Math.max(0, ids.indexOf(root.profile))
                ServiceUPower.setPowerProfile(ids[Math.max(0, Math.min(ids.length - 1, at + (d > 0 ? 1 : -1)))])
            }
        }

        CustomToolTip {
            content: root.entry.name + " mode"
            visible: hov.containsMouse && !root.showLabel
        }
    }
}
