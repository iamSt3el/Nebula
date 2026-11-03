import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

Rectangle {
    id: root

    property var palette: null

    readonly property bool ready: root.palette !== null
    readonly property color fallback: Colors.surfaceContainerHighest

    function c(key) {
        return root.ready ? root.palette[key] : root.fallback
    }

    radius: 16
    color: root.ready ? root.c("surface") : Colors.surfaceContainerHigh
    Behavior on color { EffectsColorAnim {} }
    implicitHeight: 118

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        opacity: root.ready ? 1 : 0.35
        Behavior on opacity { EffectsAnim {} }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 16
            radius: 8
            color: root.c("surfaceContainerHigh")
            Behavior on color { EffectsColorAnim {} }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 6
                radius: 3
                color: root.c("primary")
                Behavior on color { EffectsColorAnim {} }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: root.c("primaryContainer")
                Behavior on color { EffectsColorAnim {} }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: root.c("tertiaryContainer")
                Behavior on color { EffectsColorAnim {} }
            }
        }

        Rectangle {
            Layout.preferredWidth: parent.width * 0.6
            Layout.preferredHeight: 10
            radius: 5
            color: root.c("primary")
            Behavior on color { EffectsColorAnim {} }
        }
    }

    CustomCircularLoader {
        anchors.centerIn: parent
        visible: !root.ready
        size: 26
        trackWidth: 3
    }
}
