pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes

Item {
    id: root

    implicitWidth: 360
    implicitHeight: col.implicitHeight + 36

    property bool firmwareAsk: false
    signal closeRequested()

    function run(action) {
        if (action === "lock")     { root.closeRequested(); lockDelay.restart(); return }
        if (action === "sleep")    { Quickshell.execDetached(["systemctl", "suspend"]);     return }
        if (action === "logout")   { Hyprland.dispatch("hl.dsp.exit()");                    return }
        if (action === "restart")  { Quickshell.execDetached(["systemctl", "reboot"]);      return }
        if (action === "shutdown") { Quickshell.execDetached(["systemctl", "poweroff"]);    return }
        if (action === "firmware") { Quickshell.execDetached(["systemctl", "reboot", "--firmware-setup"]) }
    }

    readonly property var tracks: [logoutTrack, restartTrack, shutdownTrack]
    readonly property bool sliding: logoutTrack.auto || restartTrack.auto || shutdownTrack.auto

    function autoSlide(track) {
        for (const t of root.tracks)
            if (t !== track) t.reset()
        track.slide()
    }

    function resetAll() {
        for (const t of root.tracks)
            t.reset()
        root.firmwareAsk = false
    }

    onVisibleChanged: {
        GlobalStates.powerPanelOpen = root.visible
        if (root.visible) {
            ServiceSystemInfo.getUptime()
            return
        }
        for (const t of root.tracks)
            t.clear()
        root.firmwareAsk = false
    }
    Component.onCompleted: {
        GlobalStates.powerPanelOpen = root.visible
        ServiceSystemInfo.getUptime()
    }
    Component.onDestruction: GlobalStates.powerPanelOpen = false

    Timer {
        id: lockDelay
        interval: 250
        onTriggered: GlobalStates.lockRequested()
    }

    Timer {
        id: firmwareTimer
        interval: 3000
        onTriggered: root.firmwareAsk = false
    }

    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (root.sliding || root.firmwareAsk) {
                    root.resetAll()
                } else {
                    root.closeRequested()
                }
                event.accepted = true
                return
            }
            switch (event.key) {
            case Qt.Key_L: root.run("lock");                 event.accepted = true; break
            case Qt.Key_S: root.run("sleep");                event.accepted = true; break
            case Qt.Key_E: root.autoSlide(logoutTrack);      event.accepted = true; break
            case Qt.Key_R: root.autoSlide(restartTrack);     event.accepted = true; break
            case Qt.Key_P: root.autoSlide(shutdownTrack);    event.accepted = true; break
            }
        }
    }

    ColumnLayout {
        id: col
        x: 18
        y: 18
        width: root.width - 36
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            CustomText {
                Layout.fillWidth: true
                content: "Power"
                size: 20
                weight: 600
            }
            CustomText {
                visible: (ServiceSystemInfo.uptime ?? "") !== ""
                content: "Up " + (ServiceSystemInfo.uptime ?? "")
                size: 13
                weight: 400
                customColor: Colors.surfaceVariantText
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PowerTile {
                action: "lock"
                icon: "lock"
                label: "Lock"
                detail: "Keeps everything open"
                key: "L"
                tone: Colors.primaryContainer
                ink: Colors.primaryContainerText
            }
            PowerTile {
                action: "sleep"
                icon: "bedtime"
                label: "Sleep"
                detail: "Suspend to RAM"
                key: "S"
                tone: Colors.secondaryContainer
                ink: Colors.secondaryContainerText
            }
        }

        CustomText {
            Layout.leftMargin: 4
            Layout.topMargin: 6
            content: "Slide to confirm"
            size: 13
            weight: 600
            customColor: Colors.primary
        }

        SlideTrack {
            id: logoutTrack
            action: "logout"
            icon: "logout"
            verb: "log out"
            key: "E"
            shape: "cookie9"
            trackColor: Colors.surfaceContainer
            fillColor: Colors.secondaryContainer
            thumbColor: Colors.secondaryContainerText
            thumbInk: Colors.secondaryContainer
            textColor: Colors.surfaceVariantText
        }
        SlideTrack {
            id: restartTrack
            action: "restart"
            icon: "restart_alt"
            verb: "restart"
            key: "R"
            shape: "cookie9"
            trackColor: Colors.surfaceContainer
            fillColor: Colors.primaryContainer
            thumbColor: Colors.primary
            thumbInk: Colors.primaryText
            textColor: Colors.surfaceVariantText
        }
        SlideTrack {
            id: shutdownTrack
            action: "shutdown"
            icon: "power_settings_new"
            verb: "shut down"
            key: "P"
            shape: "cookie9"
            trackColor: Qt.tint(Colors.surfaceContainer, Qt.alpha(Colors.errorContainer, 0.35))
            fillColor: Colors.errorContainer
            thumbColor: Colors.error
            thumbInk: Colors.errorText
            textColor: Colors.errorContainerText
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            spacing: 10

            MaterialIconSymbol {
                content: "info"
                iconSize: 16
                fill: 1
                customColor: Colors.primary
            }
            CustomText {
                Layout.fillWidth: true
                content: root.sliding ? "Press Esc to stop" : "Let go before the end to cancel"
                size: 12
                weight: 400
                customColor: Colors.surfaceVariantText
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            implicitHeight: 44
            radius: 22
            color: root.firmwareAsk ? Colors.errorContainer
                 : fwMa.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer
            Behavior on color { EffectsColorAnim { speed: "fast" } }

            Row {
                anchors.centerIn: parent
                spacing: 8

                MaterialIconSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    content: "developer_board"
                    iconSize: 18
                    customColor: root.firmwareAsk ? Colors.errorContainerText : Colors.surfaceVariantText
                }
                CustomText {
                    anchors.verticalCenter: parent.verticalCenter
                    content: root.firmwareAsk ? "Click again to restart to firmware" : "Restart to firmware"
                    size: 13
                    weight: 500
                    customColor: root.firmwareAsk ? Colors.errorContainerText : Colors.surfaceVariantText
                }
            }

            MouseArea {
                id: fwMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.firmwareAsk) {
                        root.firmwareAsk = false
                        root.run("firmware")
                        return
                    }
                    root.firmwareAsk = true
                    firmwareTimer.restart()
                }
            }
        }
    }

    component PowerTile: Rectangle {
        id: tile

        property string action: ""
        property string icon: ""
        property string label: ""
        property string detail: ""
        property string key: ""
        property color tone
        property color ink

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 96
        radius: tileMa.pressed ? 18 : 28
        color: tileMa.containsMouse ? Qt.tint(tile.tone, Qt.alpha(tile.ink, 0.08)) : tile.tone
        Behavior on radius { SpatialAnim { speed: "fast" } }
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        MaterialIconSymbol {
            x: 16
            y: 14
            content: tile.icon
            iconSize: 28
            fill: 1
            customColor: tile.ink
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            width: 22
            height: 22
            radius: 7
            color: Qt.alpha(tile.ink, 0.14)

            CustomText {
                anchors.centerIn: parent
                content: tile.key
                size: 11
                weight: 700
                customColor: tile.ink
            }
        }

        Column {
            x: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            width: tile.width - 32
            spacing: 1

            CustomText {
                content: tile.label
                size: 16
                weight: 600
                customColor: tile.ink
            }
            CustomText {
                width: parent.width
                content: tile.detail
                size: 12
                weight: 400
                elide: Text.ElideRight
                customColor: tile.ink
            }
        }

        MouseArea {
            id: tileMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.run(tile.action)
        }
    }

    component SlideTrack: Rectangle {
        id: st

        property string action: ""
        property string icon: ""
        property string verb: ""
        property string key: ""
        property string shape: "cookie9"
        property color trackColor
        property color fillColor
        property color thumbColor
        property color thumbInk
        property color textColor

        property real progress: 0
        property bool fired: false
        readonly property bool auto: autoAnim.running
        readonly property bool done: st.progress >= 0.92
        readonly property real travel: st.width - 64

        function reset() {
            autoAnim.stop()
            if (st.fired) return
            if (!dragMa.pressed && st.progress > 0) backAnim.restart()
        }

        function clear() {
            autoAnim.stop()
            backAnim.stop()
            st.fired = false
            st.progress = 0
        }

        function slide() {
            if (st.fired) return
            backAnim.stop()
            autoAnim.restart()
        }

        function fire() {
            if (st.fired) return
            st.fired = true
            st.progress = 1
            root.run(st.action)
        }

        Layout.fillWidth: true
        implicitHeight: 64
        radius: 32
        color: st.trackColor
        clip: true

        Rectangle {
            width: thumb.x + 60
            height: parent.height
            radius: 32
            color: st.fillColor
        }

        Row {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 20
            spacing: 6
            opacity: 1 - st.progress * 0.35

            CustomText {
                anchors.verticalCenter: parent.verticalCenter
                content: st.done ? "Let go to " + st.verb : "Slide to " + st.verb
                size: 14
                weight: 500
                customColor: st.textColor
            }
            MaterialIconSymbol {
                anchors.verticalCenter: parent.verticalCenter
                content: "keyboard_double_arrow_right"
                iconSize: 18
                customColor: st.textColor
            }
        }

        Item {
            id: thumb
            x: 4 + st.progress * st.travel
            y: 4
            width: 56
            height: 56

            MaterialShapes.ShapeCanvas {
                anchors.fill: parent
                roundedPolygon: st.shape
                color: st.thumbColor
                rotation: st.progress * 160
            }
            MaterialIconSymbol {
                anchors.centerIn: parent
                content: st.icon
                iconSize: 24
                fill: 1
                customColor: st.thumbInk
            }
        }

        MouseArea {
            id: dragMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: !st.fired
            cursorShape: dragMa.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property real grab: -1

            onPressed: mouse => {
                autoAnim.stop()
                backAnim.stop()
                dragMa.grab = mouse.x <= thumb.x + 60 ? mouse.x - thumb.x : -1
            }
            onPositionChanged: mouse => {
                if (!dragMa.pressed || dragMa.grab < 0 || st.travel <= 0) return
                st.progress = Math.max(0, Math.min(1, (mouse.x - dragMa.grab - 4) / st.travel))
            }
            onReleased: {
                if (dragMa.grab >= 0 && st.done) st.fire()
                else if (st.progress > 0) backAnim.restart()
                dragMa.grab = -1
            }
            onCanceled: {
                dragMa.grab = -1
                if (st.progress > 0) backAnim.restart()
            }
        }

        SpatialAnim {
            id: backAnim
            target: st
            property: "progress"
            to: 0
        }

        NumberAnimation {
            id: autoAnim
            target: st
            property: "progress"
            to: 1
            duration: 1400
            easing.type: Easing.InOutCubic
            onFinished: if (st.progress >= 0.999) st.fire()
        }
    }
}
