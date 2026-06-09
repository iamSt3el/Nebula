import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root
    anchors.fill: parent
    anchors.margins: 5

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        contentWidth: width
        clip: true

        ColumnLayout {
            id: column
            width: parent.width
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            anchors.topMargin: 5
            spacing: 0

            // ── Header ───────────────────────────────────────────────────────
            RowLayout {
                spacing: 10
                MaterialIconSymbol {
                    content: "partly_cloudy_day"
                    iconSize: 20
                }
                CustomText {
                    content: "Weather"
                    size: 20
                    color: Colors.primary
                }
            }

            // ── Location ─────────────────────────────────────────────────────
            CustomText {
                Layout.topMargin: 30
                content: "Location"
                size: 18
                color: Colors.primary
            }
            CustomText {
                content: "Where to fetch weather data for"
                size: 14
                color: Colors.outline
            }

            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 0
                    CustomText {
                        content: "City"
                        size: 16
                    }
                    CustomText {
                        content: "City name or lat,lon coordinates"
                        size: 13
                        color: Colors.outline
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 160
                    Layout.preferredHeight: 34
                    radius: 10
                    color: Colors.surfaceContainerHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6

                        MaterialIconSymbol {
                            content: "location_on"
                            iconSize: 16
                            color: Colors.outline
                        }

                        TextInput {
                            id: locationInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: SettingsConfig.weather.location
                            color: Colors.inverseSurface
                            font.pixelSize: 14
                            clip: true
                            verticalAlignment: TextInput.AlignVCenter

                            onEditingFinished: {
                                if (text.trim().length > 0)
                                    SettingsConfig.weather = Object.assign({}, SettingsConfig.weather, { location: text.trim() })
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.topMargin: 16
                Layout.bottomMargin: 16
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.outline
            }

            // ── Units ────────────────────────────────────────────────────────
            CustomText {
                content: "Units"
                size: 18
                color: Colors.primary
            }
            CustomText {
                content: "Temperature and measurement system"
                size: 14
                color: Colors.outline
            }

            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true
                spacing: 5

                Rectangle {
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: metricRow.implicitWidth + 24
                    topLeftRadius: 15; bottomLeftRadius: 15
                    topRightRadius: 5; bottomRightRadius: 5
                    color: SettingsConfig.weather.useMetric
                           ? Colors.primary : Colors.surfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: metricRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIconSymbol {
                            content: "thermometer"
                            iconSize: 16
                            color: SettingsConfig.weather.useMetric
                                   ? Colors.primaryText : Colors.surfaceVariantText
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        CustomText {
                            content: "Metric (°C)"
                            size: 13
                            color: SettingsConfig.weather.useMetric
                                   ? Colors.primaryText : Colors.surfaceVariantText
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsConfig.weather = Object.assign({}, SettingsConfig.weather, { useMetric: true })
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: imperialRow.implicitWidth + 24
                    topLeftRadius: 5; bottomLeftRadius: 5
                    topRightRadius: 15; bottomRightRadius: 15
                    color: !SettingsConfig.weather.useMetric
                           ? Colors.primary : Colors.surfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: imperialRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIconSymbol {
                            content: "thermometer"
                            iconSize: 16
                            color: !SettingsConfig.weather.useMetric
                                   ? Colors.primaryText : Colors.surfaceVariantText
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        CustomText {
                            content: "Imperial (°F)"
                            size: 13
                            color: !SettingsConfig.weather.useMetric
                                   ? Colors.primaryText : Colors.surfaceVariantText
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsConfig.weather = Object.assign({}, SettingsConfig.weather, { useMetric: false })
                    }
                }

                Item { Layout.fillWidth: true }
            }

            Rectangle {
                Layout.topMargin: 16
                Layout.bottomMargin: 16
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.outline
            }

            // ── Refresh ──────────────────────────────────────────────────────
            CustomText {
                content: "Refresh"
                size: 18
                color: Colors.primary
            }
            CustomText {
                content: "How often to fetch new weather data"
                size: 14
                color: Colors.outline
            }

            RowLayout {
                Layout.topMargin: 14
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 0
                    CustomText {
                        content: "Refresh Interval"
                        size: 16
                    }
                    CustomText {
                        content: "Minutes between automatic updates"
                        size: 13
                        color: Colors.outline
                    }
                }

                Item { Layout.fillWidth: true }

                CustomSpinBox {
                    inc: 5
                    limit: 120
                    Component.onCompleted: val = SettingsConfig.weather.refreshInterval
                    onValChanged: SettingsConfig.weather = Object.assign({}, SettingsConfig.weather, { refreshInterval: val })
                }
            }

            // ── Status card ──────────────────────────────────────────────────
            Rectangle {
                Layout.topMargin: 20
                Layout.fillWidth: true
                Layout.preferredHeight: statusRow.implicitHeight + 16
                radius: 10
                color: Colors.surfaceContainer

                RowLayout {
                    id: statusRow
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            spacing: 6
                            MaterialIconSymbol {
                                content: ServiceWeather.hasError ? "error" : "check_circle"
                                iconSize: 15
                                color: ServiceWeather.hasError ? Colors.error : Colors.outline
                            }
                            CustomText {
                                content: ServiceWeather.hasError
                                         ? "Last fetch failed"
                                         : "Showing: " + ServiceWeather.cityName
                                size: 12
                                color: ServiceWeather.hasError ? Colors.error : Colors.outline
                            }
                        }

                        RowLayout {
                            spacing: 6
                            MaterialIconSymbol { content: "info"; iconSize: 15; color: Colors.outline }
                            CustomText {
                                content: "Location changes take effect on the next refresh"
                                size: 12
                                color: Colors.outline
                            }
                        }
                    }

                    Rectangle {
                        implicitWidth: 34; implicitHeight: 34
                        radius: 10
                        color: refreshArea.containsMouse ? Colors.primary : Colors.surfaceContainerHigh
                        Behavior on color { ColorAnimation { duration: 150 } }
                        enabled: !ServiceWeather.isLoading

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "refresh"
                            iconSize: 18
                            color: refreshArea.containsMouse ? Colors.primaryText : Colors.surfaceVariantText
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RotationAnimation on rotation {
                                running: ServiceWeather.isLoading
                                from: 0; to: 360
                                duration: 800
                                loops: Animation.Infinite
                            }
                        }

                        MouseArea {
                            id: refreshArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ServiceWeather.refresh()
                        }
                    }
                }
            }

            Rectangle {
                Layout.topMargin: 16
                Layout.bottomMargin: 10
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.outline
            }
        }
    }
}
