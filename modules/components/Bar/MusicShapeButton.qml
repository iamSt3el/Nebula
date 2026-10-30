import QtQuick
import qs.modules.utils
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes

Item {
    id: root

    property string icon: ""
    property string shape: "clover4"
    property string pressShape: "circle"
    property real side: 52
    property real iconSize: Math.round(root.side * 0.46)
    property color tone: Colors.surfaceContainerHigh
    property color hoverTone: Qt.lighter(root.tone, 1.15)
    property color iconColor: Colors.surfaceText
    property real ringWidth: 0
    property color ringColor: "transparent"
    property bool usable: true
    signal tapped

    implicitWidth: root.side
    implicitHeight: root.side
    opacity: root.usable ? 1 : 0.4

    MaterialShapes.ShapeCanvas {
        anchors.fill: parent
        roundedPolygon: area.pressed ? root.pressShape : root.shape
        color: area.containsMouse ? root.hoverTone : root.tone
        borderWidth: root.ringWidth
        borderColor: root.ringColor
        Behavior on color { EffectsColorAnim { speed: "fast" } }
    }

    MaterialIconSymbol {
        anchors.centerIn: parent
        content: root.icon
        iconSize: root.iconSize
        fill: 1
        customColor: root.iconColor
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
