pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings
import "../../MatrialShapes/" as MaterialShapes

Item {
    id: root
    anchors.fill: parent

    signal backClicked
    property bool showBack: true

    property bool scanning: false
    property bool passwordPrompt: false
    property bool addMode: false
    property bool joining: false
    property var pendingNetwork: null
    property string connectionError: ""
    property bool detailsOpen: true

    property bool showQr: false
    property string qrSource: ""
    property bool qrFailed: false

    property string ipAddress: ""
    property int freqMhz: 0
    property bool autoconnect: true
    property int savedCount: 0

    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property bool hardwareOn: Networking.wifiHardwareEnabled
    readonly property var current: root.wifiOn ? ServiceNetwork.connectedNetwork : null
    readonly property string iface: ServiceNetwork.wifiDevice?.name ?? ""
    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"

    function bucket(n) { return ServiceNetwork.bucket(n) }
    function ordered(list) { return ServiceNetwork.ordered(list) }

    readonly property var savedRows: root.ordered(ServiceNetwork.savedNetworks)
    readonly property var nearbyRows: root.ordered(ServiceNetwork.available.filter(n => (n.name ?? "") !== ""))
    readonly property var rows: root.wifiOn ? root.savedRows.concat(root.nearbyRows) : []

    function strengthLabel(strength) { return ServiceNetwork.strengthLabel(strength) }
    function securityLabel(security) { return ServiceNetwork.securityLabel(security) }
    function isSecured(security) { return ServiceNetwork.isSecured(security) }
    function band(mhz) { return ServiceNetwork.band(mhz) }

    readonly property string currentLine: {
        const n = root.current
        if (!n) return ""
        if (n.state === ConnectionState.Disconnecting) return "Disconnecting…"
        return [root.strengthLabel(n.signalStrength) + " signal", root.band(root.freqMhz), root.securityLabel(n.security)]
            .filter(s => s !== "").join(", ")
    }

    function askPassword(network) {
        root.addMode = false
        root.pendingNetwork = network
        root.passwordPrompt = true
    }

    function askHidden() {
        root.connectionError = ""
        root.pendingNetwork = null
        root.addMode = true
        root.passwordPrompt = true
    }

    function submitPassword(psk) {
        if (root.pendingNetwork) root.pendingNetwork.connectWithPsk(psk)
        root.passwordPrompt = false
    }

    function joinHidden(ssid, psk) {
        root.connectionError = ""
        root.joining = true
        joiner.command = ["nmcli", "dev", "wifi", "connect", ssid, "hidden", "yes"]
            .concat(psk !== "" ? ["password", psk] : [])
        joiner.running = true
    }

    function dismissPassword() {
        root.passwordPrompt = false
        root.addMode = false
        root.joining = false
        root.pendingNetwork = null
        root.connectionError = ""
    }

    function activate(network) {
        if (!network) return
        root.connectionError = ""
        if (network.connected) {
            network.disconnect()
            return
        }
        if (!network.known && root.isSecured(network.security)) {
            root.askPassword(network)
            return
        }
        network.connect()
    }

    function handleFailure(network, reason) {
        if (reason === ConnectionFailReason.NoSecrets) {
            root.connectionError = ""
            root.askPassword(network)
            return
        }
        if (root.pendingNetwork !== network && root.passwordPrompt) return
        switch (reason) {
        case ConnectionFailReason.WifiAuthTimeout:
            root.connectionError = "Wrong password"; break
        case ConnectionFailReason.WifiNetworkLost:
            root.connectionError = "Network out of range"; break
        case ConnectionFailReason.WifiClientDisconnected:
            root.connectionError = "Disconnected by the network"; break
        default:
            root.connectionError = "Connection failed"; break
        }
        if (reason === ConnectionFailReason.WifiAuthTimeout) root.askPassword(network)
    }

    function startScan() {
        if (!ServiceNetwork.scan()) return
        root.scanning = true
        scanTimer.restart()
    }

    function openSettings(from) {
        GlobalStates.openQuickSettings(4, from)
    }

    function share() {
        if (!root.current) return
        root.qrSource = ""
        root.qrFailed = false
        root.showQr = true
        ServiceNetwork.generateQr(root.current.name, root.current.security)
    }

    function refreshInfo() {
        if (info.running) return
        info.command = ["sh", "-c",
            "nmcli -t -g IP4.ADDRESS dev show \"$1\" 2>/dev/null | head -n1; "
            + "nmcli -t -f ACTIVE,FREQ dev wifi list --rescan no 2>/dev/null | awk -F: '$1==\"yes\"{print $2+0; exit}'; echo; "
            + "nmcli -g connection.autoconnect connection show id \"$2\" 2>/dev/null; echo; "
            + "nmcli -t -f TYPE connection show 2>/dev/null | awk '/802-11-wireless/{c++} END{print c+0}'",
            "sh", root.iface, root.current?.name ?? ""]
        info.running = true
    }

    function setAutoconnect(on) {
        if (!root.current) return
        root.autoconnect = on
        Quickshell.execDetached(["nmcli", "connection", "modify", "id", root.current.name,
                                 "connection.autoconnect", on ? "yes" : "no"])
    }

    function forgetCurrent() {
        if (!root.current) return
        const n = root.current
        n.forget()
        infoTimer.restart()
    }

    Process {
        id: info
        stdout: StdioCollector {
            id: infoOut
            onStreamFinished: {
                const lines = infoOut.text.split("\n").map(l => l.trim()).filter(l => l !== "")
                const ipLine = lines.find(l => /^\d+\.\d+\.\d+\.\d+/.test(l)) ?? ""
                root.ipAddress = ipLine.split("/")[0]
                const f = lines.find(l => /^\d{4}$/.test(l))
                root.freqMhz = f ? parseInt(f) : 0
                const ac = lines.find(l => l === "yes" || l === "no")
                root.autoconnect = ac !== "no"
                const count = lines.length > 0 ? parseInt(lines[lines.length - 1]) : 0
                root.savedCount = isNaN(count) ? 0 : count
            }
        }
    }

    Process {
        id: joiner
        stderr: StdioCollector { id: joinErr }
        onExited: code => {
            root.joining = false
            if (code === 0) {
                root.dismissPassword()
                infoTimer.restart()
            } else {
                const msg = (joinErr.text || "").trim().split("\n").pop()
                root.connectionError = msg !== "" ? msg.replace(/^Error:\s*/, "") : "Couldn't join that network"
            }
        }
    }

    Timer {
        id: infoTimer
        interval: 1200
        onTriggered: root.refreshInfo()
    }

    onCurrentChanged: infoTimer.restart()

    property var downHist: []
    property var upHist: []

    Component.onCompleted: {
        ServiceSystemInfo.retain()
        if (root.wifiOn) root.startScan()
        root.refreshInfo()
    }
    Component.onDestruction: ServiceSystemInfo.release()

    Connections {
        target: ServiceNetwork
        enabled: root.showQr
        function onQrGenerated(path) {
            root.qrSource = "file://" + path + "?" + Date.now()
        }
        function onQrFailed() {
            root.qrFailed = true
        }
    }

    Loader {
        active: root.passwordPrompt
        sourceComponent: WifiPasswordPrompt {
            askName: root.addMode
            working: root.joining
            network: root.addMode ? null : root.pendingNetwork
            errorText: root.connectionError
            onSubmitted: psk => root.submitPassword(psk)
            onSubmittedHidden: (ssid, psk) => root.joinHidden(ssid, psk)
            onDismissed: root.dismissPassword()
        }
    }

    Timer {
        id: scanTimer
        interval: 8000
        onTriggered: root.scanning = false
    }

    opacity: 0
    EffectsAnim {
        target: root
        property: "opacity"
        from: 0; to: 1
        speed: "slow"
        running: true
    }

    component SectionLabel: RowLayout {
        id: sl
        property string text: ""
        property string note: ""
        property bool busy: false

        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.topMargin: 12
        Layout.bottomMargin: 4
        spacing: 8

        CustomText {
            Layout.fillWidth: true
            content: sl.text
            size: 14
            weight: 800
        }

        MaterialShapes.ShapeCanvas {
            id: burst
            visible: sl.busy
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            roundedPolygon: "softBurst"
            color: Colors.primary

            NumberAnimation on angle {
                from: 0; to: 360
                duration: 2400
                loops: Animation.Infinite
                running: sl.busy && sl.visible
            }
        }

        CustomText {
            visible: sl.note !== ""
            content: sl.note
            size: 12
            weight: 500
            customColor: Colors.surfaceVariantText
        }
    }

    component GroupRow: Rectangle {
        id: gr
        property bool first: false
        property bool last: false

        Layout.fillWidth: true
        implicitHeight: 60
        topLeftRadius: gr.first ? 24 : 6
        topRightRadius: gr.first ? 24 : 6
        bottomLeftRadius: gr.last ? 24 : 6
        bottomRightRadius: gr.last ? 24 : 6
        color: Colors.surfaceContainer
        Behavior on color { EffectsColorAnim {} }
    }

    component SplitButton: RowLayout {
        id: sb
        property string label: ""
        property bool open: false
        signal pressed()
        signal toggled()

        spacing: 2

        Rectangle {
            Layout.preferredHeight: 40
            Layout.preferredWidth: sbText.implicitWidth + 28
            topLeftRadius: 20
            bottomLeftRadius: 20
            topRightRadius: 4
            bottomRightRadius: 4
            color: Colors.primary

            CustomText {
                id: sbText
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 1
                content: sb.label
                size: 13
                weight: 700
                customColor: Colors.primaryText
            }

            RippleEffect {
                anchors.fill: parent
                topLeftRadius: 20
                bottomLeftRadius: 20
                topRightRadius: 4
                bottomRightRadius: 4
                hoverColor: Qt.alpha(Colors.primaryText, 0.08)
                rippleColor: Qt.alpha(Colors.primaryText, 0.18)
                onClicked: sb.pressed()
            }
        }

        Rectangle {
            id: sbArrow
            Layout.preferredHeight: 40
            Layout.preferredWidth: 36
            topLeftRadius: sb.open ? 20 : 4
            bottomLeftRadius: sb.open ? 20 : 4
            topRightRadius: 20
            bottomRightRadius: 20
            color: Colors.primary
            Behavior on topLeftRadius { SpatialAnim { speed: "fast" } }
            Behavior on bottomLeftRadius { SpatialAnim { speed: "fast" } }

            MaterialIconSymbol {
                anchors.centerIn: parent
                content: "keyboard_arrow_down"
                iconSize: 20
                customColor: Colors.primaryText
                rotation: sb.open ? 180 : 0
                Behavior on rotation { SpatialAnim { speed: "fast" } }
            }

            RippleEffect {
                anchors.fill: parent
                topLeftRadius: sbArrow.topLeftRadius
                bottomLeftRadius: sbArrow.bottomLeftRadius
                topRightRadius: 20
                bottomRightRadius: 20
                hoverColor: Qt.alpha(Colors.primaryText, 0.08)
                rippleColor: Qt.alpha(Colors.primaryText, 0.18)
                onClicked: sb.toggled()
            }
        }
    }

    component DetailLine: RowLayout {
        id: dl
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 34
        spacing: 12

        CustomText {
            Layout.fillWidth: true
            content: dl.label
            size: 12
            weight: 500
            customColor: Colors.surfaceVariantText
        }

        CustomText {
            content: dl.value
            size: 12
            weight: 700
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            spacing: 8

            M3IconButton {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                icon: "chevron_backward"
                iconSize: 20
                visible: root.showBack
                onClicked: root.backClicked()
            }

            CustomText {
                Layout.fillWidth: true
                content: "Wi-Fi"
                family: root.displayFamily
                size: 30
                weight: 400
            }

            Rectangle {
                visible: root.wifiOn
                Layout.preferredHeight: 40
                Layout.preferredWidth: addRow.implicitWidth + 28
                radius: 20
                color: Colors.tertiaryContainer

                RowLayout {
                    id: addRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIconSymbol {
                        content: "add"
                        iconSize: 20
                        customColor: Colors.tertiaryContainerText
                    }

                    CustomText {
                        content: "Add"
                        size: 13
                        weight: 800
                        customColor: Colors.tertiaryContainerText
                    }
                }

                RippleEffect {
                    anchors.fill: parent
                    radius: 20
                    hoverColor: Qt.alpha(Colors.tertiaryContainerText, 0.08)
                    rippleColor: Qt.alpha(Colors.tertiaryContainerText, 0.18)
                    onClicked: root.askHidden()
                }

                CustomToolTip {
                    content: "Add a hidden network"
                    visible: addTip.hovered
                }

                HoverHandler { id: addTip }
            }

            M3IconButton {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                id: netGear
                icon: "settings"
                iconSize: 20
                tip: "Network settings"
                onClicked: root.openSettings(netGear)
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: flick
                anchors.fill: parent
                contentHeight: body.implicitHeight + 16
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                ScrollBar.vertical: CustomScrollBar { id: scrollBar }

                ColumnLayout {
                    id: body
                    width: flick.width - (scrollBar.size < 1.0 ? 14 : 0)
                    spacing: 2

                    GroupRow {
                        first: true
                        last: true
                        color: root.wifiOn ? Colors.primaryContainer : Colors.surfaceContainer

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 14
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                CustomText {
                                    Layout.fillWidth: true
                                    content: "Use Wi-Fi"
                                    size: 15
                                    weight: 800
                                    customColor: root.wifiOn ? Colors.primaryContainerText : Colors.surfaceText
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    visible: !root.hardwareOn
                                    content: "Blocked by the hardware switch or airplane mode"
                                    size: 12
                                    weight: 500
                                    customColor: Colors.surfaceVariantText
                                }
                            }

                            CustomToogle {
                                isToggleOn: Networking.wifiEnabled
                                opacity: root.hardwareOn ? 1 : 0.4
                                onToggled: s => { if (root.hardwareOn) Networking.wifiEnabled = s }
                            }
                        }
                    }

                    SectionLabel {
                        visible: root.wifiOn
                        text: root.current ? "Connected" : ServiceNetwork.connectionType === "ethernet" ? "On Ethernet" : "Not connected"
                        note: root.current ? "↓ " + ServiceSystemInfo.formatNetSpeed(ServiceSystemInfo.netDownloadBps)
                                             + "  ↑ " + ServiceSystemInfo.formatNetSpeed(ServiceSystemInfo.netUploadBps) : ""
                    }

                    Rectangle {
                        id: card
                        Layout.fillWidth: true
                        visible: root.current !== null
                        implicitHeight: root.detailsOpen ? 64 + details.implicitHeight : 64
                        Behavior on implicitHeight { SpatialAnim {} }
                        clip: true
                        radius: 24
                        color: Colors.surfaceContainer

                        RowLayout {
                            x: 10
                            y: 10
                            width: parent.width - 20
                            height: 44
                            spacing: 12

                            Item {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44

                                MaterialShapes.ShapeCanvas {
                                    anchors.fill: parent
                                    roundedPolygon: "cookie9"
                                    color: Colors.tertiaryContainer
                                }

                                WifiGlyph {
                                    anchors.centerIn: parent
                                    size: 22
                                    strength: root.current?.signalStrength ?? 0
                                    color: Colors.tertiaryContainerText
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 2

                                CustomText {
                                    Layout.fillWidth: true
                                    content: root.current?.name ?? ""
                                    size: 14
                                    weight: 800
                                }

                                CustomText {
                                    Layout.fillWidth: true
                                    content: root.currentLine
                                    size: 12
                                    weight: 500
                                    customColor: Colors.surfaceVariantText
                                }
                            }

                            SplitButton {
                                label: "Disconnect"
                                open: root.detailsOpen
                                onPressed: root.current?.disconnect()
                                onToggled: root.detailsOpen = !root.detailsOpen
                            }
                        }

                        ColumnLayout {
                            id: details
                            x: 16
                            y: 64
                            width: parent.width - 32
                            spacing: 0
                            opacity: root.detailsOpen ? 1 : 0
                            Behavior on opacity { EffectsAnim {} }

                            DetailLine {
                                label: "IP address"
                                value: root.ipAddress !== "" ? root.ipAddress : "—"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                spacing: 12

                                CustomText {
                                    Layout.fillWidth: true
                                    content: "Connect automatically"
                                    size: 12
                                    weight: 500
                                    customColor: Colors.surfaceVariantText
                                }

                                CustomToogle {
                                    isToggleOn: root.autoconnect
                                    onToggled: s => root.setAutoconnect(s)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 8
                                Layout.bottomMargin: 12
                                spacing: 2

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.preferredHeight: 40
                                    topLeftRadius: 20
                                    bottomLeftRadius: 20
                                    topRightRadius: 6
                                    bottomRightRadius: 6
                                    color: Colors.secondaryContainer

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        MaterialIconSymbol {
                                            content: "qr_code_2"
                                            iconSize: 18
                                            customColor: Colors.secondaryContainerText
                                        }

                                        CustomText {
                                            content: "Share"
                                            size: 13
                                            weight: 700
                                            customColor: Colors.secondaryContainerText
                                        }
                                    }

                                    RippleEffect {
                                        anchors.fill: parent
                                        topLeftRadius: 20
                                        bottomLeftRadius: 20
                                        topRightRadius: 6
                                        bottomRightRadius: 6
                                        hoverColor: Qt.alpha(Colors.secondaryContainerText, 0.08)
                                        rippleColor: Qt.alpha(Colors.secondaryContainerText, 0.18)
                                        onClicked: root.share()
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.preferredHeight: 40
                                    topLeftRadius: 6
                                    bottomLeftRadius: 6
                                    topRightRadius: 20
                                    bottomRightRadius: 20
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Colors.outlineVariant

                                    CustomText {
                                        anchors.centerIn: parent
                                        content: "Forget"
                                        size: 13
                                        weight: 700
                                        customColor: Colors.error
                                    }

                                    RippleEffect {
                                        anchors.fill: parent
                                        topLeftRadius: 6
                                        bottomLeftRadius: 6
                                        topRightRadius: 20
                                        bottomRightRadius: 20
                                        hoverColor: Qt.alpha(Colors.error, 0.08)
                                        rippleColor: Qt.alpha(Colors.error, 0.18)
                                        onClicked: root.forgetCurrent()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 64
                        visible: root.wifiOn && root.current === null
                        radius: 24
                        color: Colors.surfaceContainer

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 16
                            spacing: 12

                            Item {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44

                                MaterialShapes.ShapeCanvas {
                                    anchors.fill: parent
                                    roundedPolygon: "cookie9"
                                    color: Colors.surfaceContainerHighest
                                }

                                MaterialIconSymbol {
                                    anchors.centerIn: parent
                                    content: ServiceNetwork.connectionType === "ethernet" ? "lan" : "wifi_find"
                                    iconSize: 22
                                    customColor: Colors.surfaceVariantText
                                }
                            }

                            CustomText {
                                Layout.fillWidth: true
                                content: ServiceNetwork.connectionType === "ethernet"
                                    ? "Using " + ServiceNetwork.activeInterface + ", pick a network to switch"
                                    : "Pick a network below"
                                size: 13
                                weight: 600
                                customColor: Colors.surfaceVariantText
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 40
                        visible: !root.wifiOn
                        spacing: 10

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 64
                            implicitHeight: 64

                            MaterialShapes.ShapeCanvas {
                                anchors.fill: parent
                                roundedPolygon: "cookie9"
                                color: Colors.surfaceContainerHigh
                            }

                            MaterialIconSymbol {
                                anchors.centerIn: parent
                                content: "wifi_off"
                                iconSize: 26
                                customColor: Colors.outline
                            }
                        }

                        CustomText {
                            Layout.alignment: Qt.AlignHCenter
                            content: root.hardwareOn ? "Turn Wi-Fi on to see networks" : "Wi-Fi is blocked"
                            size: 12
                            weight: 500
                            customColor: Colors.surfaceVariantText
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.wifiOn
                        spacing: 0

                        SectionLabel {
                            text: "Available"
                            busy: root.scanning
                            note: root.scanning ? "Searching" : ""
                        }

                        M3IconButton {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            Layout.topMargin: 8
                            visible: !root.scanning
                            icon: "refresh"
                            iconSize: 18
                            tip: "Search again"
                            onClicked: root.startScan()
                        }
                    }

                    Repeater {
                        model: ScriptModel { values: root.rows }

                        Rectangle {
                            id: net

                            required property var modelData
                            required property int index
                            readonly property bool first: net.index === 0
                            readonly property bool last: net.index === root.rows.length - 1
                            readonly property bool saved: net.modelData?.known ?? false
                            readonly property bool secured: root.isSecured(net.modelData?.security)
                            readonly property bool busy: net.modelData?.state === ConnectionState.Connecting
                                || net.modelData?.state === ConnectionState.Disconnecting

                            Layout.fillWidth: true
                            implicitHeight: 56
                            topLeftRadius: net.first ? 24 : 6
                            topRightRadius: net.first ? 24 : 6
                            bottomLeftRadius: net.last ? 24 : 6
                            bottomRightRadius: net.last ? 24 : 6
                            color: netRipple.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                            Behavior on color { EffectsColorAnim {} }

                            Connections {
                                target: net.modelData
                                ignoreUnknownSignals: true
                                function onConnectionFailed(reason) {
                                    root.handleFailure(net.modelData, reason)
                                }
                                function onConnectedChanged() {
                                    if (net.modelData?.connected) {
                                        root.connectionError = ""
                                        if (root.pendingNetwork === net.modelData) root.passwordPrompt = false
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 8
                                spacing: 14

                                WifiGlyph {
                                    size: 22
                                    strength: net.modelData?.signalStrength ?? 0
                                    color: net.saved ? Colors.primary : Colors.surfaceVariantText
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: 1

                                    CustomText {
                                        Layout.fillWidth: true
                                        content: net.modelData?.name ?? ""
                                        size: 14
                                        weight: 700
                                    }

                                    CustomText {
                                        Layout.fillWidth: true
                                        content: {
                                            const n = net.modelData
                                            if (n?.state === ConnectionState.Connecting) return "Connecting…"
                                            if (n?.state === ConnectionState.Disconnecting) return "Disconnecting…"
                                            const parts = [root.strengthLabel(n?.signalStrength)]
                                            if (net.saved) parts.unshift("Saved")
                                            parts.push(net.secured ? "secured" : "open")
                                            return parts.join(", ")
                                        }
                                        size: 11
                                        weight: 500
                                        customColor: Colors.surfaceVariantText
                                    }
                                }

                                CustomText {
                                    visible: !net.busy
                                    Layout.rightMargin: 10
                                    content: "Connect"
                                    size: 13
                                    weight: 800
                                    customColor: Colors.primary
                                }

                                Item {
                                    visible: net.busy
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: 36

                                    CustomCircularLoader {
                                        anchors.centerIn: parent
                                        size: 18
                                        trackWidth: 2
                                        waveAmplitude: 0
                                        highlightColor: Colors.primary
                                        trackColor: Colors.surfaceContainerHighest
                                    }
                                }
                            }

                            RippleEffect {
                                id: netRipple
                                anchors.fill: parent
                                topLeftRadius: net.topLeftRadius
                                topRightRadius: net.topRightRadius
                                bottomLeftRadius: net.bottomLeftRadius
                                bottomRightRadius: net.bottomRightRadius
                                onClicked: if (!net.busy) root.activate(net.modelData)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 56
                        visible: root.wifiOn && root.rows.length === 0
                        radius: 24
                        color: Colors.surfaceContainer

                        CustomText {
                            anchors.centerIn: parent
                            content: root.scanning ? "Looking for networks…" : "No other networks found"
                            size: 12
                            weight: 500
                            customColor: Colors.surfaceVariantText
                        }
                    }

                    GroupRow {
                        Layout.topMargin: 10
                        visible: root.wifiOn
                        first: true
                        last: true
                        implicitHeight: 56

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                CustomText { Layout.fillWidth: true; content: "Saved networks"; size: 14; weight: 700 }
                                CustomText {
                                    Layout.fillWidth: true
                                    content: root.savedCount === 1 ? "1 network" : root.savedCount + " networks"
                                    size: 12
                                    weight: 500
                                    customColor: Colors.surfaceVariantText
                                }
                            }

                            MaterialIconSymbol {
                                content: "chevron_right"
                                iconSize: 22
                                customColor: Colors.surfaceVariantText
                            }
                        }

                        RippleEffect {
                            anchors.fill: parent
                            radius: 24
                            onClicked: root.openSettings(parent)
                        }
                    }
                }
            }

            ScrollFade {
                anchors.fill: parent
                flickable: flick
                color: Colors.surface
            }

        }
    }

    Rectangle {
        id: qrSheet
        anchors.fill: parent
        anchors.margins: 8
        radius: 24
        color: Colors.surfaceContainer
        opacity: root.showQr ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { EffectsAnim {} }

        MouseArea {
            anchors.fill: parent
            onClicked: root.showQr = false
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 14

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 220
                Layout.preferredHeight: 220
                radius: 24
                color: "white"

                Image {
                    anchors.fill: parent
                    anchors.margins: 12
                    source: root.qrSource
                    visible: root.qrSource !== ""
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                    cache: false
                }

                CustomCircularLoader {
                    anchors.centerIn: parent
                    visible: root.qrSource === "" && !root.qrFailed
                    size: 28
                    trackWidth: 3
                    waveAmplitude: 0
                    highlightColor: "#1a1c1e"
                    trackColor: "#d0d0d0"
                }

                CustomText {
                    anchors.fill: parent
                    anchors.margins: 20
                    visible: root.qrFailed
                    content: "Couldn't make a code. Check that qrencode is installed and the password is saved."
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    size: 12
                    weight: 500
                    customColor: "#1a1c1e"
                }
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 300
                content: root.current?.name ?? ""
                family: root.displayFamily
                size: 20
                weight: 400
            }

            CustomText {
                Layout.alignment: Qt.AlignHCenter
                content: "Scan with a phone camera to join"
                size: 12
                weight: 400
                customColor: Colors.surfaceVariantText
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                implicitWidth: doneText.implicitWidth + 40
                implicitHeight: 40
                radius: 20
                color: Colors.primary

                CustomText {
                    id: doneText
                    anchors.centerIn: parent
                    content: "Done"
                    size: 14
                    weight: 600
                    customColor: Colors.primaryText
                }

                RippleEffect {
                    anchors.fill: parent
                    radius: parent.radius
                    hoverColor: Qt.alpha(Colors.primaryText, 0.08)
                    rippleColor: Qt.alpha(Colors.primaryText, 0.18)
                    onClicked: root.showQr = false
                }
            }
        }
    }
}
