import QtQuick
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

PopupWindow {
    id: root
    implicitWidth: 420
    implicitHeight: 520
    visible: true
    color: "transparent"
    signal close

    anchor {
        window: layout
        rect.x: utility.x + utility.width - implicitWidth
        rect.y: utility.y + utility.height + 4
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: true
        windows: [QsWindow.window]
        onCleared: root.close()
    }

    // ── Colors ────────────────────────────────────────────────────────
    readonly property color _base: Colors.surfaceDim
    readonly property color _mantle: Colors.surfaceContainerLowest
    readonly property color _crust: Colors.surface
    readonly property color _text: Colors.surfaceText
    readonly property color _subtext0: Colors.outline
    readonly property color _overlay0: Colors.surfaceVariant
    readonly property color _surface0: Colors.surfaceContainer
    readonly property color _surface1: Colors.surfaceContainerHigh
    readonly property color _surface2: Colors.surfaceContainerHighest
    readonly property color _mauve: Colors.tertiary
    readonly property color _sapphire: Colors.primary
    readonly property color _red: Colors.error
    readonly property color _peach: Colors.secondary
    readonly property color _maroon: Colors.error
    readonly property color _blue: Colors.primary

    readonly property color modeColor: Qt.lighter(_sapphire, 1.15)

    // ── State ────────────────────────────────────────────────────────
    property bool wifiPower: false
    property var wifiConnected: null
    property var wifiNetworks: []
    property string connectingId: ""
    property string failedId: ""
    property var busyTasks: ({})

    // Password prompt state
    property bool showPasswordPrompt: false
    property string pendingSsid: ""
    property string pendingId: ""
    // Temp storage for retry with password
    property string _pendingSsidForPwd: ""
    property string _pendingIdForPwd: ""
    property bool _hasSecurityPending: false

    // ── Sound ────────────────────────────────────────────────────────
    function playSfx(filename) {
        try {
            var path = Quickshell.env("HOME") + "/.config/quickshell/network/sounds/" + filename;
            Quickshell.execDetached(["sh", "-c", "pw-play '" + path + "' 2>/dev/null || paplay '" + path + "' 2>/dev/null"]);
        } catch (e) {}
    }

    // ── Orbit animation ──────────────────────────────────────────────
    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0
        to: Math.PI * 2
        duration: 200000
        loops: Animation.Infinite
        running: true
    }

    property real introState: 0
    Behavior on introState {
        NumberAnimation {
            duration: 1500
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: {
        introState = 1;
        refreshPolls();
    }

    // ── Info nodes ─────────────────────────────────────────────────
    ListModel { id: infoListModel }

    function updateInfoNodes() {
        infoListModel.clear();
        if (!currentConn || !currentPower) return;

        if (wifiConnected) {
            var sig = wifiConnected.signal || "0";
            var sec = wifiConnected.security || "Open";
            var ip = wifiConnected.ip || "";
            var freq = wifiConnected.freq || "";

            infoListModel.append({ label: "Signal", value: sig + "%" });
            if (sec) infoListModel.append({ label: "Security", value: sec });
            if (ip) infoListModel.append({ label: "IP", value: ip });
            if (freq) infoListModel.append({ label: "Band", value: freq });
        }
    }

    onWifiConnectedChanged: {
        if (wifiConnected) {
            Qt.callLater(updateInfoNodes);
        }
    }

    // ── Polling ──────────────────────────────────────────────────────
    function refreshPolls() {
        wifiPoller.running = true;
    }

    function processWifiData(textData) {
        try {
            var data = JSON.parse(textData.trim());
            wifiPower = data.power === "on";
            wifiConnected = data.connected || null;
            wifiNetworks = data.networks || [];
            if (wifiConnected) {
                for (var i = 0; i < wifiNetworks.length; i++) {
                    if (wifiNetworks[i].id === wifiConnected.ssid || wifiNetworks[i].ssid === wifiConnected.ssid) {
                        wifiConnected.icon = wifiNetworks[i].icon || wifiConnected.icon;
                        wifiConnected.signal = wifiNetworks[i].signal || wifiConnected.signal;
                        wifiConnected.security = wifiNetworks[i].security || wifiConnected.security;
                        break;
                    }
                }
            }
        } catch (e) {}
    }

    Process {
        id: wifiPoller
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/network/wifi_panel_logic.sh"]
        stdout: StdioCollector {
            onStreamFinished: root.processWifiData(this.text)
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: refreshPolls()
    }

    // ── Connect ──────────────────────────────────────────────────────
    Process {
        id: connectProc
        property string targetId: ""
        onExited: {
            var bt = root.busyTasks;
            delete bt[targetId];
            root.busyTasks = Object.assign({}, bt);
            root.connectingId = "";
            if (exitCode !== 0) {
                root.failedId = targetId;
                failTimer.restart();
                // If we tried without password and network has security, show password prompt
                if (root._hasSecurityPending && root._pendingSsidForPwd !== "") {
                    root.showPasswordPrompt = true;
                    root.pendingSsid = root._pendingSsidForPwd;
                    root.pendingId = root._pendingIdForPwd;
                }
            } else {
                root.playSfx("connect.wav");
                Qt.callLater(updateInfoNodes);
            }
            root._pendingSsidForPwd = "";
            root._pendingIdForPwd = "";
            root._hasSecurityPending = false;
            refreshPolls();
        }
    }

    Timer {
        id: failTimer
        interval: 4000
        onTriggered: root.failedId = ""
    }
    Timer {
        id: busyTimeout
        interval: 15000
        onTriggered: {
            root.busyTasks = ({});
            root.connectingId = "";
        }
    }

    function toggleWifiPower() {
        var turningOn = !wifiPower;
        playSfx(turningOn ? "power_on.wav" : "power_off.wav");
        Quickshell.execDetached(["nmcli", "radio", "wifi", wifiPower ? "off" : "on"]);
        wifiPower = !wifiPower;
        if (!wifiPower) { infoListModel.clear(); }
        Qt.callLater(refreshPolls);
    }

    function connectNetwork(mode, id, name, password) {
        root.connectingId = id;
        root.failedId = "";
        var bt = root.busyTasks;
        bt[id] = true;
        root.busyTasks = Object.assign({}, bt);
        busyTimeout.restart();

        connectProc.targetId = id;
        if (mode === "wifi") {
            if (password && password !== "") {
                connectProc.command = ["bash", "-c", "nmcli device wifi connect '" + name + "' password '" + password + "'"];
            } else {
                connectProc.command = ["bash", "-c", "nmcli device wifi connect '" + name + "'"];
            }
        }
        connectProc.running = true;
    }

    function disconnectNetwork(mode, id) {
        var bt = root.busyTasks;
        bt[id] = true;
        root.busyTasks = Object.assign({}, bt);
        busyTimeout.restart();

        connectProc.command = ["bash", "-c", "nmcli device disconnect $(nmcli -t -f DEVICE,TYPE d | awk -F: '$2==\"wifi\"{print $1;exit}')"];
        connectProc.targetId = id;
        connectProc.running = true;
        playSfx("disconnect.wav");
    }

    readonly property bool currentPower: wifiPower
    readonly property bool currentConn: !!wifiConnected

    // ── UI ─────────────────────────────────────────────────────────────
    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 20
        color: _base
        border.color: _surface0
        border.width: 1
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

        // ── Password prompt overlay ──────────────────────────────────
        Item {
            anchors.fill: parent
            visible: showPasswordPrompt
            z: 100

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.5)
                radius: 20

                MouseArea {
                    anchors.fill: parent
                    onClicked: { /* block clicks behind */ }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 80
                height: 160
                radius: 16
                color: _base
                border.color: _surface1
                border.width: 1
                focus: true

                Keys.onEscapePressed: {
                    root.showPasswordPrompt = false;
                    root.pendingSsid = "";
                    root.pendingId = "";
                    pwdInput.text = "";
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    width: parent.width - 40

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        font.family: "JetBrains Mono"
                        font.pixelSize: 14
                        font.weight: Font.Black
                        color: _text
                        text: "Connect to " + root.pendingSsid
                        elide: Text.ElideRight
                        Layout.maximumWidth: parent.width
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 10
                        color: _surface0
                        border.color: pwdInput.activeFocus ? modeColor : "transparent"
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        TextInput {
                            id: pwdInput
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "JetBrains Mono"
                            font.pixelSize: 13
                            color: _text
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            onAccepted: {
                                if (text.length > 0) {
                                    root.connectNetwork("wifi", root.pendingId, root.pendingSsid, text);
                                    root.showPasswordPrompt = false;
                                    root.pendingSsid = "";
                                    root.pendingId = "";
                                    text = "";
                                }
                            }

                            Timer {
                                interval: 100
                                running: root.showPasswordPrompt
                                onTriggered: pwdInput.forceActiveFocus()
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 32
                            radius: 16
                            color: cancelBtn.containsMouse ? _surface1 : _surface0
                            Behavior on color { ColorAnimation { duration: 130 } }

                            Text {
                                anchors.centerIn: parent
                                font.family: "JetBrains Mono"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: _text
                                text: "Cancel"
                            }

                            MouseArea {
                                id: cancelBtn
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.showPasswordPrompt = false;
                                    root.pendingSsid = "";
                                    root.pendingId = "";
                                    pwdInput.text = "";
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 32
                            radius: 16
                            color: connectBtn.containsMouse ? Qt.lighter(modeColor, 1.15) : modeColor
                            Behavior on color { ColorAnimation { duration: 130 } }

                            Text {
                                anchors.centerIn: parent
                                font.family: "JetBrains Mono"
                                font.pixelSize: 12
                                font.weight: Font.Black
                                color: _crust
                                text: "Connect"
                            }

                            MouseArea {
                                id: connectBtn
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (pwdInput.text.length > 0) {
                                        root.connectNetwork("wifi", root.pendingId, root.pendingSsid, pwdInput.text);
                                        root.showPasswordPrompt = false;
                                        root.pendingSsid = "";
                                        root.pendingId = "";
                                        pwdInput.text = "";
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Ambient orbiting blobs ────────────────────────────────────
        Rectangle {
            width: parent.width * 0.8
            height: width
            radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.cos(root.globalOrbitAngle * 2) * 100
            y: (parent.height / 2 - height / 2) + Math.sin(root.globalOrbitAngle * 2) * 80
            opacity: currentPower ? 0.08 : 0.02
            color: currentConn ? modeColor : _surface2
            Behavior on color { ColorAnimation { duration: 1000 } }
            Behavior on opacity { NumberAnimation { duration: 1000 } }
        }

        Rectangle {
            width: parent.width * 0.9
            height: width
            radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.sin(root.globalOrbitAngle * 1.5) * (-100)
            y: (parent.height / 2 - height / 2) + Math.cos(root.globalOrbitAngle * 1.5) * (-80)
            opacity: currentPower ? 0.06 : 0.01
            color: currentConn ? Qt.darker(modeColor, 1.25) : _surface1
            Behavior on color { ColorAnimation { duration: 1000 } }
            Behavior on opacity { NumberAnimation { duration: 1000 } }
        }

        // ── Radar rings ──────────────────────────────────────────────
        Repeater {
            model: 3
            Rectangle {
                x: parent.width / 2 - width / 2
                y: 100 - height / 2
                width: 280 + (index * 100)
                height: width
                radius: width / 2
                color: "transparent"
                border.color: modeColor
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 1000 } }
                opacity: currentPower ? (0.06 - (index * 0.02)) : 0.02
            }
        }

        // ── Scanning rings ──────────────────────────────────────────
        Repeater {
            model: currentPower && !currentConn ? 3 : 0
            Rectangle {
                anchors.centerIn: parent
                width: 60; height: 60; radius: 30
                color: "transparent"
                border.color: modeColor
                border.width: 2
                opacity: 0.6
                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    PauseAnimation { duration: index * 400 }
                    NumberAnimation { from: 1.0; to: 3.5; duration: 2000; easing.type: Easing.OutSine }
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    PauseAnimation { duration: index * 400 }
                    NumberAnimation { from: 0.7; to: 0.0; duration: 2000; easing.type: Easing.OutSine }
                }
            }
        }

        // ── Header ────────────────────────────────────────────────────
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Item {
                        Layout.fillWidth: true
                    }

                    // Close
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 14
                        color: closeHov.containsMouse ? _surface1 : "transparent"
                        Behavior on color { ColorAnimation { duration: 130 } }

                        Text {
                            anchors.centerIn: parent
                            font.family: "JetBrains Mono"
                            font.pixelSize: 13
                            font.weight: Font.Black
                            color: _text
                            text: "X"
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
            }

            // ── Connection status core + Info nodes ─────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 140

                // Status core circle — click to toggle power
                Rectangle {
                    id: coreCircle
                    x: 20
                    y: (parent.height - height) / 2 - 18
                    width: 120
                    height: 120
                    radius: 60

                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop {
                            position: 0.0
                            color: currentPower ? (currentConn ? Qt.lighter(modeColor, 1.15) : _surface0) : _mantle
                        }
                        GradientStop {
                            position: 1.0
                            color: currentPower ? (currentConn ? modeColor : _base) : _crust
                        }
                    }
                    border.color: currentConn ? Qt.lighter(modeColor, 1.1) : _surface1
                    border.width: 2

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        // WiFi signal bar in center circle
                        MaterialIconSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            content: {
                                if (!currentPower)
                                    return "signal_wifi_off";
                                if (currentConn && wifiConnected) {
                                    var s = parseInt(wifiConnected.signal) || 0;
                                    if (s >= 90) return "signal_wifi_4_bar";
                                    if (s >= 60) return "network_wifi_3_bar";
                                    if (s >= 30) return "network_wifi_2_bar";
                                    return "network_wifi_1_bar";
                                }
                                return "signal_wifi_4_bar";
                            }                                iconSize: 40
                            customColor: currentConn ? _crust : (currentPower ? _text : _overlay0)
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: 70
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            font.pixelSize: 9
                            color: currentConn ? _crust : (currentPower ? _subtext0 : _overlay0)
                            elide: Text.ElideRight
                            text: {
                                if (wifiConnected)
                                    return wifiConnected.ssid || "Connected";
                                if (!currentPower)
                                    return "Disabled";
                                return "Scanning...";
                            }
                        }


                    }

                    // Click to toggle power
                    MouseArea {
                        id: coreMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toggleWifiPower()
                    }

                    // Pulse ring
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 30
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.color: modeColor
                        border.width: 2
                        z: -1

                        property real pulseOp: 0.0
                        property real pulseSc: 1.0
                        opacity: (currentConn && currentPower) ? pulseOp : 0.0
                        scale: pulseSc

                        Timer {
                            interval: 45
                            running: parent.opacity > 0.01
                            repeat: true
                            onTriggered: {
                                var time = Date.now() / 1000;
                                parent.pulseOp = 0.3 + Math.sin(time * 2.5) * 0.15;
                                parent.pulseSc = 1.02 + Math.cos(time * 3.0) * 0.02;
                            }
                        }
                    }
                }

                // ── Info nodes (no icons) ────────────────────────────
                Item {
                    anchors.left: coreCircle.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.top: coreCircle.top
                    anchors.bottom: coreCircle.bottom

                    opacity: currentConn && currentPower ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 400 } }

                    clip: true

                    ListView {
                        id: infoListView
                        anchors.fill: parent
                        spacing: 3
                        model: infoListModel
                        orientation: ListView.Vertical
                        interactive: false

                        delegate: Rectangle {
                            required property var modelData
                            width: infoListView.width
                            implicitHeight: 24
                            radius: 6
                            color: Qt.alpha(modeColor, 0.12)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: _subtext0
                                    text: modelData.label || ""
                                    elide: Text.ElideRight
                                }

                                Text {
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 10
                                    font.weight: Font.Black
                                    color: _text
                                    text: modelData.value || ""
                                }
                            }
                        }
                    }
                }
            }

            // ── Separator ─────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: _surface1
                Layout.leftMargin: 12
                Layout.rightMargin: 12
            }

            // ── Network/Device list (always visible, no icons) ────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                Layout.bottomMargin: 4

                ListView {
                    id: listView
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4
                    model: wifiNetworks

                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: listView.width - 16
                        implicitHeight: 46
                        radius: 12
                        color: {
                            if (isBusy)
                                return Qt.lighter(modeColor, 1.3);
                            if (isConnected)
                                return modeColor;
                            if (ma.containsMouse)
                                return _surface1;
                            return "transparent";
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        readonly property string itemId: modelData.id || modelData.ssid || ""
                        readonly property bool isBusy: !!root.busyTasks[itemId] || root.connectingId === itemId
                        readonly property bool isConnected: root.wifiConnected && (root.wifiConnected.ssid === modelData.id || root.wifiConnected.ssid === modelData.ssid)
                        readonly property bool isFailed: root.failedId === itemId
                        readonly property bool hasSecurity: modelData.security && modelData.security !== "Open" && modelData.security !== "--" && modelData.security !== ""

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: _red
                            opacity: isFailed ? 0.3 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 6
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Bold
                                    font.pixelSize: 13
                                    color: {
                                        if (isConnected)
                                            return _crust;
                                        if (ma.containsMouse)
                                            return _text;
                                        return _subtext0;
                                    }
                                    elide: Text.ElideRight
                                    text: modelData.ssid || modelData.name || modelData.id || "Unknown"
                                }

                                Text {
                                    Layout.fillWidth: true
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 11
                                    color: isConnected ? Qt.rgba(0, 0, 0, 0.5) : _overlay0
                                    text: {
                                        if (isBusy)
                                            return "Connecting...";
                                        if (isConnected)
                                            return "Connected";
                                        var sig = parseInt(modelData.signal) || 0;
                                        var sec = modelData.security || "";
                                        if (sec && sec !== "Open" && sec !== "")
                                            return sig + "% · " + sec;
                                        return sig + "%";
                                    }
                                }
                            }

                            // Disconnect button (connected items)
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 13
                                visible: isConnected && !isBusy
                                color: discBtn.containsMouse ? Qt.alpha(_red, 0.4) : Qt.alpha(_crust, 0.15)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 10
                                    font.weight: Font.Black
                                    color: discBtn.containsMouse ? _red : _crust
                                    text: "X"
                                }

                                MouseArea {
                                    id: discBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!isBusy && isConnected)
                                            root.disconnectNetwork(activeMode, itemId);
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (isBusy || isConnected)
                                    return;
                                // Try connecting without password first (nmcli uses saved creds if available)
                                root.connectNetwork("wifi", itemId, modelData.ssid || modelData.name || "", "");
                                // If it fails and network has security, password prompt appears via connectProc.onExited
                                root._pendingSsidForPwd = modelData.ssid || modelData.name || "";
                                root._pendingIdForPwd = itemId;
                                root._hasSecurityPending = hasSecurity;
                            }
                        }
                    }
                }

                // Empty state (no icons, just text)
                Text {
                    anchors.centerIn: parent
                    font.family: "JetBrains Mono"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: _overlay0
                    opacity: wifiNetworks.length === 0 && wifiPower ? 0.5 : 0
                    text: "No networks found"
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
            }
        }
    }
}
