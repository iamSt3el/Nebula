import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.modules.customComponents
import qs.modules.utils
import qs.modules.settings
import qs.modules.services

PopupWindow {
    id: root
    implicitWidth: 340
    implicitHeight: 400
    visible: true
    color: "transparent"
    signal close

    anchor {
        window: layout
        rect.x: utility.x + utility.width - implicitWidth - 8
        rect.y: utility.y + utility.height + 4
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: true
        windows: [QsWindow.window]
        onCleared: root.close()
    }

    // ── Battery state helpers ───────────────────────────────────────────
    readonly property bool isCharging: ServiceUPower.isCharging
    readonly property bool isFull: ServiceUPower.powerLevel >= 1.0
    readonly property real batPct: ServiceUPower.powerLevel

    // ── Ambient colors (match battery state) ────────────────────────────
    readonly property color ambientPrimary: {
        if (isFull) return Colors.primary;
        if (isCharging) return Colors.primary;
        if (batPct >= 0.7) return Colors.primary;
        if (batPct >= 0.3) return Colors.tertiary;
        return Colors.error;
    }
    readonly property color ambientSecondary: {
        if (isFull) return Colors.tertiary;
        if (isCharging) return Colors.tertiary;
        if (batPct >= 0.7) return Colors.tertiary;
        if (batPct >= 0.3) return Colors.primary;
        return Colors.error;
    }

    // Unified hue for Battery
    readonly property color batColorStart: {
        if (isCharging || isFull) return Colors.primary;
        if (batPct >= 0.7) return Colors.primary;
        if (batPct >= 0.3) return Colors.tertiary;
        return Colors.error;
    }
    readonly property color batColorEnd: Qt.lighter(batColorStart, 1.15)

    // ── Profile colors ──────────────────────────────────────────────────
    readonly property color profileStart: {
        const idx = ServiceUPower.powerProfile;
        if (idx === 0) return Colors.error;
        if (idx === 2) return Colors.tertiary;
        return Colors.primary;
    }
    readonly property color profileEnd: Qt.lighter(profileStart, 1.15)

    // ── Danger state (low battery) ───────────────────────────────────────
    readonly property bool isDangerState: !isCharging && !isFull && batPct < 0.15

    // ── Animated capacity ───────────────────────────────────────────────
    property real animCapacity: 0
    Behavior on animCapacity {
        NumberAnimation { duration: 1200; easing.type: Easing.OutQuint }
    }

    onBatPctChanged: {
        animCapacity = batPct;
    }
    Component.onCompleted: {
        animCapacity = batPct;
    }

    // ── Uptime ──────────────────────────────────────────────────────────
    property int upHours: 0
    property int upMins: 0

    Process {
        id: uptimeProc
        command: ["bash", "-c", "awk '{print int($1/3600)\"h \"int(($1%3600)/60)\"m\"}' /proc/uptime 2>/dev/null || echo '0h 0m'"]

        property string buffer: ""

        stdout: SplitParser {
            onRead: data => uptimeProc.buffer = data
        }

        onExited: {
            const line = uptimeProc.buffer.trim();
            uptimeProc.buffer = "";
            if (!line) return;

            const upParts = line.split("h ");
            if (upParts.length === 2) {
                root.upHours = parseInt(upParts[0]) || 0;
                root.upMins = parseInt(upParts[1].replace("m", "")) || 0;
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: uptimeProc.running = true
    }

    // ── Slow orbit animation ────────────────────────────────────────────
    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0
        to: Math.PI * 2
        duration: 90000
        loops: Animation.Infinite
        running: true
    }

    Rectangle {
        id: child
        anchors.fill: parent
        color: Colors.surface
        radius: 20
        clip: true

        scale: 0.88
        opacity: 0
        NumberAnimation on opacity {
            from: 0
            to: 1
            duration: 180
            running: true
        }
        NumberAnimation on scale {
            from: 0.88
            to: 1
            duration: 260
            running: true
            easing.type: Easing.OutBack
            easing.overshoot: 0.35
        }

        // ── Ambient orbiting blobs ────────────────────────────────────────
        Rectangle {
            width: parent.width * 0.8
            height: width
            radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.cos(root.globalOrbitAngle * 2) * 80
            y: (parent.height / 2 - height / 2) + Math.sin(root.globalOrbitAngle * 2) * 60
            opacity: 0.08
            color: root.ambientPrimary
            Behavior on color {
                ColorAnimation { duration: 1000 }
            }
        }

        Rectangle {
            width: parent.width * 0.9
            height: width
            radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.5) * (-80)
            y: (parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.5) * (-60)
            opacity: 0.06
            color: root.ambientSecondary
            Behavior on color {
                ColorAnimation { duration: 1000 }
            }
        }

        // ── Radar rings (centered on battery gauge) ───────────────────────
        Repeater {
            model: 3
            Rectangle {
                x: parent.width / 2 - width / 2
                y: 100 - height / 2
                width: 200 + (index * 100)
                height: width
                radius: width / 2
                color: "transparent"
                border.color: root.ambientSecondary
                border.width: 1
                Behavior on border.color {
                    ColorAnimation { duration: 1000 }
                }
                opacity: 0.06 - (index * 0.02)
            }
        }

        ColumnLayout {
            id: col
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 16
            }
            spacing: 12

            // ── Header ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Colors.primaryContainer

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: isCharging ? "battery_charging_full" : "battery_full"
                        iconSize: 18
                        customColor: Colors.primaryContainerText
                    }
                }

                CustomText {
                    Layout.fillWidth: true
                    content: "Battery"
                    size: 16
                    weight: 700
                }

                CustomText {
                    content: ServiceUPower.batteryStatus
                    size: 12
                    weight: 600
                    customColor: {
                        if (isFull) return Colors.primary;
                        if (isCharging) return Colors.primary;
                        return Colors.outline;
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: closeHov.containsMouse ? Colors.surfaceContainerHigh : "transparent"
                    Behavior on color {
                        ColorAnimation { duration: 130 }
                    }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: "close"
                        iconSize: 16
                        customColor: Colors.outline
                    }

                    MouseArea {
                        id: closeHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            // ── Uptime (imperative-dots style) ─────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 52

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    // Hours box
                    Rectangle {
                        width: 44; height: 48; radius: 10
                        color: Colors.surfaceContainer
                        border.color: Colors.surfaceContainerHigh
                        border.width: 1

                        Rectangle {
                            anchors.fill: parent; radius: 10
                            color: root.ambientPrimary; opacity: 0.05
                            Behavior on color { ColorAnimation { duration: 1000 } }
                        }

                        Column {
                            anchors.centerIn: parent
                            CustomText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                content: root.upHours.toString().padStart(2, '0')
                                size: 18
                                weight: 700
                                customColor: root.ambientPrimary
                            }
                            CustomText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                content: "HR"
                                size: 8
                                weight: 700
                                customColor: Colors.outline
                            }
                        }
                    }

                    // Pulsing colon
                    CustomText {
                        anchors.verticalCenter: parent.verticalCenter
                        content: ":"
                        size: 22
                        weight: 700
                        customColor: root.ambientPrimary

                        opacity: uptimePulse
                        property real uptimePulse: 1.0
                        SequentialAnimation on uptimePulse {
                            loops: Animation.Infinite; running: true
                            NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                        }
                    }

                    // Minutes box
                    Rectangle {
                        width: 44; height: 48; radius: 10
                        color: Colors.surfaceContainer
                        border.color: Colors.surfaceContainerHigh
                        border.width: 1

                        Rectangle {
                            anchors.fill: parent; radius: 10
                            color: root.ambientSecondary; opacity: 0.05
                            Behavior on color { ColorAnimation { duration: 1000 } }
                        }

                        Column {
                            anchors.centerIn: parent
                            CustomText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                content: root.upMins.toString().padStart(2, '0')
                                size: 18
                                weight: 700
                                customColor: root.ambientSecondary
                            }
                            CustomText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                content: "MIN"
                                size: 8
                                weight: 700
                                customColor: Colors.outline
                            }
                        }
                    }
                }
            }

            // ── Battery Ring (imperative-dots inspired) ──────────────────
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 160
                Layout.preferredHeight: 160

                // Glow halo (completely static)
                Rectangle {
                    anchors.centerIn: batCore
                    width: batCore.width + 45
                    height: width
                    radius: width / 2
                    color: Colors.primary
                    opacity: 0.15
                    z: 0
                }

                Rectangle {
                    id: batCore
                    width: 150
                    height: 150
                    anchors.centerIn: parent
                    radius: width / 2
                    z: 1

                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: Colors.surfaceContainer }
                        GradientStop { position: 1.0; color: Colors.surface }
                    }

                    // Danger pulse
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Colors.error
                        opacity: root.isDangerState ? 0.15 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 1000 } }
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: root.isDangerState
                            NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.15; duration: 600; easing.type: Easing.InOutSine }
                        }
                    }

                    Item {
                        anchors.fill: parent

                        // Charging surge animation
                        property real pumpPhase: 0.0
                        NumberAnimation on pumpPhase {
                            running: isCharging
                            loops: Animation.Infinite
                            from: 0.0; to: 1.0; duration: 2000
                            easing.type: Easing.InOutSine
                            onStopped: batCanvas.requestPaint()
                        }

                        onPumpPhaseChanged: { if(isCharging) batCanvas.requestPaint() }

                        // Charging/discharge hover animation states
                        property real textPulse: 0.0
                        SequentialAnimation on textPulse {
                            loops: Animation.Infinite; running: true
                            NumberAnimation { from: 0.0; to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1.0; to: 0.0; duration: 1200; easing.type: Easing.InOutSine }
                        }



                        Canvas {
                            id: batCanvas
                            anchors.fill: parent
                            rotation: 180
                            antialiasing: true

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);

                                var centerX = width / 2;
                                var centerY = height / 2;
                                var radius = (width / 2) - 14;
                                var endAngle = (root.animCapacity) * 2 * Math.PI;

                                ctx.lineCap = "round";

                                // Background ring
                                ctx.lineWidth = 8;
                                ctx.beginPath();
                                ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
                                ctx.strokeStyle = Colors.surfaceContainerHigh;
                                ctx.stroke();

                                // Fill ring
                                var fillGrad = ctx.createLinearGradient(0, height, width, 0);
                                fillGrad.addColorStop(0, root.batColorStart.toString());
                                fillGrad.addColorStop(1, root.batColorEnd.toString());

                                ctx.lineWidth = 14;
                                ctx.beginPath();
                                ctx.arc(centerX, centerY, radius, 0, endAngle);
                                ctx.strokeStyle = fillGrad;
                                ctx.stroke();

                                // Charging surge — steady orbiting band (no beating)
                                if (endAngle > 0.1 && isCharging) {
                                    var orbAngle = parent.pumpPhase * endAngle;
                                    var orbStart = Math.max(0, orbAngle - 0.3);
                                    var orbEnd = Math.min(endAngle, orbAngle + 0.3);

                                    if (orbStart < orbEnd) {
                                        ctx.beginPath();
                                        ctx.arc(centerX, centerY, radius, orbStart, orbEnd);
                                        ctx.lineWidth = 22;
                                        ctx.strokeStyle = root.batColorStart.toString();
                                        ctx.globalAlpha = 0.85;
                                        ctx.stroke();

                                        orbStart = Math.max(0, orbAngle - 0.15);
                                        orbEnd = Math.min(endAngle, orbAngle + 0.15);
                                        ctx.beginPath();
                                        ctx.arc(centerX, centerY, radius, orbStart, orbEnd);
                                        ctx.lineWidth = 28;
                                        ctx.strokeStyle = root.batColorEnd.toString();
                                        ctx.globalAlpha = 1.0;
                                        ctx.stroke();
                                    }
                                }
                            }

                            Connections {
                                target: root
                                function onAnimCapacityChanged() { batCanvas.requestPaint() }
                                function onBatColorStartChanged() { batCanvas.requestPaint() }
                            }
                        }

                        // Center text
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0

                            CustomText {
                                Layout.alignment: Qt.AlignHCenter
                                content: Math.round(root.animCapacity * 100) + "%"
                                size: 40
                                weight: 700
                            }

                            CustomText {
                                Layout.alignment: Qt.AlignHCenter
                                content: isFull ? "FULLY CHARGED"
                                       : (isCharging ? "CHARGING" : "REMAINING")
                                size: 11
                                weight: 600
                                customColor: {
                                    if (isFull) return Colors.primary;
                                    if (isCharging) {
                                        return Qt.tint(Colors.primary, Qt.rgba(1, 1, 1, parent.textPulse * 0.4));
                                    }
                                    return Colors.outline;
                                }
                            }

                            // Time to full (only when charging)
                            CustomText {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 2
                                content: "Time: " + ServiceUPower.timeToFull
                                size: 9
                                weight: 600
                                visible: isCharging || isFull
                                customColor: Colors.outline
                            }


                        }
                    }

                    MouseArea {
                        id: ringMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: batCanvas.requestPaint()
                        onExited: batCanvas.requestPaint()
                    }
                }
            }

            // ── Battery Health ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialIconSymbol {
                    iconSize: 14
                    content: "health_and_safety"
                    customColor: ServiceUPower.health > 0.8 ? Colors.outline : Colors.error
                }

                CustomText {
                    content: "Battery Health: " + Math.round(ServiceUPower.health * 100) + "%"
                    size: 11
                    weight: 600
                    customColor: ServiceUPower.health > 0.8 ? Colors.outline : Colors.error
                }
            }

            // ── Power Profiles (imperative-dots style sliding pill) ───────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                CustomText {
                    content: "Power Profile"
                    size: 12
                    weight: 600
                    customColor: Colors.outline
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 10
                    color: Colors.surfaceContainer
                    border.color: Colors.surfaceContainerHigh
                    border.width: 1

                    // Sliding pill indicator
                    Rectangle {
                        id: sliderPill
                        width: (parent.width - 2) / 3
                        height: parent.height - 2
                        y: 1
                        radius: 8
                        x: ServiceUPower.powerProfile * (parent.width - 2) / 3 + 1

                        Behavior on x {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.2
                            }
                        }

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: root.profileStart
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }
                            GradientStop {
                                position: 1.0
                                color: root.profileEnd
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        Repeater {
                            model: ServiceUPower.powerProfiles

                            delegate: Item {
                                required property int index
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                readonly property bool isActive: ServiceUPower.powerProfile === index

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    MaterialIconSymbol {
                                        iconSize: 16
                                        content: modelData.icon
                                        customColor: isActive
                                            ? Colors.primaryText
                                            : (profHov.containsMouse ? Colors.surfaceText : Colors.outline)
                                        Behavior on customColor { ColorAnimation { duration: 200 } }
                                    }

                                    CustomText {
                                        content: modelData.name
                                        size: 12
                                        weight: 700
                                        customColor: isActive
                                            ? Colors.primaryText
                                            : (profHov.containsMouse ? Colors.surfaceText : Colors.outline)
                                    }
                                }

                                MouseArea {
                                    id: profHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ServiceUPower.setPowerProfile(index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
