import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    implicitWidth: 210
    implicitHeight: 110

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

    Row {
        anchors.fill: parent
        spacing: 0

        // Left — date number on primary background
        Rectangle {
            width: 90
            height: parent.height
            topLeftRadius: 22
            bottomLeftRadius: 22
            color: Colors.primary

            CustomText {
                anchors.centerIn: parent
                content: ServiceClock.date
                size: 54
                weight: 700
                color: Colors.primaryText
                font.family: SettingsConfig.general.displayFont ?? "Titan One"
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.2)
            }
        }

        // Right — day name + month + year stacked
        Rectangle {
            width: parent.width - 90
            height: parent.height
            topRightRadius: 22
            bottomRightRadius: 22
            color: Colors.surfaceContainerHigh

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 3

                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: ServiceClock.day.toUpperCase().slice(0, 3)
                    size: 10
                    weight: 700
                    color: Colors.outline
                    font.letterSpacing: 2
                }

                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: ServiceClock.month
                    size: 17
                    weight: 700
                    color: Colors.surfaceText
                    font.family: SettingsConfig.general.displayFont ?? "Titan One"
                }

                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: ServiceClock.year
                    size: 11
                    color: Colors.outline
                }
            }
        }
    }
}
