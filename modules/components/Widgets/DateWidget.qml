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
    implicitHeight: 215

    property bool editMode: false

    scale: root.editMode ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    layer.enabled: root.editMode
    layer.smooth: true
    layer.textureSize: root.editMode ? Qt.size(width * 1.05, height * 1.05) : Qt.size(width, height)

    readonly property int dayOfWeek: ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"].indexOf(ServiceClock.day)

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

    onXChanged: if (editMode) dateSaveTimer.restart()
    onYChanged: if (editMode) dateSaveTimer.restart()

    Timer {
        id: dateSaveTimer
        interval: 500
        repeat: false
        onTriggered: {
            SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, {
                dateWidgetX: root.x,
                dateWidgetY: root.y
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

    // Edit mode outline
    Rectangle {
        anchors.fill: parent
        radius: 24
        color: Colors.surfaceContainerHigh

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0

            // ── Week row ────────────────────────────────────────────
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 0

                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]

                    delegate: Item {
                        required property int index
                        required property string modelData
                        readonly property bool isToday: index === root.dayOfWeek

                        implicitWidth: 26
                        implicitHeight: 28

                        Rectangle {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            radius: 11
                            color: parent.isToday ? Colors.primary : "transparent"
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        CustomText {
                            anchors.centerIn: parent
                            content: modelData
                            size: 11
                            weight: parent.isToday ? 700 : 400
                            color: parent.isToday ? Colors.primaryText : Colors.outline
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                    }
                }
            }

            // ── Separator ────────────────────────────────────────────
            Rectangle {
                Layout.topMargin: 8
                Layout.bottomMargin: 0
                implicitWidth: 168
                implicitHeight: 1
                color: Qt.alpha(Colors.outline, 0.2)
            }

            // ── Large date number ─────────────────────────────────────
            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: ServiceClock.date
                size: 90
                weight: 600
                color: Colors.surfaceText
                font.family: SettingsConfig.general.displayFont ?? "Titan One"
                style: Text.Raised
                styleColor: Colors.outline
            }

            // ── Month · Year ──────────────────────────────────────────
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: -8
                spacing: 6

                CustomText {
                    content: ServiceClock.month
                    size: 15
                    weight: 600
                    color: Colors.primary
                    font.family: SettingsConfig.general.displayFont ?? "Titan One"
                    style: Text.Raised
                    styleColor: Colors.outline
                }

                CustomText {
                    content: "·"
                    size: 15
                    color: Colors.outline
                }

                CustomText {
                    content: ServiceClock.year
                    size: 15
                    weight: 600
                    color: Colors.surfaceText
                    font.family: SettingsConfig.general.displayFont ?? "Titan One"
                    style: Text.Raised
                    styleColor: Colors.outline
                }
            }
        }
    }
}
