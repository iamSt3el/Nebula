import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    implicitWidth: 195
    implicitHeight: 185

    property bool editMode: false

    scale: root.editMode ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    layer.enabled: root.editMode
    layer.smooth: true
    layer.textureSize: root.editMode ? Qt.size(width * 1.05, height * 1.05) : Qt.size(width, height)

    Component.onCompleted: {
        root.x = SettingsConfig.widgets.dateWidgetX ?? 300
        root.y = SettingsConfig.widgets.dateWidgetY ?? 300
    }

    Connections {
        target: SettingsConfig
        function onWidgetsChanged() {
            if (!root.editMode) {
                root.x = SettingsConfig.widgets.dateWidgetX ?? 300
                root.y = SettingsConfig.widgets.dateWidgetY ?? 300
            }
        }
    }

    onXChanged: if (editMode) saveTimer.restart()
    onYChanged: if (editMode) saveTimer.restart()

    Timer {
        id: saveTimer
        interval: 500
        repeat: false
        onTriggered: {
            SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, {
                dateWidgetX: root.x, dateWidgetY: root.y
            })
        }
    }

    MouseArea {
        anchors.fill: parent
        drag.target: root.editMode ? root : undefined
        cursorShape: root.editMode ? Qt.SizeAllCursor : Qt.ArrowCursor
        onDoubleClicked: root.editMode = true
        onReleased: if (root.editMode) root.editMode = false
    }

    Rectangle {
        anchors.fill: parent
        radius: 24
        color: Colors.surface

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0

            // Day name — small, spaced out, primary
            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: ServiceClock.day.toUpperCase()
                size: 11
                weight: 700
                color: Colors.primary
                font.letterSpacing: 3
            }

            // Huge date — takes up most of the card
            CustomText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: -6
                content: ServiceClock.date
                size: 115
                weight: 700
                color: Colors.primary
                font.family: SettingsConfig.general.displayFont ?? "Titan One"
                style: Text.Raised
                styleColor: Colors.outline
            }

            // Month · Year — compact below
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: -14
                spacing: 8

                CustomText {
                    content: ServiceClock.month
                    size: 13
                    weight: 600
                    color: Colors.surfaceText
                    font.family: SettingsConfig.general.displayFont ?? "Titan One"
                }

                Rectangle {
                    implicitWidth: 3
                    implicitHeight: 3
                    radius: 2
                    color: Colors.outline
                }

                CustomText {
                    content: ServiceClock.year
                    size: 13
                    weight: 600
                    color: Colors.outline
                    font.family: SettingsConfig.general.displayFont ?? "Titan One"
                }
            }
        }
    }
}
