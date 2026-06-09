import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell.Widgets
import qs.modules.customComponents
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MaterialShapeFn

Item{
    id: root
    anchors.fill: parent
    signal closed


    opacity:0
    scale: 0.8

    NumberAnimation on opacity{
        from: 0
        to: 1
        duration: 400
        running: true
    }


    NumberAnimation on scale{
        from: 0.8
        to: 1
        duration: 400
        running: true
    }

    ColumnLayout{
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        RowLayout{
            Layout.fillWidth: true

            Rectangle{
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: Colors.surfaceContainer
                topLeftRadius: 20
                topRightRadius: 5
                bottomLeftRadius: 20
                bottomRightRadius: 5
                CustomText{
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 20
                    content: ServiceWeather.location
                    size: 16
                }
            }

            Rectangle{
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                topLeftRadius: 5
                topRightRadius: 5
                bottomLeftRadius: 5
                bottomRightRadius: 5
                color: Colors.surfaceContainer

                MaterialIconSymbol{
                    anchors.centerIn: parent
                    content: "refresh"
                    iconSize: refreshRipple.containsMouse ? 21 : 18
                    Behavior on iconSize { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                    RotationAnimation on rotation {
                        running: ServiceWeather.isLoading
                        from: 0; to: 360
                        duration: 800
                        loops: Animation.Infinite
                    }
                }

                RippleEffect {
                    id: refreshRipple
                    anchors.fill: parent
                    topLeftRadius: 5; topRightRadius: 5
                    bottomLeftRadius: 5; bottomRightRadius: 5
                    onClicked: ServiceWeather.refresh()
                }
            }
            Rectangle{
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                topLeftRadius: 5
                topRightRadius: 20
                bottomLeftRadius: 5
                bottomRightRadius: 20
                color: Colors.surfaceContainer

                MaterialIconSymbol{
                    anchors.centerIn: parent
                    content: "close"
                    iconSize: closeRipple.containsMouse ? 21 : 18
                    Behavior on iconSize { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                }

                RippleEffect {
                    id: closeRipple
                    anchors.fill: parent
                    topLeftRadius: 5; topRightRadius: 20
                    bottomLeftRadius: 5; bottomRightRadius: 20
                    onClicked: root.closed()
                }
            }
        }


        MaterialShapes.ShapeCanvas{
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: 200
            Layout.preferredHeight: 200
            roundedPolygon: MaterialShapeFn.getPill()
            color: Colors.primary

            CustomText{
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 20
                anchors.rightMargin: 20
                content: ServiceWeather.temperature
                size: 70
                color: Colors.primaryText
                weight: 900
            }


            Image{
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.bottomMargin: 20
                anchors.leftMargin: 20
                source: IconUtil.getSystemIcon(ServiceWeather.weatherIconPath.svg)
                width: 80
                height: 80
                sourceSize: Qt.size(width, height) 
            }
        }
        CustomText{
            Layout.alignment: Qt.AlignCenter
            content: ServiceWeather.description
            size: 20
        }

        CustomText{
            Layout.alignment: Qt.AlignCenter
            content: "Feels like " + ServiceWeather.feelsLike
            size: 20
            color: Colors.outline
        }
        Item{
            Layout.fillHeight: true
        }
        Rectangle{
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            color: Colors.surfaceContainer
            radius: 20
            clip: true

            ColumnLayout{
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                RowLayout{
                    MaterialIconSymbol{
                        content: "schedule"
                        iconSize: 20
                    }
                    CustomText{
                        content: "Hourly forecast"
                        size: 14
                    }
                }

                ListView{
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    orientation: Qt.Horizontal
                    spacing: 10

                    model: ServiceWeather.todayHourly
                    delegate: Item{
                        implicitHeight: parent.height
                        implicitWidth: 50

                        ColumnLayout{
                            anchors.fill: parent
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10

                            Item{
                                Layout.alignment: Qt.AlignCenter
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40


                                Loader{
                                    active: index === 0
                                    visible: active
                                    anchors.fill: parent
                                    sourceComponent:MaterialShapes.ShapeCanvas{
                                        anchors.fill: parent
                                        roundedPolygon: MaterialShapeFn.getCookie4Sided()
                                        color: Colors.primary
                                    }
                                }

                                CustomText{
                                    anchors.centerIn: parent
                                    content: modelData.tempC
                                    size: 16
                                    color:index === 0 ? Colors.primaryText : Colors.surfaceText
                                }
                            }
                            Item{
                                Layout.fillHeight: true
                            }

                            Image{
                                Layout.alignment: Qt.AlignCenter
                                source: IconUtil.getSystemIcon(ServiceWeather.getWeatherIcon(modelData.weatherCode).svg)
                                width: 20
                                height: 20
                                sourceSize: Qt.size(width, height)
                            }

                            CustomText{
                                Layout.alignment: Qt.AlignCenter
                                content: modelData.chanceofrain + "%"
                                size: 14
                                color: Colors.primary
                            }
                            Item{
                                Layout.fillHeight: true
                            }
                            CustomText{
                                Layout.alignment: Qt.AlignCenter
                                content: modelData.time
                                size: 14
                                color: Colors.outline
                            }

                        }
                    }
                }

            }
        }


        RowLayout{
            Layout.fillWidth: true 
            spacing: 10

            Rectangle{
                Layout.preferredHeight: 160
                Layout.fillWidth: true
                radius: 20
                color: Colors.surfaceContainer

                ColumnLayout{
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    RowLayout{

                        MaterialIconSymbol{
                            content: "rainy_heavy"
                            iconSize: 20
                        }

                        CustomText{
                            content: "Precipitation"
                            size: 16
                        }
                    }
                    RowLayout{
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        CustomText{
                            content: ServiceWeather.precipitation
                            size: 28
                            color: Colors.primary
                        }
                        CustomText{
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 5
                            content: "in"
                            size: 16
                        }
                    }

                    RowLayout{
                        Layout.fillWidth: true
                        CustomText{
                            Layout.preferredWidth: 80
                            content: "Total rain for the day"
                            size: 14
                            elide: Text.ElideNone
                            wrapMode: Text.WordWrap

                        }
                        Item{
                            Layout.fillWidth: true
                        }

                        // MaterialIconSymbol{
                        //     content: "rainy"
                        //     iconSize: 40
                        // }
                        Image{
                            width: 40
                            height: 40
                            sourceSize: Qt.size(width, height)
                            source: IconUtil.getSystemIcon("heavy_rain")
                        }
                    }

                }
            }

            Rectangle{
                Layout.preferredHeight: 160
                Layout.preferredWidth: 160
                radius: width / 2
                color: Colors.surfaceContainer


                MaterialShapes.ShapeCanvas{
                    rotation: ServiceWeather.windDegree
                    anchors.centerIn: parent
                    implicitHeight: 150
                    implicitWidth: 135
                    roundedPolygon: MaterialShapeFn.getArrow()
                    color: Qt.alpha(Colors.primary, 0.5)
                }

                ColumnLayout{
                    anchors.centerIn: parent
                    spacing: 20

                    RowLayout{
                        Layout.alignment: Qt.AlignCenter

                        MaterialIconSymbol{
                            content: "air"
                            iconSize: 20
                        }

                        CustomText{
                            content: "Wind"
                            size: 16
                        }
                    }

                    CustomText{
                        Layout.alignment: Qt.AlignCenter
                        content: ServiceWeather.windSpeed
                        size: 20
                        color: Colors.primaryText
                    }

                    CustomText{
                        Layout.alignment: Qt.AlignCenter
                        content: "From " + ServiceWeather.windDirection
                        size: 14
                    }
                }
            }
        }

        RowLayout{
            Layout.fillWidth: true 
            spacing: 10

            Rectangle{
                Layout.preferredHeight: 160
                Layout.fillWidth: true
                radius: 20
                color: Colors.surfaceContainer

                ColumnLayout{
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    RowLayout{
                        Layout.alignment: Qt.AlignCenter
                        spacing: 20
                        Rectangle{
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 50
                            radius: width / 2
                            color: "#FFE97D"
                        }

                        ColumnLayout{
                            spacing: 0
                            CustomText{
                                content: "Sunrise"
                                size: 16
                            }
                            CustomText{
                                content: ServiceWeather.astronomy.sunrise
                                size: 14
                                color: Colors.outline
                            }
                        }
                    }

                    CustomSpermSeparator{
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        frequency: 10
                        color: Colors.outline
                    }

                    RowLayout{
                        Layout.alignment: Qt.AlignCenter
                        spacing: 20


                        ColumnLayout{
                            spacing: 0
                            CustomText{
                                content: "Sunset"
                                size: 16
                            }
                            CustomText{
                                content: ServiceWeather.astronomy.sunset
                                size: 14
                                color: Colors.outline
                            }
                        }

                        Rectangle{
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 50
                            radius: width / 2
                            color: "#D51C39"
                        }
                    }


                }
            }

            Rectangle{
                Layout.preferredWidth: 160
                Layout.preferredHeight: 160
                radius: width / 2
                color: Colors.surfaceContainer

                MaterialShapes.ShapeCanvas{
                    anchors.fill: parent
                    anchors.margins: 10
                    roundedPolygon: MaterialShapeFn.getCookie12Sided()
                    color: Qt.alpha(Colors.primary, 0.5)
                }

                ColumnLayout{
                    anchors.centerIn: parent
                    spacing: 10
                    RowLayout{
                        spacing: 2
                        MaterialIconSymbol{
                            content: "visibility"
                            iconSize: 20
                        }
                        CustomText{
                            content: "Visibility"
                            size: 14
                        }
                    }

                    RowLayout{
                        Layout.alignment: Qt.AlignCenter
                        spacing: 5
                        CustomText{
                            content: ServiceWeather.visibility
                            size: 40
                            color: Colors.primaryText
                        }
                        CustomText{
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 10
                            content: "km"
                            size: 16
                        }
                    }

                    Item{
                        Layout.fillHeight: true
                    }

                }
            }

        }

        RowLayout{
            Layout.fillWidth: true 
            spacing: 10

            ClippingWrapperRectangleInternal{
                Layout.preferredHeight: 160
                Layout.fillWidth: true
                radius: 20
                color: Colors.surfaceContainer


                Canvas {
                    id: wave
                    property color color: Qt.alpha(Colors.primary, 0.5)
                    property real amplitude: 3
                    property real frequency: 6
                    property real lineWidth: 0
                    anchors.bottom: parent.bottom
                    implicitWidth: parent.width
                    implicitHeight: parent.height * ServiceWeather.humidity / 100

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        var waveY

                        // --- draw the filled wavy rectangle ---
                        ctx.beginPath()

                        // 1. trace the wave across the top
                        for (var x = 0; x <= width; x += 1) {
                            waveY = amplitude + amplitude * Math.sin(frequency * 2 * Math.PI * x / width)
                            if (x === 0)
                            ctx.moveTo(x, waveY)
                            else
                            ctx.lineTo(x, waveY)
                        }

                        // 2. go down to bottom-right
                        ctx.lineTo(width, height)

                        // 3. go to bottom-left
                        ctx.lineTo(0, height)

                        // 4. close back to wave start
                        ctx.closePath()

                        ctx.fillStyle = wave.color
                        ctx.fill()


                    }
                }

                ColumnLayout{
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 30

                    RowLayout{
                        MaterialIconSymbol{
                            content: "humidity_low"
                            iconSize: 20
                        }

                        CustomText{
                            content: "Humidity"
                            size: 16
                        }
                    }

                    CustomText{
                        content: ServiceWeather.humidity + "%"
                        size: 40
                        color: Colors.primary
                        weight: 700
                    }

                    Item{
                        Layout.fillHeight: true
                    }
                }
            }

            Rectangle{
                Layout.preferredHeight: 160
                Layout.preferredWidth: 160
                radius: width / 2
                color: Colors.surfaceContainer

                CustomGaugeProgress {
                    anchors.centerIn: parent
                    width: 150
                    height: 150
                    progress: ServiceWeather.pressure
                    thickness: 8
                    gap: 0.1
                    showData: false
                    sperm: false

                    ColumnLayout{
                        anchors.centerIn: parent
                        spacing: 4

                        RowLayout{
                            spacing: 2
                            MaterialIconSymbol{
                                content: "compress"
                                iconSize: 20
                            }
                            CustomText{
                                content: "Pressure"
                                size: 14
                            }
                        }

                        CustomText{
                            Layout.alignment: Qt.AlignCenter
                            content: ServiceWeather.pressureInches
                            size: 30
                            color: Colors.primary
                            weight: 700
                        }

                        CustomText{
                            Layout.alignment: Qt.AlignCenter
                            content: "in"
                            size: 18
                        }
                    }
                }
            }
        }


    }
}


