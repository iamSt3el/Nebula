import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "clock"
    tile: Qt.size(WidgetSizes.span(4), WidgetSizes.span(2))
    defaultPos: Qt.point(100, 100)
    backdrop: false
    outlined: false

    readonly property bool showStatus: SettingsConfig.widgets.clockStatus ?? true
    readonly property string _family: SettingsConfig.general.defaultFont ?? "Rubik"

    ClockParts { id: t }

    optionsComponent: Component {
        ClockOptions { rows: [{ key: "clockStatus", label: "Status line", sub: "Battery, network and weather under the time", def: true }] }
    }

    ClockLift {
        anchors.fill: parent

        ColumnLayout {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            spacing: 0

            MotionEnter {
                visible: t.showDate
                delay: 220
                dy: 16
                animated: !root.preview

                CustomText {
                    content: (t.weekday + ", " + t.day + " " + t.month).toUpperCase()
                    size: 15
                    weight: 500
                    font.letterSpacing: 3
                    customColor: t.inkVariant
                }
            }

            MotionEnter {
                Layout.topMargin: 6
                Layout.leftMargin: -5
                delay: 60
                dy: 34
                fromScale: 0.96
                animated: !root.preview

                RollText {
                    text: t.time
                    color: t.ink
                    family: root._family
                    pixelSize: 124
                    weight: 600
                    letterSpacing: -6
                    lineHeight: 0.86
                    animated: !root.preview
                }
            }

            MotionEnter {
                visible: root.showStatus
                Layout.topMargin: 14
                delay: 340
                dy: 16
                animated: !root.preview

                Row {
                    spacing: 18

                    Row {
                        visible: UPower.displayDevice?.isLaptopBattery ?? false
                        spacing: 6
                        MaterialIconSymbol { anchors.verticalCenter: parent.verticalCenter; content: ServiceUPower.isCharging ? "battery_android_bolt" : "battery_android_full"; iconSize: 18; customColor: t.accent }
                        CustomText { anchors.verticalCenter: parent.verticalCenter; content: Math.round(ServiceUPower.powerLevel * 100) + "%"; size: 15; weight: 500; customColor: t.inkVariant }
                    }
                    Row {
                        spacing: 6
                        MaterialIconSymbol { anchors.verticalCenter: parent.verticalCenter; content: ServiceNetwork.icon; iconSize: 18; customColor: t.accent }
                        CustomText { anchors.verticalCenter: parent.verticalCenter; content: ServiceNetwork.connectionLabel !== "" ? ServiceNetwork.connectionLabel : "Offline"; size: 15; weight: 500; customColor: t.inkVariant }
                    }
                    Row {
                        visible: ServiceWeather.currentCondition !== null
                        spacing: 6
                        MaterialIconSymbol { anchors.verticalCenter: parent.verticalCenter; content: ServiceWeather.weatherIconPath?.icon ?? "cloud"; iconSize: 18; customColor: t.accent }
                        CustomText { anchors.verticalCenter: parent.verticalCenter; content: ServiceWeather.temperature; size: 15; weight: 500; customColor: t.inkVariant }
                    }
                }
            }
        }
    }
}
