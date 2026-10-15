import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

ColumnLayout {
    id: root
    spacing: 12

    readonly property string audioSource: SettingsConfig.recording.audioEnabled
                                          ? (SettingsConfig.recording.audioSource ?? "mic") : "off"
    readonly property bool hasMic:    root.audioSource === "mic"    || root.audioSource === "both"
    readonly property bool hasSystem: root.audioSource === "system" || root.audioSource === "both"

    property bool _held: false

    readonly property bool shouldHold: root.visible && GlobalStates.toolsWidgetOpen && ServiceTools.isRecording

    function _hold(on) {
        if (on === root._held) return
        root._held = on
        if (on) ServiceRecLevels.retain()
        else    ServiceRecLevels.release()
    }

    onShouldHoldChanged: root._hold(root.shouldHold)

    Binding {
        target: ServiceRecLevels
        property: "wantMic"
        value: root.hasMic
        when: root._held
    }

    Binding {
        target: ServiceRecLevels
        property: "wantSystem"
        value: root.hasSystem
        when: root._held
    }

    Component.onCompleted: root._hold(root.shouldHold)
    Component.onDestruction: root._hold(false)

    RowLayout {
        Layout.fillWidth: true
        spacing: 7

        Rectangle {
            implicitWidth: 8; implicitHeight: 8
            radius: 4
            color: Colors.error

            SequentialAnimation on opacity {
                running: ServiceTools.isRecording
                loops: Animation.Infinite
                NumberAnimation { to: 0.30; duration: 620; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0;  duration: 620; easing.type: Easing.InOutSine }
            }
        }

        CustomText {
            content: "REC"
            size: 10; weight: 700
            color: Colors.error
        }

        CustomText {
            content: ServiceTools.recordingMode
            size: 11; weight: 500
            color: Colors.outline
        }

        Item { Layout.fillWidth: true }

        CustomText {
            content: ServiceTools.recordingProfile
                     + (ServiceTools.recordingBytes > 0 ? " · " + ServiceTools.humanBytes(ServiceTools.recordingBytes) : "")
            size: 11; weight: 500
            color: Colors.outline
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        CustomText {
            content: {
                const s = ServiceTools.recordingSeconds
                return String(Math.floor(s / 60)).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
            }
            size: 40; weight: 700
            color: Colors.surfaceText
        }

        CustomText {
            visible: ServiceTools.recordingMarks.length > 0
            content: ServiceTools.recordingMarks.length
                     + (ServiceTools.recordingMarks.length === 1 ? " mark" : " marks")
            size: 11; weight: 500
            color: Colors.outline
        }

        Item { Layout.fillWidth: true }

        ConsoleBtn {
            icon: "bookmark_add"
            tip: "Mark this moment"
            onActivated: ServiceTools.markMoment()
        }

        Item {
            implicitWidth: 52; implicitHeight: 52

            Rectangle {
                anchors.centerIn: parent
                width: 52; height: 52; radius: 26
                color: "transparent"
                border.width: 1.5
                border.color: Qt.alpha(Colors.error, 0.30)

                SequentialAnimation on scale {
                    running: ServiceTools.isRecording
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.22; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on opacity {
                    running: ServiceTools.isRecording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: stopMa.pressed ? 42 : 46; height: width; radius: width / 2
                Behavior on width { SpatialAnim { speed: "fast" } }
                color: stopMa.containsMouse ? Colors.errorContainer : Colors.error
                Behavior on color { EffectsColorAnim { speed: "fast" } }

                Rectangle {
                    anchors.centerIn: parent
                    width: 15; height: 15; radius: 3
                    color: stopMa.containsMouse ? Colors.errorContainerText : Colors.errorText
                }

                MouseArea {
                    id: stopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ServiceTools.stopRecording()
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 7
        visible: root.hasMic || root.hasSystem

        LevelMeter {
            Layout.fillWidth: true
            visible: root.hasMic
            icon: "mic"
            level: ServiceRecLevels.micLevel
            tint: Colors.primary
        }

        LevelMeter {
            Layout.fillWidth: true
            visible: root.hasSystem
            icon: "volume_up"
            level: ServiceRecLevels.systemLevel
            tint: Colors.tertiary
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: !root.hasMic && !root.hasSystem
        spacing: 7

        MaterialIconSymbol { content: "volume_off"; iconSize: 15; color: Colors.outline }
        CustomText { content: "Recording without audio"; size: 11; weight: 500; color: Colors.outline }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Colors.outlineVariant
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MaterialIconSymbol { content: "folder"; iconSize: 15; color: Colors.outline }

        CustomText {
            Layout.fillWidth: true
            content: ServiceTools.lastFilename.split("/").pop()
            size: 11; weight: 500
            color: Colors.surfaceVariantText
            elide: Text.ElideMiddle
        }

        Rectangle {
            implicitWidth: changeText.implicitWidth + 20
            implicitHeight: 24
            radius: 12
            color: changeMa.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : Qt.alpha(Colors.surfaceText, 0)
            border.width: 1
            border.color: Colors.outlineVariant
            Behavior on color { EffectsColorAnim { speed: "fast" } }

            CustomText {
                id: changeText
                anchors.centerIn: parent
                content: "Change"
                size: 10; weight: 600
                color: Colors.surfaceVariantText
            }

            MouseArea {
                id: changeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    GlobalStates.toolsWidgetOpen = false
                    GlobalStates.settingsPage = 7
                    GlobalStates.settingsOpen = true
                }
            }
        }
    }

    component LevelMeter: RowLayout {
        id: lm
        spacing: 8

        property string icon: ""
        property real   level: 0
        property color  tint: Colors.primary

        MaterialIconSymbol {
            Layout.preferredWidth: 18
            content: lm.icon
            iconSize: 15
            color: Colors.surfaceVariantText
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            radius: 3
            color: Colors.surfaceContainerHigh

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, lm.level))
                height: parent.height
                radius: parent.radius
                color: lm.tint
                Behavior on width { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
            }
        }
    }

    component ConsoleBtn: Rectangle {
        id: cb
        implicitWidth: 44; implicitHeight: 44
        radius: 22
        color: cbMa.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer

        property string icon: ""
        property string tip: ""
        signal activated()

        Behavior on color { EffectsColorAnim { speed: "fast" } }

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: cb.icon
            iconSize: cbMa.pressed ? 17 : 20
            Behavior on iconSize { SpatialAnim { speed: "fast" } }
            color: Colors.surfaceText
        }

        CustomToolTip {
            visible: cbMa.containsMouse
            content: cb.tip
        }

        MouseArea {
            id: cbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cb.activated()
        }
    }
}
