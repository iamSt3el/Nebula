import QtQuick
import qs.modules.utils
import qs.modules.customComponents

Rectangle {
    id: root

    property string icon: ""
    property real side: 44
    property bool filled: false
    property bool usable: true
    property real cornerRadius: root.side / 2
    property color tone: Colors.surfaceContainerHigh
    signal tapped

    implicitWidth: root.side
    implicitHeight: root.side
    radius: area.pressed ? Math.min(root.cornerRadius, root.side * 0.3) : root.cornerRadius
    opacity: root.usable ? 1 : 0.4
    color: root.filled
        ? (area.containsMouse ? Qt.lighter(Colors.primary, 1.08) : Colors.primary)
        : area.containsMouse ? (root.tone.a < 0.01 ? Colors.surfaceContainerHigh : Qt.lighter(root.tone, 1.18)) : root.tone

    Behavior on radius { SpatialAnim { speed: "fast" } }
    Behavior on color { EffectsColorAnim {} }

    MaterialIconSymbol {
        anchors.centerIn: parent
        content: root.icon
        iconSize: Math.round(root.side * (root.filled ? 0.5 : 0.52))
        fill: 1
        customColor: root.filled ? Colors.primaryText : Colors.surfaceText
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.usable
        cursorShape: Qt.PointingHandCursor
        onClicked: root.tapped()
    }
}
