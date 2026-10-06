import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Row {
    id: caps

    property string keyString: ""
    property int capSize: 28
    property color capColor: Colors.surfaceContainerHighest
    property color textColor: Colors.surfaceText

    readonly property var parts: ServiceKeybinds.keyParts(caps.keyString)

    spacing: 4

    Repeater {
        model: caps.parts

        Row {
            id: capItem
            required property string modelData
            required property int index
            spacing: 4

            CustomText {
                visible: capItem.index > 0
                anchors.verticalCenter: parent.verticalCenter
                content: "+"
                size: 11
                customColor: Colors.outline
            }

            Rectangle {
                width: Math.max(caps.capSize, capLabel.implicitWidth + 16)
                height: caps.capSize
                radius: 9
                color: caps.capColor

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 2
                    radius: 1
                    color: Qt.alpha("#000000", 0.35)
                }

                CustomText {
                    id: capLabel
                    anchors.centerIn: parent
                    content: capItem.modelData
                    size: 12
                    weight: 600
                    customColor: caps.textColor
                }
            }
        }
    }
}
