import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item{
    id: root
    implicitHeight: notifications.length > 0 ? innerItem.height + 30 : 0
    implicitWidth: 400
    anchors.right: parent.right
    anchors.bottom: parent.bottom

    Behavior on implicitHeight{
        NumberAnimation{
            easing.type: Easing.OutQuad
            duration: 300
        }
    }

    property var notifications: ServiceNotification.popups
    // property real disX: 18
    // property real disY: 18
    // property real radX: 18
    // property real radY: 18

    // Shape{
    //     preferredRendererType: Shape.CurveRenderer
    //     visible: root.height > 0
    //     ShapePath{
    //         strokeWidth: 2
    //         strokeColor: "transparent"
    //         fillColor: Colors.surface
    //         startX: innerItem.x
    //         startY: innerItem.y + innerItem.height 
    //
    //         PathArc{
    //             relativeX: root.disX
    //             relativeY: -root.disY
    //             radiusX: root.radX
    //             radiusY: root.radY
    //             direction: PathArc.Counterclockwise
    //         }
    //
    //         PathLine{
    //             relativeX: 0
    //             relativeY: - (innerItem.height - 3 * root.disY)
    //         }
    //
    //         PathArc{
    //             relativeX: root.disX
    //             relativeY: -root.disY
    //             radiusX: root.radX
    //             radiusY: root.radY
    //         }
    //
    //         PathLine{
    //             relativeX: innerItem.width - 3 * root.disX
    //             relativeY: 0
    //         }
    //
    //         PathArc{
    //             relativeX: root.disX
    //             relativeY: -root.disY
    //             radiusX: root.radX
    //             radiusY: root.radY
    //             direction: PathArc.Counterclockwise
    //         }
    //
    //         PathLine{
    //             relativeX: 0
    //             relativeY: innerItem.height
    //         }
    //
    //     }
    // }

    Item{
        id: innerItem
        width: 400
        height: list.contentHeight + 20
        anchors.bottom: parent.bottom
        anchors.right: parent.right

        ListView{
            id: list
            anchors.fill: parent
            anchors.margins: 10
            orientation: Qt.Vertical
            model: ScriptModel{
                values: [...root.notifications].reverse()
            }
            spacing: 10
            interactive: false

            add: Transition {
                NumberAnimation{
                    property: "x"
                    from: list.width
                    to: 0
                    duration: 300
                    easing.type: Easing.OutQuad
                }
            }

            // addDisplaced: Transition{
            //     NumberAnimation{
            //         property: "y"
            //         duration: 200
            //         easing.type: Easing.OutQuad
            //     }
            // }
            //
            move: Transition {
                NumberAnimation {
                    property: "y"
                    duration: 250
                    easing.type: Easing.OutQuad
                }
            }

            // displaced: Transition {
            //     NumberAnimation {
            //         property: "y"
            //         duration: 250
            //         easing.type: Easing.OutQuad
            //     }
            // }

            delegate: Rectangle{
                id: popup
                implicitWidth: list.width
                implicitHeight: 80
                radius: 20
                color: Colors.surfaceContainerHigh
           

                RowLayout{
                    anchors.fill: parent
                    anchors.margins: 5
                    Image{
                        source: IconUtil.getIconPath(modelData.appIcon)
                        width: 65
                        height: 65
                        sourceSize: Qt.size(width, height)
                        fillMode: Image.PreserveAspectCrop
                    }

                    ColumnLayout{
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                         
                        CustomText{
                            Layout.fillWidth: true
                            content: modelData.summary
                            size: 17
                        }
                        CustomText{
                            Layout.fillWidth: true
                            content: modelData.body
                            size: 14
                            color: Colors.outline
                        }
                    }

                    Loader{
                        active: modelData.image
                        visible: active
                        Layout.preferredHeight: 65
                        Layout.preferredWidth: 65
                        sourceComponent:Image{
                            source: modelData.image
                            anchors.fill: parent
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                }
            }

        }
    }
}
