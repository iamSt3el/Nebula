import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    implicitWidth: 220
    implicitHeight: col.implicitHeight

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
        radius: 8
        visible: root.editMode
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: 0

        // Day name — small caps, primary, wide tracking
        CustomText {
            content: ServiceClock.day.slice(0, 3).toUpperCase()
            size: 12
            weight: 700
            customColor: Colors.primary
            font.letterSpacing: 5
        }

        // Huge ghost date number — raised shadow gives depth without a box
        CustomText {
            Layout.topMargin: -6
            content: ServiceClock.date
            size: 120
            weight: 700
            customColor: Colors.surfaceText
            font.family: SettingsConfig.general.displayFont ?? "Titan One"
            style: Text.Raised
            styleColor: Qt.alpha(Colors.primary, 0.35)
        }

        // Month · Year below, flush left
        RowLayout {
            Layout.topMargin: -18
            spacing: 6

            CustomText {
                content: ServiceClock.month.toUpperCase()
                size: 12
                weight: 600
                customColor: Colors.outline
                font.letterSpacing: 2
            }

            Rectangle {
                implicitWidth: 3; implicitHeight: 3; radius: 2
                color: Colors.primary
                opacity: 0.6
            }

            CustomText {
                content: ServiceClock.year
                size: 12
                weight: 400
                customColor: Colors.outline
            }
        }
    }
}
