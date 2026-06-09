pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.Widgets
import qs.modules.services 
import QtQuick.Shapes


Item{
    id: root
    required property LockContext context
    focus: true
    property bool inputExpanded: false


    Keys.onPressed: (event) => {
        if(!inputExpanded){
            inputExpanded = true
            input.forceActiveFocus();
            // if(event.text.length > 0 && !event.modifiers){
            //     input.text = event.text;
            // }
        }
    }


    Image{
        id: background
        source: WallpaperTheme.wallpaper
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width, height)

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.8
            blurMax: 40
            autoPaddingEnabled: false
        }
    }
    // Button {
    //     text: "Its not working, let me out"
    //     onClicked: context.unlocked();
    // }

    



    NewClock{
        //anchors.centerIn: parent
    }




    Item{
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: 900
        implicitHeight: 100
        Shape {
            id: bgShape
            z: 1
            preferredRendererType: Shape.CurveRenderer

            readonly property real w: container.width
            readonly property real h: container.height
            readonly property real bodyLeft: container.x
            readonly property real bodyRight: container.x + w
            readonly property real bodyBottom: container.y + container.height
            readonly property real bodyTop: bodyBottom - h

            readonly property real rounding: Math.min(h / 3, w / 3)

            readonly property real flareX: w / 18
            readonly property bool flattenFlare: h < flareX * 2
            readonly property real flareY: flattenFlare ? Math.max(0, h / 2) : flareX
            readonly property real flareRadiusY: Math.min(flareX, Math.max(0, h))

            ShapePath {
                strokeWidth: -1
                fillColor: Settings.layoutColor

                startX: bgShape.bodyLeft - bgShape.flareX
                startY: bgShape.bodyBottom

                PathArc {
                    x: bgShape.bodyLeft
                    y: bgShape.bodyBottom - bgShape.flareY
                    radiusX: bgShape.flareX
                    radiusY: bgShape.flareRadiusY
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: bgShape.bodyLeft
                    y: bgShape.bodyTop + bgShape.rounding
                }

                PathArc {
                    x: bgShape.bodyLeft + bgShape.rounding
                    y: bgShape.bodyTop
                    radiusX: bgShape.rounding
                    radiusY: Math.min(bgShape.rounding, bgShape.h)
                }

                PathLine {
                    x: bgShape.bodyRight - bgShape.rounding
                    y: bgShape.bodyTop
                }

                PathArc {
                    x: bgShape.bodyRight
                    y: bgShape.bodyTop + bgShape.rounding
                    radiusX: bgShape.rounding
                    radiusY: Math.min(bgShape.rounding, bgShape.h)
                }

                PathLine {
                    x: bgShape.bodyRight
                    y: bgShape.bodyBottom - bgShape.flareY
                }

                PathArc {
                    x: bgShape.bodyRight + bgShape.flareX
                    y: bgShape.bodyBottom
                    radiusX: bgShape.flareX
                    radiusY: bgShape.flareRadiusY
                    direction: PathArc.Counterclockwise
                }

                PathLine {
                    x: bgShape.bodyLeft - bgShape.flareX
                    y: bgShape.bodyBottom
                }
            }
        }
        Item{
            id: container
            z: 10
            implicitWidth: 800
            implicitHeight: 0
            visible: true
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on implicitHeight{
                NumberAnimation{
                    duration: 300
                    easing.type: Easing.OutQuad
                }
            }

            Connections{
                target: root.context
                function onUnlocked(){
                    container.implicitHeight = 0
                    row.visible = false
                }
            }

            onVisibleChanged:{
                if(!visible){
                    row.visible = false
                }
            }

            Timer{
                id: timer2
                interval: 600
                running: true
                onTriggered:{
                    container.implicitHeight = 80
                }
            }

            Timer{
                id: timer
                interval: 900
                running: true
                onTriggered:{
                    row.visible = true
                }
            }


            RowLayout{
                id: row
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                visible: false

                Rectangle{
                    Layout.preferredWidth: 130
                    Layout.fillHeight: true
                    radius: 20
                    color: Colors.surfaceContainer

                    RowLayout{
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        ClippingWrapperRectangle{
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 10
                            color: Colors.primary
                            Image{
                                source: SettingsConfig.general.profile
                                anchors.fill: parent
                                sourceSize: Qt.size(width, height)
                                fillMode: Qt.PreserveAspectCrop
                            }
                        }
                        ColumnLayout{
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            spacing: 2
                            CustomText{
                                content: "St3el"
                                size: 15
                                color: Colors.surfaceText
                            }
                            CustomText{
                                content: "Hyprland"
                                size: 13
                                color: Colors.outline
                            }
                        }
                    }
                        
                    // MaterialIconSymbol{
                    //     anchors.centerIn: parent
                    //     content: "power"
                    //     iconSize: 30
                    //     color: Colors.surfaceText
                    // }
                }

                Rectangle{
                    Layout.preferredWidth: 400
                    Layout.fillHeight: true
                    radius: 20
                    color: Colors.surfaceContainer
                    RowLayout{
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 0

                        Rectangle{
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            //color: Colors.surfaceContainerHigh
                            color: "transparent"
                            radius: 20
                            MaterialIconSymbol{
                                anchors.centerIn: parent
                                content: "lock"
                                iconSize: 26
                            }
                        }

                        CustomShapeInput {
                            id: input
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            placeholderText: root.context.showFailure ? "Seriously Dude" : "Enter password"
                            placeholderColor: root.context.showFailure ? Colors.error : Colors.outline
                            enabled: !root.context.unlockInProgress

                            onTextChanged: root.context.currentText = text
                            onAccepted: root.context.tryUnlock()

                            Connections {
                                target: root.context
                                function onCurrentTextChanged() {
                                    input.text = root.context.currentText
                                }
                            }
                        } 
                    }

                }
                Rectangle{
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Colors.surfaceContainer
                    radius: 20

                    LockScreenMusicPlayer{
                        anchors.fill: parent
                    }
                }

            } 
        }
    }
}
