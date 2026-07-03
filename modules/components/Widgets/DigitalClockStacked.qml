import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    property bool editMode: false

    scale: root.editMode ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    layer.enabled: root.editMode
    layer.smooth: true
    layer.textureSize: root.editMode ? Qt.size(width * 1.05, height * 1.05) : Qt.size(width, height)

    Component.onCompleted: {
        root.x = SettingsConfig.widgets.clockX ?? 100
        root.y = SettingsConfig.widgets.clockY ?? 100
    }

    Connections {
        target: SettingsConfig
        function onWidgetsChanged() {
            if (!root.editMode) {
                root.x = SettingsConfig.widgets.clockX ?? 100
                root.y = SettingsConfig.widgets.clockY ?? 100
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
                clockX: root.x, clockY: root.y
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

    ColumnLayout {
        id: col
        spacing: -8

        CustomText {
            Layout.alignment: Qt.AlignHCenter
            content: ServiceClock.time
            size: 100
            weight: 800
            color: Colors.surfaceText
            font.family: SettingsConfig.general.displayFont ?? "Titan One"
            style: Text.Raised
            styleColor: Colors.outline
        }

        CustomText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            content: ServiceClock.day + ", " + ServiceClock.month + " " + ServiceClock.date
            size: 22
            weight: 700
            color: Colors.primary
            font.family: SettingsConfig.general.displayFont ?? "Titan One"
        }
    }
}
