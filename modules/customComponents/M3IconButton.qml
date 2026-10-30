import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

// Icon-only M3 button. API-compatible with the former CustomButton.
Rectangle {
    id: root

    property string icon
    property int    iconSize:       20
    property color  iconColor:      Colors.surfaceText
    property color  iconHoverColor: Colors.primaryText
    property int    iconFill:       0
    property bool   enabledButton:  true
    property string tip: ""

    // false: pill (CornerFull).  true: square-ish, morphing on press.
    property bool square: false
    property real squareRadius: 12
    property real pressedRadius: 8

    signal clicked
    signal rightClicked

    implicitWidth: 40
    implicitHeight: 40

    radius: ripple.pressed ? pressedRadius : (square ? squareRadius : height / 2)
    Behavior on radius {
        NumberAnimation {
            duration: M3Motion.container.radiusDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: M3Motion.container.curve
        }
    }

    color: ripple.containsMouse ? Colors.primary : Colors.surfaceContainerHighest
    Behavior on color { ColorAnimation { duration: M3Motion.effects.fastDuration } }

    opacity: enabledButton ? 1 : 0.6

    MaterialIconSymbol {
        anchors.centerIn: parent
        content: root.icon
        iconSize: ripple.pressed ? root.iconSize * 0.9 : root.iconSize
        Behavior on iconSize { SpatialAnim { speed: "fast" } }
        fill: root.iconFill
        color: ripple.containsMouse ? root.iconHoverColor : root.iconColor
        Behavior on color { ColorAnimation { duration: M3Motion.effects.fastDuration } }
        Behavior on fill  { NumberAnimation { duration: M3Motion.effects.defaultDuration } }

    }

    RippleEffect {
        id: ripple
        anchors.fill: parent
        radius: root.radius
        enabled: root.enabledButton
        hoverColor:  Qt.alpha(root.iconHoverColor, 0.08)
        rippleColor: Qt.alpha(root.iconHoverColor, 0.20)
        onClicked: if (root.enabledButton) root.clicked()
        onRightClicked: if (root.enabledButton) root.rightClicked()
    }

    CustomToolTip { content: root.tip; visible: root.tip !== "" && ripple.containsMouse && !ripple.pressed }
}
