import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root

    property real progress: 0
    property string icon: ""
    property bool isDragging: false
    signal moved(real value)

    implicitHeight: 48

    readonly property real radius: 16
    readonly property real clamped: Math.max(0, Math.min(1, root.progress))
    readonly property real fillW: root.width * root.clamped
    readonly property bool iconOverFill: root.fillW > root.width - 26

    scale: root.isDragging ? 1.02 : 1
    Behavior on scale {
        NumberAnimation {
            duration: Appearance.motion.spatialFast
            easing.type: Appearance.motion.spatialEasing
            easing.overshoot: Appearance.motion.spatialOvershoot
        }
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: root.radius
        color: Colors.surfaceContainerHigh
        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.fillW
            radius: root.radius
            color: Colors.primary
            visible: width > 1
        }
    }

    MaterialIconSymbol {
        anchors.right: parent.right
        anchors.rightMargin: 13
        anchors.verticalCenter: parent.verticalCenter
        content: root.icon
        iconSize: 19
        customColor: root.iconOverFill ? Colors.primaryText : Colors.surfaceVariantText
        Behavior on customColor {
            ColorAnimation {
                duration: Appearance.motion.effectsDefault
                easing.type: Appearance.motion.effectsEasing
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function applyAt(mx) {
            const v = Math.max(0, Math.min(1, mx / Math.max(1, root.width)))
            root.progress = v
            root.moved(v)
        }

        onPressed: event => { root.isDragging = true; applyAt(event.x) }
        onPositionChanged: event => { if (pressed) applyAt(event.x) }
        onReleased: root.isDragging = false
        onCanceled: root.isDragging = false
    }
}
