import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    implicitWidth: row.implicitWidth + 48
    implicitHeight: 72

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
        radius: 36
        color: Colors.surfaceContainerHigh

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 20

            // Day name
            ColumnLayout {
                spacing: 2
                Layout.alignment: Qt.AlignVCenter
                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: ServiceClock.day.slice(0, 3).toUpperCase()
                    size: 10
                    weight: 700
                    color: Colors.outline
                    font.letterSpacing: 1.5
                }
                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: ServiceClock.month.slice(0, 3).toUpperCase()
                    size: 10
                    weight: 700
                    color: Colors.primary
                    font.letterSpacing: 1.5
                }
            }

            // Divider
            Rectangle {
                implicitWidth: 1
                implicitHeight: 36
                color: Qt.alpha(Colors.outline, 0.25)
            }

            // Date number
            CustomText {
                content: ServiceClock.date
                size: 38
                weight: 700
                color: Colors.surfaceText
                font.family: SettingsConfig.general.displayFont ?? "Titan One"
                style: Text.Raised
                styleColor: Colors.outline
            }

            // Divider
            Rectangle {
                implicitWidth: 1
                implicitHeight: 36
                color: Qt.alpha(Colors.outline, 0.25)
            }

            // Year
            CustomText {
                content: ServiceClock.year
                size: 12
                weight: 600
                color: Colors.outline
                font.family: SettingsConfig.general.displayFont ?? "Titan One"
            }
        }
    }
}
