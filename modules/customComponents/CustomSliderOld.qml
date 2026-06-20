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
    signal change



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
            property var progress: 1

            Rectangle {
                implicitWidth: parent.width
                anchors.top: parent.top
                implicitHeight: (parent.height - 14) * (1 - wrapper.progress)
                color: Colors.surfaceContainerHigh
                topLeftRadius: 12
                topRightRadius: 12

                MaterialIconSymbol{
                    visible: lower.height < height + 5
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    content: root.icon
                    iconSize: 24
                    color: Colors.surfaceText
                }
            }
            Rectangle {
                id: lower
                implicitHeight: (parent.height - 14) * wrapper.progress
                implicitWidth: parent.width
                anchors.bottom: parent.bottom
                color: Colors.primary
                bottomLeftRadius: 12
                bottomRightRadius: 12


                MaterialIconSymbol{
                    visible: parent.height > height + 5
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    content: root.icon
                    iconSize: 24
                    color: Colors.primaryText
                }
            }
            // Track click area (full height)
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    let pct = 1 - ((mouse.y - 7) / (parent.height - 14));
                    wrapper.progress = Math.max(0, Math.min(1, pct));
                    root.change();
                }
                onPressed: mouse => {
                    let pct = 1 - ((mouse.y - 7) / (parent.height - 14));
                    wrapper.progress = Math.max(0, Math.min(1, pct));
                    root.change();
                }
                onPositionChanged: mouse => {
                    if (pressed) {
                        let pct = 1 - ((mouse.y - 7) / (parent.height - 14));
                        wrapper.progress = Math.max(0, Math.min(1, pct));
                        root.change();
                    }
                }
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
                    preventStealing: true
                    onPositionChanged: {
                        if (drag.active) {
                            root.change()

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
            implicitHeight: 16          // thin dimension (was implicitWidth: 40)
            implicitWidth: parent.width // long dimension (was implicitHeight: parent.height)
            color: "transparent"
            radius: 6
            anchors.centerIn: parent
            property var progress: wrapper.progress

            // inactive = right portion
            Rectangle {
                implicitHeight: parent.height
                anchors.right: parent.right
                implicitWidth: (parent.width - 14) * (1 - wrapperH.progress)
                color: Qt.alpha(Colors.primary, 0.5)
                topRightRadius: 6
                bottomRightRadius: 6
            }
            // active = left portion
            Rectangle {
                implicitWidth: (parent.width - 14) * wrapperH.progress
                implicitHeight: parent.height
                anchors.left: parent.left
                color: Colors.primary
                topLeftRadius: 6
                bottomLeftRadius: 6
            }
            // Track click area (full width)
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    let pct = (mouse.x - 7) / (parent.width - 14);
                    wrapperH.progress = Math.max(0, Math.min(1, pct));
                    wrapper.progress = wrapperH.progress;
                    root.change();
                }
                onPressed: mouse => {
                    let pct = (mouse.x - 7) / (parent.width - 14);
                    wrapperH.progress = Math.max(0, Math.min(1, pct));
                    wrapper.progress = wrapperH.progress;
                    root.change();
                }
                onPositionChanged: mouse => {
                    if (pressed) {
                        let pct = (mouse.x - 7) / (parent.width - 14);
                        wrapperH.progress = Math.max(0, Math.min(1, pct));
                        wrapper.progress = wrapperH.progress;
                        root.change();
                    }
                }
            }

            // handler — tall and thin (inverted from vertical)
            Rectangle {
                id: handlerH
                implicitWidth: 8
                implicitHeight: 22
                color: Colors.primary
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                x: (parent.width - 14) * wrapperH.progress + 7 - (width / 2)

                MouseArea {
                    anchors.fill: parent
                    drag.target: handlerH
                    drag.axis: Drag.XAxis
                    drag.minimumX: 0
                    drag.maximumX: wrapperH.width - 14
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onPositionChanged: {
                        if (drag.active) {
                            let pct = (handlerH.x - 6 + handlerH.width / 2) / (wrapperH.width - 14);
                            wrapperH.progress = Math.max(0, Math.min(1, pct));
                            wrapper.progress = wrapperH.progress;
                            root.change();
                        }
                    }
                }
            }
        }
    }
}
