import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import Qt.labs.platform
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MaterialShapeFn

Item{
    id: root
    anchors.fill: parent
    anchors.margins: 5

    FileDialog {
        id: imagePicker
        title: "Select a profile image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.gif)"]
        onAccepted: {
            SettingsConfig.general = Object.assign({}, SettingsConfig.general, {profile: imagePicker.file.toString().replace(/^file:\/\//, "")})
            GlobalStates.fileDialogOpen = false
        }
        onRejected: GlobalStates.fileDialogOpen = false
    }

    Flickable{
        id: flickable
        anchors.fill: parent  
        contentHeight: column.implicitHeight
        contentWidth: width   
        clip: true

        ColumnLayout{
            id: column
            width: parent.width
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            anchors.topMargin: 5
            spacing: 0
            RowLayout{
                spacing: 10
                MaterialIconSymbol{
                    content: "tune"
                    iconSize: 20
                }

                CustomText{
                    content: "General"
                    size: 20
                    color: Colors.primary
                }
            }

            CustomText{
                Layout.topMargin: 30
                content: "Profile"
                size: 18
                color: Colors.primary
            }
            CustomText{
                content: "Set your name and avatar shown across the shell"
                size: 14
                color: Colors.outline
            }


            RowLayout{
                Layout.topMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                spacing: 10

                Item{
                    Layout.preferredWidth: 90    
                    Layout.preferredHeight: 90
                    MaterialShapes.ShapeCanvas{
                        id: artMask
                        anchors.fill: parent
                        roundedPolygon: MaterialShapeFn.getPill()
                        color: Colors.primary
                    }

                    Image{
                        id: profileArt
                        anchors.fill: parent
                        sourceSize: Qt.size(width, height)
                        source: SettingsConfig.general.profile
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                        layer.enabled: true
                    }
                    MultiEffect{
                        source: profileArt
                        anchors.fill: profileArt
                        maskEnabled: true
                        maskSource: artMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }

                }

                ColumnLayout{
                    Layout.alignment: Qt.AlignLeft
                    Layout.fillHeight: true
                    CustomText{
                        content: "St3el"
                        size: 18
                    }
                    Item{
                        Layout.fillHeight: true
                    }
                    CustomText{
                        content: "Shown in the overview and lock screen"
                        size: 12
                        color: Colors.outline
                    }

                    RowLayout{
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        spacing: 4
                        Rectangle{
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            topLeftRadius: 15
                            bottomLeftRadius: 15
                            topRightRadius: 5
                            bottomRightRadius: 5
                            color: Colors.surfaceContainerHighest
                            CustomText{
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                content: SettingsConfig.general.profile
                                size: 12
                            }
                        }

                        CustomButton{
                            Layout.fillHeight: true
                            Layout.preferredWidth: 40
                            topLeftRadius: 5
                            bottomLeftRadius: 5
                            topRightRadius: 15
                            bottomRightRadius: 15
                            icon: "image"
                            iconSize: 18
                            onClicked: {
                                GlobalStates.fileDialogOpen = true
                                imagePicker.open()
                            }
                        }
                    }
                }
            }
            Rectangle{
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.outline
            }


            CustomText{
                content: "Fonts"
                size: 18
                color: Colors.primary
            }
            CustomText{
                content: "Font used across the shell interface"
                size: 14
                color: Colors.outline
            }



            RowLayout{
                Layout.topMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                ColumnLayout{
                    Layout.fillHeight: true
                    spacing: 0
                    CustomText{
                        content: "Default Font"
                        size: 16
                    }
                    CustomText{
                        content: "Applied globally to all text elements"
                        size: 13
                        color: Colors.outline
                    }
                }
                Item{
                    Layout.fillWidth: true
                }

                CustomListNew{
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 200
                    currentVal: SettingsConfig.general.defaultFont
                    list: Settings.fonts

                    onCurrentValChanged: {
                        if (currentVal)
                            SettingsConfig.general = Object.assign({}, SettingsConfig.general, {defaultFont: currentVal})
                    }

                }

            }
            Rectangle{
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.outline
            }


            CustomText{
                content: "Dock"
                size: 18
                color: Colors.primary
            }
            CustomText{
                content: "Configure dock visibility and behavior"
                size: 14
                color: Colors.outline
            }

            RowLayout{
                Layout.topMargin: 10
                Layout.fillWidth: true
                ColumnLayout{
                    spacing: 0
                    CustomText{
                        content: "Dock"
                        size: 16
                    }
                    CustomText{
                        content: "Show or hide the application dock"
                        size: 13
                        color: Colors.outline
                    }
                }

                Item{
                    Layout.fillWidth: true
                }

                CustomToogle{
                    isToggleOn: SettingsConfig.general.dock
                    onToggled: function(state) {
                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, {dock: state})
                    }
                }
            }

            RowLayout{
                Layout.topMargin: 10
                Layout.fillWidth: true
                ColumnLayout{
                    spacing: 0
                    CustomText{
                        content: "Autohide"
                        size: 16
                    }
                    CustomText{
                        content: "Dock hides when a window overlaps it"
                        size: 13
                        color: Colors.outline
                    }
                }

                Item{
                    Layout.fillWidth: true
                }

                CustomToogle{
                    isToggleOn: SettingsConfig.general.dockAutoHide
                    onToggled: function(state) {
                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, {dockAutoHide: state})
                    }
                }
            }

            RowLayout{
                Layout.topMargin: 10
                Layout.fillWidth: true
                ColumnLayout{
                    spacing: 0
                    CustomText{
                        content: "Music Player"
                        size: 16
                    }
                    CustomText{
                        content: "Show the mini player in the dock"
                        size: 13
                        color: Colors.outline
                    }
                }

                Item{
                    Layout.fillWidth: true
                }

                CustomToogle{
                    isToggleOn: SettingsConfig.general.dockMusicPlayer
                    onToggled: function(state) {
                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, {dockMusicPlayer: state})
                    }
                }
            }

            Rectangle{
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.outline
            }


            CustomText{
                content: "Music Visualizer"
                size: 18
                color: Colors.primary
            }
            CustomText{
                content: "Control the audio frequency visualizer in the bar"
                size: 14
                color: Colors.outline
            }

            RowLayout{
                Layout.topMargin: 10
                Layout.fillWidth: true
                ColumnLayout{
                    spacing: 0
                    CustomText{
                        content: "Visualizer"
                        size: 16
                    }
                    CustomText{
                        content: "Display audio bars alongside the music player"
                        size: 13
                        color: Colors.outline
                    }
                }

                Item{
                    Layout.fillWidth: true
                }

                CustomToogle{
                    isToggleOn: SettingsConfig.general.musicVisOn
                    onToggled: function(state) {
                        SettingsConfig.general = Object.assign({}, SettingsConfig.general, {musicVisOn: state})
                    }
                }
            }
            

            RowLayout{
                Layout.topMargin: 10
                ColumnLayout{
                    spacing: 0
                    CustomText{
                        content: "Music Visualizer Colors"
                        size: 16
                    }
                    CustomText{
                        content: "Two accent colors blended across the frequency bars"
                        size: 13
                        color: Colors.outline
                    }
                }
                Item{
                    Layout.fillWidth: true
                }


                Rectangle{
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 30
                    radius: 10
                    color: Colors.primary

                    MaterialIconSymbol{
                        anchors.centerIn: parent
                        content: "palette"
                        iconSize: 20
                        color: Colors.primaryText
                    }
                    MouseArea{
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: colorPicker.active = true
                    }
                }
            }
            RowLayout{
                Layout.topMargin: 10
                Layout.fillWidth: true

                ColumnLayout{
                    CustomText{
                        content: "Music Visualizer Bars"
                        size: 16
                    }

                    CustomText{
                        content: "Number of frequency bands to render"
                        size: 13
                        color: Colors.outline
                    }
                }

                Item{
                    Layout.fillWidth: true
                }

                CustomSpinBox{
                    Component.onCompleted: val = SettingsConfig.general.musicVisBars
                    onValChanged: SettingsConfig.general = Object.assign({}, SettingsConfig.general, {musicVisBars: val})
                }


            }
            Rectangle{
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.outline
            }

        }
    }  

    Loader{
        id: colorPicker
        active: false

        onActiveChanged:{
            if(active){
                grab.active = false
            }else{
                grab.active = true
            }
        }
        sourceComponent: CustomCircularColorPicker{
            onClose:{
                colorPicker.active = false
            }
            onColorsChanged: (first, second, third) => {
                SettingsConfig.theme = Object.assign({}, SettingsConfig.theme, {
                    firstColor: first.toString(),
                    secondColor: second.toString(),
                    thirdColor: third.toString()
                })
            }
        }

    }

}
