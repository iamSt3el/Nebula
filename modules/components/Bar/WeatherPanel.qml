import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import qs.modules.customComponents
import qs.modules.utils
import qs.modules.settings
import qs.modules.services

PopupWindow{
    id: root
    implicitWidth: 240
    implicitHeight: child.implicitHeight
    visible: true
    color: "transparent"
    signal close

    anchor{
        window: layout
        rect.x: utility.x
        rect.y: utility.y + utility.height + 2
    }

    HyprlandFocusGrab{
        id: focusGrab
        active: true
        windows: [QsWindow.window]
        onCleared: root.close()
    }

    Rectangle{
        id: child
        implicitWidth: parent.width
        implicitHeight: col.implicitHeight + 40
        scale: 0.8
        opacity: 0

        NumberAnimation on opacity{
            from: 0
            to: 1
            duration: 100
            running: true
        }

        NumberAnimation on scale{
            from: 0.8
            to: 1
            duration: 100
            running: true
        }

        color: Settings.layoutColor
        radius: 20

        ColumnLayout{
            id: col
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20

            RowLayout{
                Layout.fillWidth: true
                Layout.rightMargin: 20

                ColumnLayout{
                    spacing: 2
                    CustomText{
                        content: ServiceWeather.temperature
                        size: 24
                    }
                    CustomText{
                        content: ServiceWeather.description
                        size: 16
                        color: Colors.outline
                    }

                    CustomText{
                        content: "Feels like " + ServiceWeather.feelsLike
                        size: 14
                        color: Colors.outline
                    }

                }
                Item{
                    Layout.fillWidth: true
                }
                MaterialIconSymbol{
                    content: ServiceWeather.weatherIconPath
                    iconSize: 50
                }
            }

            // Rectangle{
            //     Layout.fillWidth: true
            //     Layout.preferredHeight: 1
            //     color: Colors.outline
            // }

            // RowLayout{
            //     Layout.fillWidth: true
            //     spacing: 4
            //
            //     ColumnLayout{
            //         Layout.fillWidth: true
            //         CustomIconImage{
            //             Layout.alignment: Qt.AlignCenter
            //             icon: "wi-humidity"
            //             size: 20
            //             bright: 1
            //         }
            //
            //         CustomText{
            //             Layout.alignment: Qt.AlignCenter
            //             content: ServiceWeather.humidity
            //             size: 14
            //         }
            //         CustomText{
            //             Layout.alignment: Qt.AlignCenter
            //             content: "Humidity"
            //             size: 12
            //             color: Colors.outline
            //             weight: 600
            //         }
            //     }
            //
            //
            //     Item{
            //         Layout.fillWidth: true
            //     }
            //
            //
            //
            //     ColumnLayout{
            //         Layout.fillWidth: true
            //         CustomIconImage{
            //             Layout.alignment: Qt.AlignCenter
            //             icon: "wi-cloudy"
            //             size: 20
            //             bright: 1
            //         }
            //
            //         CustomText{
            //             Layout.alignment: Qt.AlignCenter
            //             content: ServiceWeather.cloudcover
            //             size: 14
            //         }
            //         CustomText{
            //             Layout.alignment: Qt.AlignCenter
            //             content: "Cloud Cover"
            //             size: 12
            //             color: Colors.outline
            //             weight: 600
            //         }
            //     }
            //     Item{
            //         Layout.fillWidth: true
            //     }
            //
            //     ColumnLayout{
            //         Layout.fillWidth: true
            //         CustomIconImage{
            //             Layout.alignment: Qt.AlignCenter
            //             icon: "wi-windy"
            //             size: 20
            //             bright: 1
            //         }
            //
            //         CustomText{
            //             Layout.alignment: Qt.AlignCenter
            //             content: ServiceWeather.windSpeed
            //             size: 14
            //         }
            //         CustomText{
            //             Layout.alignment: Qt.AlignCenter
            //             content: "Wind Speed"
            //             size: 12
            //             color: Colors.outline
            //             weight: 600
            //         }
            //     }
            // }


            // RowLayout{
            //     Layout.fillWidth: true
            //     spacing: 0
            //     ColumnLayout{
            //         Layout.fillWidth: true
            //         MaterialIconSymbol{
            //             Layout.alignment: Qt.AlignCenter
            //             content: "skull"
            //             iconSize: 22
            //         }
            //
            //         CustomText{
            //             Layout.alignment: Qt.AlignCenter
            //             content: ServiceWeather.aqi
            //             size: 14
            //         }
            //         CustomText{
            //             Layout.alignment: Qt.AlignCenter
            //             content: "     AQI     "
            //             size: 12
            //             color: Colors.outline
            //             weight: 600
            //         }
            //     }
            //
            //     Item{
            //         Layout.fillWidth: true
            //     }
            //
            //     ColumnLayout{
            //         Layout.fillWidth: true
            //         MaterialIconSymbol{
            //             Layout.alignment: Qt.AlignCenter
            //             content: "visibility"
            //             iconSize: 22
            //         }
            //
            //         CustomText{
            //             Layout.alignment: Qt.AlignCenter
            //             content: ServiceWeather.visibility
            //             size: 14
            //         }
            //         CustomText{
            //             Layout.alignment: Qt.AlignCenter
            //             content: "Visibility"
            //             size: 12
            //             color: Colors.outline
            //             weight: 600
            //         }
            //     }
            //
            //     Item{
            //         Layout.fillWidth: true
            //     }
            //
            //     ColumnLayout{
            //         Layout.fillWidth: true
            //         CustomIconImage{
            //             Layout.alignment: Qt.AlignCenter
            //             icon: "wi-day-sunny"
            //             size: 22
            //             bright: 1
            //         }
            //
            //         CustomText{
            //             Layout.alignment: Qt.AlignCenter
            //             content: ServiceWeather.uvindex
            //             size: 14
            //         }
            //         CustomText{
            //             Layout.alignment: Qt.AlignCenter
            //             content: "UV Index"
            //             size: 12
            //             color: Colors.outline
            //             weight: 600
            //         }
            //     }
            // }
        }
    }
}

