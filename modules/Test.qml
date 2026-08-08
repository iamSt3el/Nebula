import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell
import Quickshell.Io
import QtQuick.Effects
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents
import "MatrialShapes/" as MaterialShapes
import "MatrialShapes/material-shapes.js" as MaterialShapeFn

Scope {
    PanelWindow {
        id: bar
        visible: true
        implicitHeight: 400
        implicitWidth: 400
        color: Colors.surface
        

        Rectangle{
            id: root
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 40
            implicitHeight: expanded ? 300 : 150
            implicitWidth: 300
            color: Colors.surfaceContainer
            radius: 20

            Behavior on implicitHeight{
                NumberAnimation{
                    duration: M3Motion.spatial.defaultDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: M3Motion.spatialCurve("fast")
                }
            }
            property bool expanded: false

            ColumnLayout{
            anchors.fill: parent
                RowLayout{
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    Rectangle{
                        Layout.margins: 10
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: Colors.primary


                        MaterialIconSymbol{
                            anchors.centerIn: parent
                            content: "camera"
                            iconSize: 18
                            color: Colors.primaryText
                        }
                    }

                    CustomText{
                        content: "notify-send"
                        color: Colors.outline
                    }

                    CustomText{
                        content: "now"
                    }
                    Item{
                        Layout.fillWidth: true
                    }

                    Rectangle{
                        Layout.rightMargin: 20
                        Layout.preferredHeight: 25
                        Layout.preferredWidth: 40
                        color: Colors.surfaceContainerHigh
                        radius: 20
                        MaterialIconSymbol{
                            anchors.centerIn: parent
                            content: "keyboard_arrow_down"
                            iconSize: 16
                        }


                        MouseArea{
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked:{
                                root.expanded = !root.expanded
                            }
                        }

                    }
                }

                ListView{
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: Qt.Vertical
                    spacing: 10
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10

                    model: 3

                    delegate: Rectangle{
                        implicitWidth: parent.width
                        implicitHeight: root.expanded ? 60 : 20
                        color: "transparent"
                        radius: 20

                        RowLayout{

                        }
                    }

                }
            }

            
        }
    }
}
