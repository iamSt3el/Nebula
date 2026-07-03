import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    implicitWidth: 170
    implicitHeight: 205

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

    // Card body
    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Colors.surfaceContainerHigh

        // Month header strip
        Rectangle {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 58
            topLeftRadius: 20
            topRightRadius: 20
            color: Colors.primaryContainer

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 1

                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: ServiceClock.month.toUpperCase()
                    size: 14
                    weight: 700
                    color: Colors.primary
                    font.letterSpacing: 2
                }

                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: ServiceClock.year
                    size: 11
                    color: Colors.outline
                }
            }
        }

        // Date number
        CustomText {
            anchors.top: header.bottom
            anchors.bottom: dayLabel.top
            anchors.horizontalCenter: parent.horizontalCenter
            verticalAlignment: Text.AlignVCenter
            content: ServiceClock.date
            size: 86
            weight: 700
            color: Colors.surfaceText
            font.family: SettingsConfig.general.displayFont ?? "Titan One"
            style: Text.Raised
            styleColor: Colors.outline
        }

        // Day of week at bottom
        CustomText {
            id: dayLabel
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            content: ServiceClock.day.toUpperCase()
            size: 11
            weight: 600
            color: Colors.outline
            font.letterSpacing: 2
        }
    }
}
