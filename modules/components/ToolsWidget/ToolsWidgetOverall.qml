import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import Quickshell
import Quickshell.Hyprland

Item {
    id: root
    implicitWidth:  cardW + 32
    implicitHeight: card.implicitHeight + 32

    readonly property real cardW: 540

    property string toolMode: ServiceTools.isRecording ? "recording" : "camera"

    readonly property bool consoleUp: ServiceTools.isRecording && root.toolMode === "recording"

    readonly property string title: {
        if (root.toolMode === "text")      return "Live Text"
        if (root.toolMode === "recording") return ServiceTools.isRecording ? "Recording" : "Record"
        return "Screenshot"
    }

    function trigger(act) {
        const cam = root.toolMode === "camera"
        const mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

        var selectorMode = ""
        if (act === "window")       selectorMode = cam ? "window-screenshot" : "window-recording"
        else if (act === "area")    selectorMode = cam ? "screenshot" : "recording"
        else if (act === "ocrarea") selectorMode = "ocr"
        else if (act === "screen" && Quickshell.screens.length > 1)
            selectorMode = cam ? "screen-screenshot" : "screen-recording"

        GlobalStates.toolsWidgetOpen = false

        if (selectorMode !== "") {
            GlobalStates.areaSelectMode = selectorMode
            GlobalStates.areaSelectOpen = true
        } else if (act === "screen") {
            if (cam) ServiceTools.takeScreenshot("Screen")
            else     ServiceTools.startDelayed("Screen", "")
        } else if (act === "livetext") {
            if (mon !== "") ServiceTools.startLiveText(mon, M3Motion.panel.closeDuration + 80)
        }
    }

    Component.onCompleted: {
        root._cs = 1.0
        root._co = 1.0
        ServiceCaptures.refresh()
    }

    Connections {
        target: GlobalStates

        function onToolsWidgetOpenChanged() {
            if (!GlobalStates.toolsWidgetOpen) return
            if (ServiceTools.isRecording) root.toolMode = "recording"
            ServiceCaptures.refresh()
        }
    }

    property real _cs: 0.88
    property real _co: 0.0

    Behavior on _cs { NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 0.4 } }
    Behavior on _co { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

    Rectangle {
        anchors.centerIn: parent
        width: root.cardW; height: card.height
        radius: 30
        color: Colors.shadow
        opacity: root._co * 0.08
        scale: root._cs
        transform: Translate { y: 4 }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: root.cardW
        height: implicitHeight
        implicitHeight: Math.max(body.implicitHeight, rail.implicitHeight + 16) + 24
        radius: 28
        color: Colors.surfaceContainerLow
        clip: true
        scale: root._cs
        opacity: root._co

        Behavior on implicitHeight { SpatialAnim { speed: "fast" } }

        RowLayout {
            id: body
            anchors { fill: parent; margins: 12 }
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 60
                Layout.fillHeight: true
                Layout.minimumHeight: rail.implicitHeight + 16
                radius: 20
                color: Colors.surfaceContainer

                ColumnLayout {
                    id: rail
                    anchors { fill: parent; topMargin: 8; bottomMargin: 8 }
                    spacing: 6

                    RailBtn { icon: "photo_camera";      label: "Screenshot"; mode: "camera" }
                    RailBtn { icon: "screen_record";     label: "Record";     mode: "recording" }
                    RailBtn { icon: "text_select_start"; label: "Live Text";  mode: "text" }
                    RailBtn {
                        icon: "colorize"; label: "Pick a colour"
                        onActivated: {
                            GlobalStates.toolsWidgetOpen = false
                            ServiceTools.pickColor()
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RailBtn {
                        icon: "settings"; label: "Settings"; dim: true
                        onActivated: {
                            GlobalStates.toolsWidgetOpen = false
                            GlobalStates.settingsPage = 7
                            GlobalStates.settingsOpen = true
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    CustomText {
                        Layout.fillWidth: true
                        content: root.title
                        size: 15; weight: 600; color: Colors.surfaceText
                    }

                    Rectangle {
                        visible: root.toolMode === "camera" && ServiceTools.captureDelay > 0
                        implicitWidth: delayRow.implicitWidth + 18
                        implicitHeight: 26
                        radius: 13
                        color: Colors.secondaryContainer

                        Row {
                            id: delayRow
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialIconSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                content: "timer"; iconSize: 13; color: Colors.secondaryContainerText
                            }
                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                content: ServiceTools.captureDelay + "s"
                                size: 11; weight: 700; color: Colors.secondaryContainerText
                            }
                        }
                    }

                    Rectangle {
                        implicitWidth: 26; implicitHeight: 26
                        radius: 13
                        color: closeHov.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
                        Behavior on color { EffectsColorAnim { speed: "fast" } }

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            content: "close"; iconSize: 16; color: Colors.surfaceVariantText
                        }
                        MouseArea {
                            id: closeHov
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: GlobalStates.toolsWidgetOpen = false
                        }
                    }
                }

                ToolsTargets {
                    Layout.fillWidth: true
                    visible: !root.consoleUp
                    mode: root.toolMode
                    onTriggered: act => root.trigger(act)
                }

                ToolsConsole {
                    Layout.fillWidth: true
                    visible: root.consoleUp
                }

                ToolsRecent {
                    Layout.fillWidth: true
                    visible: !root.consoleUp
                }
            }
        }
    }

    component RailBtn: Rectangle {
        id: rb
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 44
        Layout.preferredHeight: 40
        radius: 14

        property string icon: ""
        property string label: ""
        property string mode: ""
        property bool   dim: false
        signal activated()

        readonly property bool active: rb.mode !== "" && root.toolMode === rb.mode

        color: rb.active ? Colors.secondaryContainer
                         : rbMa.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: rb.icon
            iconSize: 20
            color: rb.active ? Colors.secondaryContainerText
                             : rb.dim ? Colors.outline : Colors.surfaceVariantText
        }

        CustomToolTip {
            visible: rbMa.containsMouse
            content: rb.label
        }

        MouseArea {
            id: rbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (rb.mode !== "") root.toolMode = rb.mode
                else rb.activated()
            }
        }
    }
}
