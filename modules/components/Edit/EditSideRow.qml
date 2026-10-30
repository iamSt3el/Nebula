import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Rectangle {
    id: row

    property string icon: ""
    property string label: ""
    property string value: ""
    property bool lit: false
    property bool chevron: true
    property string trailing: "chevron_right"
    property bool accent: false
    signal clicked

    Layout.fillWidth: true
    implicitHeight: 40
    radius: ripple.pressed ? 8 : 12
    color: row.lit ? Colors.secondaryContainer : "transparent"
    Behavior on radius {
        NumberAnimation {
            duration: M3Motion.container.radiusDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: M3Motion.container.curve
        }
    }
    Behavior on color { EffectsColorAnim { speed: "fast" } }

    readonly property color ink: row.lit ? Colors.secondaryContainerText : row.accent ? Colors.primary : Colors.surfaceText
    readonly property color soft: row.lit ? Colors.secondaryContainerText : Colors.surfaceVariantText

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 8

        MaterialIconSymbol {
            visible: row.icon !== ""
            content: row.icon
            iconSize: 18
            customColor: row.accent ? Colors.primary : row.soft
        }

        CustomText {
            Layout.fillWidth: true
            content: row.label
            size: 13
            weight: row.accent ? 600 : 500
            elide: Text.ElideRight
            customColor: row.ink
        }

        CustomText {
            visible: row.value !== ""
            Layout.maximumWidth: row.width * 0.45
            content: row.value
            size: 12
            elide: Text.ElideRight
            customColor: row.soft
        }

        MaterialIconSymbol {
            visible: row.chevron
            content: row.trailing
            iconSize: 18
            customColor: row.accent ? Colors.primary : row.soft
        }
    }

    RippleEffect {
        id: ripple
        anchors.fill: parent
        radius: row.radius
        onClicked: row.clicked()
    }
}
