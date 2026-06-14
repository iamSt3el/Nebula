import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents


Item{
    id: root
    anchors.fill: parent


    property bool isMenuOpen: true
    property var currentPage: 0
    signal settingClosed
    scale: 0.7

    opacity: 0

    NumberAnimation on opacity{
        from: 0
        to: 1
        duration: 200
        running: true
    }
    NumberAnimation on scale{
        from: 0.7
        to: 1
        duration: 100
        running: true
    }



    Rectangle{
        anchors.fill: parent
        radius: 20
        color: Colors.surface

        Rectangle{
            anchors.fill: parent
            anchors.margins: 10
            radius: 20
            color: Colors.surfaceContainer


            
            RowLayout{
                anchors.fill: parent

                Rectangle{
                    Layout.fillHeight: true
                    Layout.preferredWidth: 150
                    radius:20
                    color: Colors.surfaceContainerHigh

                    ColumnLayout{

                        anchors.fill: parent
                        anchors.margins: 10

                        CustomText{
                            content: "Nebula"
                            size: 22
                            weight: 700
                        }
                        CustomText{
                            content: "v0.1.0-beta"
                            size: 12
                            color: Colors.outline
                        }

                        Item{
                            Layout.preferredHeight: 20
                        }

                        Item{
                            Layout.fillWidth: true
                            Layout.preferredHeight: navColumn.implicitHeight

                            Rectangle{
                                id: navHighlight
                                width: parent.width
                                height: 40
                                radius: 10
                                color: Colors.primary
                                y: root.currentPage * (40 + navColumn.spacing)

                                Behavior on y{
                                    NumberAnimation{
                                        duration: 200
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }

                            Column{
                                id: navColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 5

                                Repeater{
                                    model: Settings.pages

                                    delegate: Item{
                                        id: delegateItem
                                        property bool active: root.currentPage === index
                                        width: navColumn.width
                                        height: 40

                                        // hover overlay
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 10
                                            color: navMouse.containsMouse && !active
                                                   ? Qt.rgba(0.5, 0.5, 0.5, 0.08)
                                                   : "transparent"
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }

                                        RowLayout{
                                            anchors.fill: parent
                                            anchors.margins: 5
                                            spacing: 10

                                            Item {
                                                implicitWidth: 22
                                                implicitHeight: 22

                                                MaterialIconSymbol{
                                                    id: navIcon
                                                    anchors.centerIn: parent
                                                    content: modelData.icon
                                                    iconSize: 20
                                                    layer.enabled: true
                                                    layer.smooth: true
                                                    color: active ? Colors.primaryText : Colors.surfaceVariantText

                                                    fill: (navMouse.pressed || active) ? 1 : 0
                                                    Behavior on fill {
                                                        NumberAnimation { duration: 200 }
                                                    }

                                                    rotation: navMouse.pressed       ? 25
                                                            : navMouse.containsMouse ? 15
                                                            : active                 ? 20
                                                            : 0
                                                    Behavior on rotation {
                                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                                    }

                                                    Behavior on color {
                                                        ColorAnimation { duration: 150 }
                                                    }

                                                    transform: Rotation {
                                                        id: flipRotation
                                                        origin.x: navIcon.width / 2
                                                        origin.y: navIcon.height / 2
                                                        axis { x: 0; y: 1; z: 0 }
                                                        angle: 0
                                                    }

                                                    states: State {
                                                        name: "flipped"
                                                        when: navMouse.pressed
                                                        PropertyChanges { target: flipRotation; angle: 180 }
                                                    }

                                                    transitions: Transition {
                                                        NumberAnimation {
                                                            target: flipRotation
                                                            property: "angle"
                                                            duration: 300
                                                            easing.type: Easing.OutCubic
                                                        }
                                                    }
                                                }
                                            }

                                            CustomText{
                                                Layout.fillWidth: true
                                                content: modelData.name
                                                size: 15
                                                weight: active ? 800 : 600
                                                color: active ? Colors.primaryText : Colors.surfaceVariantText

                                                Behavior on color {
                                                    ColorAnimation { duration: 150 }
                                                }
                                            }
                                        }

                                        MouseArea{
                                            id: navMouse
                                            anchors.fill: parent
                                            cursorShape: GlobalStates.fileDialogOpen ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            hoverEnabled: !GlobalStates.fileDialogOpen
                                            enabled: !GlobalStates.fileDialogOpen
                                            onClicked: root.currentPage = index
                                        }
                                    }
                                }
                            }
                        }

                        Item{
                            Layout.fillHeight: true
                        }

                        Rectangle{
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: 15
                            color: Colors.primary

                            RowLayout{
                                anchors.centerIn: parent
                                MaterialIconSymbol{
                                    content: "edit"
                                    size: 20
                                    color: Colors.primaryText
                                }
                                CustomText{
                                    content: "Edit Config"
                                    size: 14
                                    color: Colors.primaryText
                                }
                            }
                        }
                    }
                }
                Item{
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    
                    Loader{
                        anchors.fill: parent
                        active: root.currentPage === 0
                        sourceComponent:General{}
                    }
                    Loader{
                        anchors.fill: parent
                        active: root.currentPage === 1
                        sourceComponent: Theme{}
                    }

                    Loader{
                        anchors.fill: parent
                        active: root.currentPage === 2
                        sourceComponent: Sound{}
                    }

                    Loader{
                        anchors.fill: parent
                        active: root.currentPage === 3
                        sourceComponent: Networking{}
                    }

                     Loader{
                        anchors.fill: parent
                        active: root.currentPage === 4
                        sourceComponent: Bluetooth{}
                    }

                    // Loader{
                    //     anchors.fill: parent
                    //     active: root.currentPage === 3
                    //     sourceComponent: Keybindings{}
                    // }

                    Loader{
                        anchors.fill: parent
                        active: root.currentPage === 5
                        sourceComponent: Ai{}
                    }
                    Loader{
                        anchors.fill: parent
                        active: root.currentPage === 6
                        sourceComponent: MangaReader{}
                    }

                    Loader{
                        anchors.fill: parent
                        active: root.currentPage === 7
                        sourceComponent: WeatherSettings{}
                    }

                    Loader{
                        anchors.fill: parent
                        active: root.currentPage === 8
                        sourceComponent: MediaSettings{}
                    }

                    Loader{
                        anchors.fill: parent
                        active: root.currentPage === 9
                        sourceComponent: About{}
                    }



                }

            }

            Rectangle{
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.rightMargin: 10
                implicitWidth: 30
                implicitHeight: 30
                radius: 10
                color: closeArea.containsMouse ? Colors.primary : Colors.surfaceContainerHighest

                MaterialIconSymbol{
                    anchors.centerIn: parent
                    content: "close"
                    iconSize: 16
                    color: closeArea.containsMouse ? Colors.primaryText : Colors.surfaceText
                }

                MouseArea{
                    id: closeArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.settingClosed()

                }
            }
        }

    }
}
