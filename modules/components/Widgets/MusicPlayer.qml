import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents


ClippingRectangle{
    id: musicRoot
    implicitHeight: 160
    implicitWidth: 320
    radius: 20
    color: "black"

    property bool editMode: false

    scale: musicRoot.editMode ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    layer.enabled: musicRoot.editMode
    layer.smooth: true
    layer.textureSize: musicRoot.editMode ? Qt.size(width * 1.05, height * 1.05) : Qt.size(width, height)

    // Overlay — only active in edit mode; blocks buttons and handles drag + exit
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: musicRoot.radius
        visible: musicRoot.editMode
        z: 10

        MouseArea {
            anchors.fill: parent
            drag.target: musicRoot
            cursorShape: Qt.SizeAllCursor
            onReleased: if (musicRoot.editMode) musicRoot.editMode = false
        }
    }

    // Double-click on album art (right side, no buttons there) to enter edit mode
    MouseArea {
        x: musicRoot.implicitWidth / 2
        y: 0
        width: musicRoot.implicitWidth / 2
        height: musicRoot.implicitHeight
        visible: !musicRoot.editMode
        z: 5
        cursorShape: Qt.PointingHandCursor
        onDoubleClicked: musicRoot.editMode = true
    }

    // Full-card blurred album art background
    Image {
        anchors.right: parent.right
        width: 160
        height: 160
        source: ServiceMusic.activeTrack?.artUrl ?? ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(parent.width, parent.height)
        asynchronous: true

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.2
            blurMax: 32
            autoPaddingEnabled: false
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            // fully opaque left side
            GradientStop { position: 0.0;  color: Qt.rgba(
                parseInt(MusicTheme.surface.slice(1,3), 16) / 255,
                parseInt(MusicTheme.surface.slice(3,5), 16) / 255,
                parseInt(MusicTheme.surface.slice(5,7), 16) / 255,
                1.0) }
                // still opaque at image boundary (x=160, 53% of 300)
                GradientStop { position: 0.55; color: Qt.rgba(
                    parseInt(MusicTheme.surface.slice(1,3), 16) / 255,
                    parseInt(MusicTheme.surface.slice(3,5), 16) / 255,
                    parseInt(MusicTheme.surface.slice(5,7), 16) / 255,
                    1.0) }
                    // fades over the image
                    GradientStop { position: 0.90; color: Qt.rgba(
                        parseInt(MusicTheme.surface.slice(1,3), 16) / 255,
                        parseInt(MusicTheme.surface.slice(3,5), 16) / 255,
                        parseInt(MusicTheme.surface.slice(5,7), 16) / 255,
                        0.2) }
                        GradientStop { position: 1.0;  color: Qt.rgba(
                            parseInt(MusicTheme.surface.slice(1,3), 16) / 255,
                            parseInt(MusicTheme.surface.slice(3,5), 16) / 255,
                            parseInt(MusicTheme.surface.slice(5,7), 16) / 255,
                            0.0) }
                        }
                    }

                    ColumnLayout{
                        anchors.fill: parent
                        anchors.margins: 10

                        CustomText{
                            content: "Zen"
                            size: 12
                            color: MusicTheme.outline
                        }
                        CustomText{
                            Layout.fillWidth: true
                            content: ServiceMusic.activeTrack?.title ?? "Unknown Title"
                            size: 15
                            color: MusicTheme.primary
                        }

                        CustomText{
                            Layout.fillWidth: true
                            content: ServiceMusic.activeTrack?.artist ?? "Unknown Artist"
                            size: 12
                            color: MusicTheme.outline
                        }

                        RowLayout{
                            spacing: 26
                            MaterialIconSymbol {
                                content: "fast_rewind"
                                iconSize: 20
                                color: MusicTheme.primary
                                MouseArea{
                                    enabled: !musicRoot.editMode
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked:{
                                        ServiceMusic.previous()
                                    }
                                }
                            }

                            MaterialIconSymbol{
                                content: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                                iconSize: 20
                                color: MusicTheme.primary
                                MouseArea{
                                    enabled: !musicRoot.editMode
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked:{
                                        ServiceMusic.togglePlaying()
                                    }
                                }
                            }
                            MaterialIconSymbol {
                                content: "fast_forward"
                                iconSize: 20
                                color: MusicTheme.primary
                                MouseArea{
                                    enabled: !musicRoot.editMode
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked:{
                                        ServiceMusic.next()
                                    }
                                }
                            }

                            // MaterialIconSymbol {
                            //     content: "shuffle"
                            //     iconSize: 20
                            //     color: MusicTheme.primary
                            //     MouseArea{
                            //         anchors.fill: parent
                            //         cursorShape: Qt.PointingHandCursor
                            //
                            //         onClicked:{
                            //             ServiceMusic.setShuffle()
                            //         }
                            //     }
                            // }
                        }
                        CustomProgressBar{
                            value: (ServiceMusic.activePlayer?.position / Math.max(ServiceMusic.activePlayer?.length, 1) || 0)
                            valueBarWidth: parent.width
                            sperm: true
                            animateSperm: ServiceMusic.isPlaying
                            highlightColor: MusicTheme.primary
                            trackColor: MusicTheme.outline
                        }

                        RowLayout{
                            Layout.fillWidth: true
                            CustomText{
                                Layout.fillWidth: true
                                content: ServiceMusic.formatTime(ServiceMusic.activePlayer?.position ?? 0)
                                size: 10
                            }

                            CustomText{
                                content: ServiceMusic.formatTime(ServiceMusic.activePlayer?.length ?? 0)
                                horizontalAlignment: Text.AlignHCenter
                                size: 10
                            }
                        }
                    } 
                }
