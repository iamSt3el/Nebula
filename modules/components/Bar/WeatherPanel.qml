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

        // ── Header bar ───────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: 20
            color: Colors.surfaceContainer

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 8
                spacing: 10

                MaterialIconSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    content: "location_on"
                    iconSize: 20
                    customColor: Colors.primary
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    CustomText {
                        content: ServiceWeather.cityName !== "Unknown"
                            ? ServiceWeather.cityName
                            : ServiceWeather.location
                        size: 14
                        weight: 700
                    }
                    CustomText {
                        content: Qt.formatDate(new Date(), "dddd, MMMM d")
                        size: 11
                        customColor: Colors.outline
                    }
                }

                Item { Layout.fillWidth: true }

                Timer {
                    id: tickTimer
                    interval: 60000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: 36
                    implicitWidth: refreshRow.implicitWidth + 20
                    radius: 18
                    color: refreshRipple.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainerHighest

                    RowLayout {
                        id: refreshRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIconSymbol {
                            Layout.alignment: Qt.AlignVCenter
                            content: "refresh"
                            iconSize: 16
                            customColor: ServiceWeather.isLoading ? Colors.primary : Colors.outline
                        }

                        CustomText {
                            Layout.alignment: Qt.AlignVCenter
                            content: {
                                tickTimer.running
                                if (!ServiceWeather.lastUpdated) return ServiceWeather.isLoading ? "updating…" : "—"
                                if (ServiceWeather.isLoading) return "updating…"
                                var mins = Math.floor((new Date() - ServiceWeather.lastUpdated) / 60000)
                                if (mins < 1) return "just now"
                                if (mins < 60) return mins + "m ago"
                                return Math.floor(mins / 60) + "h ago"
                            }
                            size: 11
                            customColor: Colors.outline
                        }
                    }

                    RippleEffect {
                        id: refreshRipple
                        anchors.fill: parent
                        radius: 18
                        onClicked: ServiceWeather.refresh()
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 36; height: 36; radius: 18
                    color: closeRipple.containsMouse ? Colors.surfaceContainerHigh : "transparent"

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "close"
                        iconSize: 18
                    }
                    RippleEffect {
                        id: closeRipple
                        anchors.fill: parent
                        radius: 18
                        onClicked: root.closed()
                    }
                }
            }
        }

        // ── Hero card (temp + stats combined) ───────────────────────────
        ClippingWrapperRectangleInternal {
            Layout.fillWidth: true
            implicitHeight: heroColumn.implicitHeight + 40
            radius: 20
            color: Colors.surfaceContainer

            // Decorative burst — clipped to rounded corners by ClippingWrapper
            MaterialShapes.ShapeCanvas {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -30
                anchors.topMargin: -25
                implicitWidth: 140
                implicitHeight: 140
                roundedPolygon: MaterialShapeFn.getSoftBurst()
                color: Qt.alpha(Colors.primary, 0.09)
            }

            ColumnLayout {
                id: heroColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                spacing: 16

                // Icon + temperature block
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    // Weather icon in shaped badge
                    Item {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 80
                        Layout.alignment: Qt.AlignVCenter

                        MaterialShapes.ShapeCanvas {
                            anchors.fill: parent
                            roundedPolygon: MaterialShapeFn.getCookie7Sided()
                            color: Qt.alpha(Colors.primary, 0.18)
                        }
                        Image {
                            anchors.centerIn: parent
                            width: 52; height: 52
                            source: IconUtil.getSystemIcon(ServiceWeather.weatherIconPath.svg)
                            sourceSize: Qt.size(width, height)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        CustomText {
                            content: ServiceWeather.temperature
                            size: 50
                            color: Colors.primary
                            weight: 900
                        }

                        RowLayout {
                            spacing: 10
                            CustomText {
                                content: "↑ " + (ServiceWeather.useMetric
                                    ? (ServiceWeather.forecastDays[0]?.maxtempC ?? "--") + "°"
                                    : (ServiceWeather.forecastDays[0]?.maxtempF ?? "--") + "°")
                                size: 13
                                color: Colors.inverseSurface
                            }
                            CustomText {
                                content: "↓ " + (ServiceWeather.useMetric
                                    ? (ServiceWeather.forecastDays[0]?.mintempC ?? "--") + "°"
                                    : (ServiceWeather.forecastDays[0]?.mintempF ?? "--") + "°")
                                size: 13
                                color: Colors.outline
                            }
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: ServiceWeather.description
                            size: 14
                            color: Colors.inverseSurface
                        }

                        CustomText {
                            content: "Feels like " + ServiceWeather.feelsLike
                            size: 12
                            color: Colors.outline
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Colors.outline
                    opacity: 0.25
                }

                // Four stat mini-cards
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    spacing: 8

                    Repeater {
                        model: [
                            { icon: "wb_sunny",   label: "UV Index", val: ServiceWeather.uvindex             },
                            { icon: "cloud",      label: "Cloud",    val: ServiceWeather.cloudcover           },
                            { icon: "visibility", label: "Visibility", val: ServiceWeather.visibility + " km" },
                            { icon: "water_drop", label: "Rain",     val: ServiceWeather.precipitation + " in"}
                        ]

                        delegate: Item {
                            Layout.fillWidth: true
                            implicitHeight: 58

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3

                                MaterialIconSymbol {
                                    Layout.alignment: Qt.AlignHCenter
                                    content: modelData.icon
                                    iconSize: 15
                                    color: Colors.primary
                                }
                                CustomText {
                                    Layout.alignment: Qt.AlignHCenter
                                    content: modelData.val
                                    size: 12
                                    weight: 700
                                    color: Colors.inverseSurface
                                }
                                CustomText {
                                    Layout.alignment: Qt.AlignHCenter
                                    content: modelData.label
                                    size: 10
                                    color: Colors.outline
                                }
                            }
                        }
                    }
                }
            }
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


