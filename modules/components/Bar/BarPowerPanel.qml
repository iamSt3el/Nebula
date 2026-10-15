import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    implicitHeight: col.implicitHeight + 24

    readonly property int countdownSeconds: 10

    property string armed: ""
    property int remaining: 0

    readonly property string armedLabel: {
        if (root.armed === "shutdown") return "Shutting down"
        if (root.armed === "restart")  return "Restarting"
        if (root.armed === "firmware") return "Restarting to firmware"
        if (root.armed === "logout")   return "Logging out"
        return ""
    }

    readonly property string armedIcon: {
        if (root.armed === "shutdown") return "power_settings_new"
        if (root.armed === "logout")   return "logout"
        return "restart_alt"
    }

    function run(action) {
        if (action === "lock")     { Quickshell.execDetached(["loginctl", "lock-session"]); return }
        if (action === "sleep")    { Quickshell.execDetached(["systemctl", "suspend"]);     return }
        if (action === "logout")   { Hyprland.dispatch("hl.dsp.exit()");                    return }
        if (action === "restart")  { Quickshell.execDetached(["systemctl", "reboot"]);      return }
        if (action === "shutdown") { Quickshell.execDetached(["systemctl", "poweroff"]);    return }
        if (action === "firmware") { Quickshell.execDetached(["systemctl", "reboot", "--firmware-setup"]) }
    }

    function trigger(action, delayed) {
        if (!delayed) {
            root.run(action)
            return
        }
        root.armed = action
        root.remaining = root.countdownSeconds
        tick.restart()
    }

    function cancel() {
        tick.stop()
        root.armed = ""
        root.remaining = 0
    }

    function commit() {
        const action = root.armed
        root.cancel()
        root.run(action)
    }

    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            root.remaining -= 1
            if (root.remaining <= 0) root.commit()
        }
    }

    onVisibleChanged: {
        GlobalStates.powerPanelOpen = root.visible
        if (!root.visible) root.cancel()
    }
    Component.onCompleted: GlobalStates.powerPanelOpen = root.visible
    Component.onDestruction: GlobalStates.powerPanelOpen = false

    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape && root.armed !== "") {
                root.cancel()
                event.accepted = true
                return
            }
            if (root.armed !== "") return

            switch (event.key) {
            case Qt.Key_L: root.trigger("lock", false);    event.accepted = true; break
            case Qt.Key_S: root.trigger("sleep", false);   event.accepted = true; break
            case Qt.Key_E: root.trigger("logout", true);   event.accepted = true; break
            case Qt.Key_R: root.trigger("restart", true);  event.accepted = true; break
            case Qt.Key_P: root.trigger("shutdown", true); event.accepted = true; break
            }
        }
    }

    ColumnLayout {
        id: col
        anchors { fill: parent; margins: 12 }
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 8
            Layout.bottomMargin: 14
            spacing: 12

            ClippingWrapperRectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: 22
                color: Colors.secondaryContainer

                Image {
                    anchors.fill: parent
                    source: SettingsConfig.general.profile ?? ""
                    sourceSize: Qt.size(88, 88)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                CustomText {
                    Layout.fillWidth: true
                    content: Quickshell.env("USER") ?? ""
                    size: 15
                    weight: 700
                    elide: Text.ElideRight
                }

                CustomText {
                    Layout.fillWidth: true
                    content: "up " + ServiceSystemInfo.getUptime()
                    size: 12
                    customColor: Colors.outline
                    elide: Text.ElideRight
                }
            }

            MaterialIconSymbol {
                content: ServiceUPower.isCharging ? "battery_charging_full" : "battery_android_full"
                iconSize: 18
                customColor: Colors.primary
            }

            CustomText {
                content: Math.round(ServiceUPower.powerLevel * 100) + "%"
                size: 12
                weight: 600
            }
        }

        PowerRow { action: "lock";     icon: "lock";                label: "Lock";      cap: "L" }
        PowerRow { action: "sleep";    icon: "bedtime";             label: "Sleep";     cap: "S" }
        PowerRow { action: "logout";   icon: "logout";              label: "Log out";   cap: "E"; delayed: true }
        PowerRow { action: "restart";  icon: "restart_alt";         label: "Restart";   cap: "R"; delayed: true }
        PowerRow { action: "shutdown"; icon: "power_settings_new";  label: "Shut down"; cap: "P"; delayed: true
                   tileColor: Colors.error; tileInk: Colors.errorText }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            color: Colors.outlineVariant
        }

        PowerRow {
            action: "firmware"
            icon: "memory"
            label: "Restart to firmware"
            delayed: true
            dim: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.preferredHeight: 54
            radius: 16
            color: Colors.surfaceContainerHigh
            visible: root.armed !== ""

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 10

                MaterialIconSymbol {
                    content: root.armedIcon
                    iconSize: 18
                    customColor: Colors.primary
                }

                CustomText {
                    Layout.fillWidth: true
                    content: root.armedLabel + " in " + root.remaining + " s"
                    size: 13
                    weight: 600
                    elide: Text.ElideRight
                }

                CountBtn {
                    label: "Now"
                    filled: true
                    onActivated: root.commit()
                }

                CountBtn {
                    label: "Cancel"
                    onActivated: root.cancel()
                }
            }
        }
    }

    component PowerRow: Rectangle {
        id: pr

        property string action: ""
        property string icon: ""
        property string label: ""
        property string cap: ""
        property bool delayed: false
        property bool dim: false
        property color tileColor: Colors.surfaceContainerHigh
        property color tileInk: Colors.surfaceText

        Layout.fillWidth: true
        Layout.preferredHeight: pr.dim ? 46 : 54
        radius: 16
        color: prMa.containsMouse ? Colors.secondaryContainer : Qt.alpha(Colors.secondaryContainer, 0)
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        opacity: root.armed !== "" ? 0.45 : 1
        Behavior on opacity { EffectsAnim { speed: "fast" } }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 12
                color: pr.dim ? Qt.alpha(pr.tileColor, 0)
                       : prMa.containsMouse ? Colors.primary : pr.tileColor
                Behavior on color { EffectsColorAnim { speed: "fast" } }

                MaterialIconSymbol {
                    anchors.centerIn: parent
                    content: pr.icon
                    iconSize: 20
                    customColor: pr.dim ? Colors.outline
                                 : prMa.containsMouse ? Colors.primaryText : pr.tileInk
                }
            }

            CustomText {
                Layout.fillWidth: true
                content: pr.label
                size: pr.dim ? 13 : 14
                weight: pr.dim ? 500 : 600
                customColor: pr.dim ? Colors.outline
                             : prMa.containsMouse ? Colors.secondaryContainerText : Colors.surfaceText
                elide: Text.ElideRight
            }

            Rectangle {
                visible: pr.cap !== ""
                Layout.preferredWidth: Math.max(22, capText.implicitWidth + 12)
                Layout.preferredHeight: 22
                radius: 6
                color: prMa.containsMouse ? Qt.alpha(Colors.secondaryContainerText, 0.18)
                                          : Colors.surfaceContainerHighest

                CustomText {
                    id: capText
                    anchors.centerIn: parent
                    content: pr.cap
                    size: 11
                    weight: 700
                    customColor: prMa.containsMouse ? Colors.secondaryContainerText : Colors.surfaceText
                }
            }
        }

        MouseArea {
            id: prMa
            anchors.fill: parent
            hoverEnabled: root.armed === ""
            enabled: root.armed === ""
            cursorShape: Qt.PointingHandCursor
            onClicked: root.trigger(pr.action, pr.delayed)
        }
    }

    component CountBtn: Rectangle {
        id: cb

        property string label: ""
        property bool filled: false
        signal activated()

        implicitHeight: 30
        implicitWidth: cbText.implicitWidth + 28
        radius: 15
        color: cb.filled ? Colors.primary
             : cbMa.containsMouse ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
        border.width: cb.filled ? 0 : 1
        border.color: Colors.outlineVariant
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        CustomText {
            id: cbText
            anchors.centerIn: parent
            content: cb.label
            size: 12
            weight: cb.filled ? 700 : 600
            customColor: cb.filled ? Colors.primaryText : Colors.surfaceText
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
