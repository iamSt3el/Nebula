import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MaterialShapeFn

Rectangle{
    radius: 20
    color: Colors.surfaceContainer

    Component.onCompleted: ServiceCava.retain()
    Component.onDestruction: ServiceCava.release()
    ColumnLayout{
        anchors.fill: parent
        spacing: 0
        Rectangle{
            color: Colors.surfaceContainerHigh
            radius: 20
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            RowLayout{
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                // ClippingWrapperRectangle{
                //     Layout.preferredWidth: 80
                //     Layout.preferredHeight: 80
                //     radius: 10
                //     color: Colors.surfaceContainerHighest
                //     Image{
                //         anchors.fill: parent
                //         sourceSize: Qt.size(width, height)
                //         fillMode: Image.PreserveAspectCrop
                //         source: ServiceMusic.activeTrack?.artUrl ?? ""
                //     }
                // }
                Item{
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 80

                    // Animated cookie12 shape — tips driven by ServiceCava.cavaData12
                    Canvas {
                        id: vizShape
                        anchors.centerIn: parent
                        width: 120
                        height: 120
                        antialiasing: true

                        property real shapeRotation: 0
                        property color fillColor: Colors.primary

                        NumberAnimation on shapeRotation {
                            from: 0
                            to: 360
                            duration: 20000
                            loops: Animation.Infinite
                            running: ServiceMusic.isPlaying
                        }

                        onShapeRotationChanged: requestPaint()
                        onFillColorChanged: requestPaint()

                        Connections {
                            target: ServiceCava
                            function onCavaData12Changed() { vizShape.requestPaint() }
                        }

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()

                            const cx = width / 2
                            const cy = height / 2

                            // cookie12 = star(12, 1, 0.8) + rotate30, normalised to 90×90.
                            // Center at (45,45) in ShapeCanvas px → same physical point as (cx,cy) here
                            // (both canvases use anchors.centerIn: parent on the same 80×80 Item).
                            // Outer tips reach ~44 px from center, inner valleys ~35 px.
                            const baseOuterR = 44
                            const valleyR    = 35
                            const maxExt     = 25   // max extra px when a bar is at full amplitude

                            const rotRad = shapeRotation * Math.PI / 180

                            // After rotate30 (+30°) applied to star(12,1,0.8):
                            //   tip i   at angle  π/6·(i+1)          → 30°,60°,…,360°
                            //   valley i at angle  π/12·(2i+3)        → 45°,75°,…,15°
                            const data = ServiceCava.cavaData12
                            const verts = []
                            for (let i = 0; i < 12; i++) {
                                const tipAngle = (Math.PI / 6 * (i + 1)) + rotRad
                                const valAngle = (Math.PI / 12 * (2 * i + 3)) + rotRad
                                const tipR = baseOuterR + (data.length === 12 ? data[i] : 0) * maxExt

                                verts.push({x: cx + tipR    * Math.cos(tipAngle),
                                            y: cy + tipR    * Math.sin(tipAngle)})
                                verts.push({x: cx + valleyR * Math.cos(valAngle),
                                            y: cy + valleyR * Math.sin(valAngle)})
                            }

                            // Draw smooth star via quadratic curves through midpoints
                            ctx.beginPath()
                            const last = verts[verts.length - 1]
                            const first = verts[0]
                            ctx.moveTo((last.x + first.x) / 2, (last.y + first.y) / 2)
                            for (let i = 0; i < verts.length; i++) {
                                const cur  = verts[i]
                                const next = verts[(i + 1) % verts.length]
                                ctx.quadraticCurveTo(cur.x, cur.y,
                                                     (cur.x + next.x) / 2,
                                                     (cur.y + next.y) / 2)
                            }
                            ctx.closePath()
                            ctx.fillStyle = fillColor
                            ctx.fill()
                        }
                    }

                    Item {
                        id: artMask
                        anchors.fill: parent
                        layer.enabled: true
                        opacity: 0

                        MaterialShapes.ShapeCanvas{
                            anchors.fill: parent
                            roundedPolygon: MaterialShapeFn.getCookie12Sided()
                            color: "white"
                            NumberAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 20000
                                loops: Animation.Infinite
                                running: ServiceMusic.isPlaying
                            }
                        }
                    }

                    Image{
                        id: albumArt
                        anchors.fill: parent
                        sourceSize: Qt.size(width, height)
                        fillMode: Image.PreserveAspectCrop
                        source: ServiceMusic.activeTrack?.artUrl ?? ""
                        visible: false
                        layer.enabled: true
                    }

                    MultiEffect{
                        source: albumArt
                        anchors.fill: albumArt
                        maskEnabled: true
                        maskSource: artMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                }


                ColumnLayout{
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    CustomText{
                        Layout.fillWidth: true
                        content: ServiceMusic.activeTrack?.title ?? "Unknown Title"
                        size: 14
                    }

                    CustomText{
                        Layout.fillWidth: true
                        content: ServiceMusic.activeTrack?.artist ?? "Unknown Artist"
                        color: Colors.outline
                        size: 12
                    }

                    Item{
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.bottomMargin: 5

                        ColumnLayout{
                            anchors.fill: parent
                            RowLayout{
                                Layout.fillWidth: true
                                CustomText{
                                    Layout.fillWidth: true
                                    content: ServiceMusic.formatTime(ServiceMusic.activePlayer?.position ?? 0)
                                    size: 12
                                }

                                CustomText{
                                    content: ServiceMusic.formatTime(ServiceMusic.activePlayer?.length ?? 0)
                                    horizontalAlignment: Text.AlignHCenter
                                    size: 12
                                }
                            }

                            CustomProgressBar{
                                value: (ServiceMusic.activePlayer?.position / Math.max(ServiceMusic.activePlayer?.length, 1) || 0)
                                valueBarWidth: parent.width
                                sperm: true
                                animateSperm: ServiceMusic.isPlaying
                            }
                        }
                    }
                }

            }
        }
        Item{
            Layout.fillHeight: true
            Layout.fillWidth: true
            RowLayout{
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5

                Rectangle{
                    Layout.preferredWidth: 50
                    Layout.fillHeight: true
                    radius: 20
                    color: loopArea.containsMouse ? Colors.primary : Colors.surfaceContainerHigh
                    Behavior on color{
                        ColorAnimation{
                            duration: 200
                        }
                    }
                    Behavior on scale{
                        NumberAnimation{
                            duration: 100
                        }
                    }
                    MaterialIconSymbol{
                        anchors.centerIn: parent
                        content: "all_inclusive"
                        iconSize: 20
                        color: loopArea.containsMouse ? Colors.primaryText : Colors.surfaceText
                    }
         
                    
                    CustomMouseArea{
                        radius: parent.radius
                        id: loopArea
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked:{
                            ServiceMusic.togglePlaying()
                        }
                    }
                }

                Rectangle{
                    Layout.preferredWidth: 40
                    Layout.fillHeight: true
                    radius: 20
                    color: sArea.containsMouse ? Colors.primary : Colors.surfaceContainerHigh
                    Behavior on color{
                        ColorAnimation{
                            duration: 200
                        }
                    }
                    Behavior on scale{
                        NumberAnimation{
                            duration: 100
                        }
                    }
                    MaterialIconSymbol{
                        anchors.centerIn: parent
                        content: "shuffle"
                        iconSize: 20
                        color: sArea.containsMouse ? Colors.primaryText : Colors.surfaceText
                    }
      
                    CustomMouseArea{
                        radius: parent.radius
                        id: sArea
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked:{
                            ServiceMusic.togglePlaying()
                        }
                    }
                }


                Rectangle{
                    Layout.preferredWidth: 50
                    Layout.fillHeight: true
                    radius: 20
                    color: lArea.containsMouse ? Colors.primary : Colors.surfaceContainerHigh
                    Behavior on color{
                        ColorAnimation{
                            duration: 200
                        }
                    }

                    Behavior on scale{
                        NumberAnimation{
                            duration: 100
                        }
                    }
                   MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "fast_rewind"
                        iconSize: 20
                        color: lArea.containsMouse ? Colors.primaryText : Colors.surfaceText
                    }
                    CustomMouseArea{
                        radius: parent.radius
                        id: lArea
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked:{
                            ServiceMusic.previous()
                        }
                    }
                }
                Rectangle{
                    Layout.preferredWidth: 40
                    Layout.fillHeight: true
                    radius: 20
                    color: pArea.containsMouse ? Colors.primary : Colors.surfaceContainerHigh
                    Behavior on scale{
                        NumberAnimation{
                            duration: 100
                        }
                    }
                    Behavior on color{
                        ColorAnimation{
                            duration: 200
                        }
                    }
                    MaterialIconSymbol{
                        anchors.centerIn: parent
                        content: ServiceMusic.isPlaying ? "pause" : "play_arrow"
                        iconSize: 20
                        color: pArea.containsMouse ? Colors.primaryText : Colors.surfaceText
                    }



                    CustomMouseArea{
                        radius: parent.radius
                        id: pArea
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked:{
                            ServiceMusic.togglePlaying()
                        }
                    }

                }
                Rectangle{
                    Layout.preferredWidth: 50
                    Layout.fillHeight: true
                    radius: 20
                    color: nArea.containsMouse ? Colors.primary : Colors.surfaceContainerHigh
                    Behavior on color{
                        ColorAnimation{
                            duration: 200
                        }
                    } 
                    Behavior on scale{
                        NumberAnimation{
                            duration: 100
                        }
                    }

                    MaterialIconSymbol{
                        anchors.centerIn: parent
                        content: "fast_forward"
                        iconSize: 20
                        color: nArea.containsMouse ? Colors.primaryText : Colors.surfaceText

                    }


                    CustomMouseArea{
                        radius: parent.radius
                        id: nArea
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked:{
                            ServiceMusic.next()
                        }
                    }

                }
            }
        }
    }
}
