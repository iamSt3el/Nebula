import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

ColumnLayout {
    id: root
    spacing: 8

    property string mode: "camera"
    signal triggered(string act)

    readonly property var targets: {
        if (root.mode === "text")
            return [ { icon: "text_select_start", label: "Whole screen", act: "livetext" },
                     { icon: "select",            label: "Region",       act: "ocrarea"  } ]
        if (root.mode === "recording")
            return [ { icon: "screenshot_monitor", label: "Screen", act: "screen" },
                     { icon: "window",             label: "Window", act: "window" },
                     { icon: "select",             label: "Area",   act: "area"   } ]
        return [ { icon: "screenshot_monitor", label: "Screen", act: "screen" },
                 { icon: "window",             label: "Window", act: "window" },
                 { icon: "select",             label: "Area",   act: "area"   } ]
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: root.targets

            delegate: TargetCard {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                icon:  modelData.icon
                label: modelData.label
                delay: index * 45
                onActivated: root.triggered(modelData.act)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.mode === "camera"
        spacing: 6

        CustomText {
            content: "Delay"
            size: 10; weight: 600
            color: Colors.surfaceVariantText
            Layout.rightMargin: 2
        }

        Repeater {
            model: [ { s: 0, t: "Off" }, { s: 3, t: "3s" }, { s: 5, t: "5s" }, { s: 10, t: "10s" } ]

            delegate: OptionChip {
                required property var modelData
                Layout.fillWidth: true
                label:  modelData.t
                active: ServiceTools.captureDelay === modelData.s
                onActivated: ServiceTools.captureDelay = modelData.s
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.mode === "camera" || root.mode === "text"
        spacing: 6

        CustomText {
            content: "Select on"
            size: 10; weight: 600
            color: Colors.surfaceVariantText
            Layout.rightMargin: 2
        }

        Repeater {
            model: [ { v: false, t: "Live screen" }, { v: true, t: "Frozen screen" } ]

            delegate: OptionChip {
                required property var modelData
                Layout.fillWidth: true
                label:  modelData.t
                active: ServiceTools.freeze === modelData.v
                onActivated: ServiceTools.setFreeze(modelData.v)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.mode === "recording"
        spacing: 6

        CustomText {
            content: "Audio"
            size: 10; weight: 600
            color: Colors.surfaceVariantText
            Layout.rightMargin: 2
        }

        Repeater {
            model: [ { v: "off",    t: "Off"    },
                     { v: "system", t: "System" },
                     { v: "mic",    t: "Mic"    },
                     { v: "both",   t: "Both"   } ]

            delegate: OptionChip {
                required property var modelData
                Layout.fillWidth: true
                label: modelData.t
                active: modelData.v === "off"
                        ? !SettingsConfig.recording.audioEnabled
                        : SettingsConfig.recording.audioEnabled
                          && (SettingsConfig.recording.audioSource ?? "mic") === modelData.v
                onActivated: {
                    if (modelData.v === "off")
                        SettingsConfig.recording = Object.assign({}, SettingsConfig.recording, { audioEnabled: false })
                    else
                        SettingsConfig.recording = Object.assign({}, SettingsConfig.recording,
                                                                 { audioEnabled: true, audioSource: modelData.v })
                }
            }
        }
    }

    component TargetCard: Rectangle {
        id: tc
        implicitHeight: 56
        radius: 16
        color: Colors.surfaceContainer
        clip: true

        property string icon:  ""
        property string label: ""
        property int    delay: 0
        signal activated()

        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: Colors.surfaceText
            opacity: tcMa.pressed ? 0.12 : tcMa.containsMouse ? 0.08 : 0
            Behavior on opacity { EffectsAnim { speed: "fast" } }
        }

        property real _ey: 14
        property real _eo: 0.0
        Component.onCompleted: { eyAnim.start(); eoAnim.start() }

        SequentialAnimation {
            id: eyAnim
            PauseAnimation  { duration: tc.delay }
            NumberAnimation { target: tc; property: "_ey"; to: 0; duration: 300; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            id: eoAnim
            PauseAnimation  { duration: tc.delay }
            NumberAnimation { target: tc; property: "_eo"; to: 1; duration: 220; easing.type: Easing.OutQuad }
        }

        transform: Translate { y: tc._ey }
        opacity:   tc._eo

        Row {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 10 }
            spacing: 8

            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                content: tc.icon
                iconSize: 20
                color: tcMa.containsMouse ? Colors.primary : Colors.surfaceText
            }
            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: tc.label
                size: 12; weight: 600
                color: Colors.surfaceText
            }
        }

        MouseArea {
            id: tcMa
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: tc.activated()
        }
    }

    component OptionChip: Rectangle {
        id: oc
        implicitHeight: 26
        radius: 13

        property string label: ""
        property bool   active: false
        signal activated()

        color: oc.active ? Colors.secondaryContainer
                         : ocMa.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
        border.width: oc.active ? 0 : 1
        border.color: Colors.outlineVariant
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        CustomText {
            anchors.centerIn: parent
            content: oc.label
            size: 10; weight: oc.active ? 700 : 500
            color: oc.active ? Colors.secondaryContainerText : Colors.surfaceVariantText
        }

        MouseArea {
            id: ocMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: oc.activated()
        }
    }
}
