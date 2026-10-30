pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

GridLayout {
    id: tc

    property var model: []
    property string current: ""
    property int cols: 2
    signal picked(string value)

    columns: tc.cols
    columnSpacing: 6
    rowSpacing: 6

    Repeater {
        model: tc.model

        delegate: Rectangle {
            id: tile
            required property var modelData
            readonly property bool on: tc.current === tile.modelData.value

            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            implicitHeight: tileCol.implicitHeight + 18
            radius: tileRipple.pressed ? 8 : tile.on ? 18 : 14
            color: tile.on ? Colors.secondaryContainer : Colors.surfaceContainerHigh
            Behavior on color { EffectsColorAnim { speed: "fast" } }
            Behavior on radius {
                NumberAnimation {
                    duration: M3Motion.container.radiusDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: M3Motion.container.curve
                }
            }

            ColumnLayout {
                id: tileCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    CustomText {
                        Layout.fillWidth: true
                        content: tile.modelData.label
                        size: 13
                        weight: 600
                        customColor: tile.on ? Colors.secondaryContainerText : Colors.surfaceText
                    }
                    MaterialIconSymbol {
                        visible: tile.on
                        content: "check"
                        iconSize: 16
                        customColor: Colors.secondaryContainerText
                    }
                }

                CustomText {
                    Layout.fillWidth: true
                    visible: (tile.modelData.desc ?? "") !== ""
                    content: tile.modelData.desc ?? ""
                    size: 11
                    wrapMode: Text.WordWrap
                    customColor: tile.on ? Colors.secondaryContainerText : Colors.surfaceVariantText
                }
            }

            RippleEffect {
                id: tileRipple
                anchors.fill: parent
                radius: tile.radius
                hoverColor: Qt.alpha(Colors.surfaceText, 0.08)
                rippleColor: Qt.alpha(tile.on ? Colors.secondaryContainerText : Colors.primary, 0.2)
                onClicked: tc.picked(tile.modelData.value)
            }
        }
    }
}
