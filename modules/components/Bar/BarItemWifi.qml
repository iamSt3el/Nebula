import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true
    readonly property bool iconSizable: true
    readonly property real box: BarLayout.boxFor(root.itemId, root.host)
    readonly property real iconPx: BarLayout.iconPxFor(root.itemId, root.box, 18)
    readonly property color plateColor: hov.containsMouse ? Colors.primaryContainer : Qt.alpha(Colors.primaryContainer, 0)
    readonly property bool plateless: BarLayout.chipHovers(root.itemId, root.implicitWidth,
                                                           root.implicitHeight)
    readonly property bool plateOn: root.plateColor.a > 0.01
    readonly property real plate: BarLayout.platePxFor(root.box, root.iconPx, 18, 28)

    implicitWidth: root.plate
    implicitHeight: root.plate
    radius: root.plate / 2
    color: root.plateless ? Qt.alpha(root.plateColor, 0) : root.plateColor
    Behavior on color { ColorAnimation { duration: 150 } }

    MaterialIconSymbol {
        anchors.centerIn: parent
        content: ServiceNetwork.icon
        iconSize: root.iconPx
        customColor: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
        Behavior on customColor { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.host) root.host.openPanel("network", root)
    }

    CustomToolTip {
        content: ServiceNetwork.connectionLabel.length > 0 ? ServiceNetwork.connectionLabel : "No network"
        detail: ServiceNetwork.connectionType === "ethernet" ? "Wired · " + ServiceNetwork.activeInterface
              : ServiceNetwork.connectedNetwork ? "Signal " + Math.round((ServiceNetwork.connectedNetwork.signalStrength ?? 0) * 100) + "% · click for networks"
              : "Click to pick a network"
        visible: hov.containsMouse && !(root.host && root.host.panelKind === "network")
    }
}
