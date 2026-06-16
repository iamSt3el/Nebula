import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    implicitWidth: 200
    implicitHeight: 110

    property bool editMode: false

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
        onDoubleClicked: root.editMode = !root.editMode
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: root.editMode ? "#aaffffff" : "transparent"
        border.width: 2
        radius: 4
        visible: root.editMode
    }

    // Left accent bar — only visual element besides text
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 4
        radius: 2
        color: Colors.primary
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        // Day name
        CustomText {
            content: ServiceClock.day.toUpperCase()
            size: 10
            weight: 700
            customColor: Colors.outline
            font.letterSpacing: 3
        }

        // Date + month/year side by side
        RowLayout {
            spacing: 10
            Layout.topMargin: -2

            CustomText {
                content: ServiceClock.date
                size: 64
                weight: 700
                customColor: Colors.primary
                font.family: SettingsConfig.general.displayFont ?? "Titan One"
                style: Text.Raised
                styleColor: Qt.alpha(Colors.primary, 0.2)
            }

            ColumnLayout {
                spacing: 1
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 10

                CustomText {
                    content: ServiceClock.month
                    size: 14
                    weight: 600
                    customColor: Colors.surfaceText
                }

                CustomText {
                    content: ServiceClock.year
                    size: 11
                    weight: 400
                    customColor: Colors.outline
                }
            }
        }
    }
}
