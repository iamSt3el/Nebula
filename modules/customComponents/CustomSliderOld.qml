import Quickshell
import QtQuick
import Quickshell.Widgets
import qs.modules.utils
import QtQuick.Effects
import qs.modules.customComponents

Item {
    id: root
    property alias progress: wrapper.progress
    property string icon
    property bool isDragging: false
    property bool horizontal: false

    // vertical
    Column {
        visible: !root.horizontal
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        spacing: 10

        Rectangle {
            id: wrapper
            implicitWidth: 40
            implicitHeight: parent.height
            color: "transparent"
            radius: 8
            anchors.horizontalCenter: parent.horizontalCenter
            property var progress: 0.2

            Rectangle {
                implicitWidth: parent.width
                anchors.top: parent.top
                implicitHeight: (parent.height - 14) * (1 - wrapper.progress)
                color: Qt.alpha(Colors.primary, 0.5)
                topLeftRadius: 8
                topRightRadius: 8
            }
            Rectangle {
                implicitHeight: (parent.height - 14) * wrapper.progress
                implicitWidth: parent.width
                anchors.bottom: parent.bottom
                color: Colors.primary
                bottomLeftRadius: 8
                bottomRightRadius: 8
            }
            Rectangle {
                id: handler
                implicitHeight: 6
                implicitWidth: 48
                color: Colors.primary
                radius: 2
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - 14) * (1 - wrapper.progress) + 7 - (height / 2)

                MouseArea {
                    anchors.fill: parent
                    drag.target: handler
                    drag.axis: Drag.YAxis
                    drag.minimumY: 0
                    drag.maximumY: wrapper.height - 14
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: {
                        if (drag.active) {
                            let pct = 1 - ((handler.y - 6 + handler.height / 2) / (wrapper.height - 14));
                            wrapper.progress = Math.max(0, Math.min(1, pct));
                        }
                    }
                }
            }
        }
    }

    // horizontal — width plays the role height had, height plays the role width had
    Item {
        visible: root.horizontal
        width: parent.width
        height: parent.height
        anchors.centerIn: parent

        Rectangle {
            id: wrapperH
            implicitHeight: 40          // thin dimension (was implicitWidth: 40)
            implicitWidth: parent.width // long dimension (was implicitHeight: parent.height)
            color: "transparent"
            radius: 8
            anchors.centerIn: parent
            property var progress: wrapper.progress

            // inactive = right portion
            Rectangle {
                implicitHeight: parent.height
                anchors.right: parent.right
                implicitWidth: (parent.width - 14) * (1 - wrapperH.progress)
                color: Qt.alpha(Colors.primary, 0.5)
                topRightRadius: 8
                bottomRightRadius: 8
            }
            // active = left portion
            Rectangle {
                implicitWidth: (parent.width - 14) * wrapperH.progress
                implicitHeight: parent.height
                anchors.left: parent.left
                color: Colors.primary
                topLeftRadius: 8
                bottomLeftRadius: 8
            }
            // handler — tall and thin (inverted from vertical)
            Rectangle {
                id: handlerH
                implicitWidth: 6        // was implicitHeight: 6
                implicitHeight: 48      // was implicitWidth: 48
                color: Colors.primary
                radius: 2
                anchors.verticalCenter: parent.verticalCenter
                x: (parent.width - 14) * wrapperH.progress + 7 - (width / 2)

                MouseArea {
                    anchors.fill: parent
                    drag.target: handlerH
                    drag.axis: Drag.XAxis
                    drag.minimumX: 0
                    drag.maximumX: wrapperH.width - 14
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: {
                        if (drag.active) {
                            let pct = (handlerH.x - 6 + handlerH.width / 2) / (wrapperH.width - 14);
                            wrapperH.progress = Math.max(0, Math.min(1, pct));
                            wrapper.progress = wrapperH.progress;
                        }
                    }
                }
            }
        }
    }
}
