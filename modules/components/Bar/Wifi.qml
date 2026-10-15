import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MatrialShapeFn

Item {
    id: root
    anchors.fill: parent

    signal backClicked
    property bool showBack: true

    property bool scanning: false
    property bool passwordPrompt: false
    property var pendingNetwork: null
    property string connectionError: ""

    property bool showQr: false
    property string qrSource: ""
    property bool qrFailed: false

    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property bool hardwareOn: Networking.wifiHardwareEnabled
    readonly property var current: root.wifiOn ? ServiceNetwork.connectedNetwork : null
    readonly property string displayFamily: SettingsConfig.general?.displayFont || "Titan One"

    function bucket(n) {
        return Math.min(3, Math.floor((n?.signalStrength ?? 0) * 4))
    }

    function ordered(list) {
        return list.slice().sort((a, b) => root.bucket(b) - root.bucket(a)
            || (a.name || "").localeCompare(b.name || ""))
    }

    readonly property var savedRows: root.ordered(ServiceNetwork.savedNetworks)
    readonly property var nearbyRows: root.ordered(ServiceNetwork.available.filter(n => (n.name ?? "") !== ""))
    readonly property var rows: root.wifiOn ? root.savedRows.concat(root.nearbyRows) : []
    readonly property int inRange: root.rows.length + (root.current ? 1 : 0)

    function strengthLabel(strength) {
        const v = (strength ?? 0) * 100
        if (v >= 75) return "Excellent"
        if (v >= 50) return "Good"
        if (v >= 25) return "Fair"
        return "Weak"
    }

    function securityLabel(security) {
        switch (security) {
        case WifiSecurityType.Wpa3SuiteB192:
        case WifiSecurityType.Sae: return "WPA3"
        case WifiSecurityType.Wpa2Psk:
        case WifiSecurityType.Wpa2Eap: return "WPA2"
        case WifiSecurityType.WpaPsk:
        case WifiSecurityType.WpaEap: return "WPA"
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep: return "WEP"
        case WifiSecurityType.Leap: return "LEAP"
        case WifiSecurityType.Owe: return "Enhanced open"
        case WifiSecurityType.Open: return "Open"
        }
        return ""
    }

    function isSecured(security) {
        if (security === undefined || security === null) return false
        return security !== WifiSecurityType.Open
            && security !== WifiSecurityType.Owe
            && security !== WifiSecurityType.Unknown
    }

    function askPassword(network) {
        root.pendingNetwork = network
        root.passwordPrompt = true
    }

    function submitPassword(psk) {
        if (root.pendingNetwork) root.pendingNetwork.connectWithPsk(psk)
        root.passwordPrompt = false
    }

    function dismissPassword() {
        root.passwordPrompt = false
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

    function openSettings() {
        root.backClicked()
        GlobalStates.settingsPage = 4
        GlobalStates.settingsOpen = true
    }

    function share() {
        if (!root.current) return
        root.qrSource = ""
        root.qrFailed = false
        root.showQr = true
        ServiceNetwork.generateQr(root.current.name, root.current.security)
    }

    property var downHist: []
    property var upHist: []
    readonly property int histLength: 30
    readonly property real peak: Math.max(1, ...root.downHist, ...root.upHist)

    function pushed(arr, v) {
        const copy = arr.slice()
        copy.push(v)
        if (copy.length > root.histLength) copy.shift()
        return copy
    }

    Component.onCompleted: {
        ServiceSystemInfo.retain()
        if (root.wifiOn) root.startScan()
    }
    Component.onDestruction: ServiceSystemInfo.release()

    Connections {
        target: ServiceSystemInfo
        function onNetSampled() {
            root.downHist = root.pushed(root.downHist, ServiceSystemInfo.netDownloadBps / 1024)
            root.upHist = root.pushed(root.upHist, ServiceSystemInfo.netUploadBps / 1024)
        }
    }

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
            network: root.pendingNetwork
            errorText: root.connectionError
            onSubmitted: psk => root.submitPassword(psk)
            onDismissed: root.dismissPassword()
        }
    }

    property bool freshOpen: true
    property var enteredRows: new Set()

    Timer {
        interval: 400
        running: true
        onTriggered: root.freshOpen = false
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

    component HeroButton: Rectangle {
        id: hb
        property string icon: ""
        property string label: ""
        property bool filled: false
        property string tip: ""
        signal clicked

        implicitHeight: 36
        implicitWidth: hbRow.implicitWidth + 28
        radius: height / 2
        color: hb.filled ? Colors.primaryContainerText : Qt.alpha(Colors.primaryContainerText, 0.12)

        RowLayout {
            id: hbRow
            anchors.centerIn: parent
            spacing: 6

            MaterialIconSymbol {
                content: hb.icon
                iconSize: 18
                customColor: hb.filled ? Colors.primaryContainer : Colors.primaryContainerText
            }

            CustomText {
                visible: hb.label !== ""
                content: hb.label
                size: 13
                weight: 600
                customColor: hb.filled ? Colors.primaryContainer : Colors.primaryContainerText
            }
        }

        RippleEffect {
            id: hbRipple
            anchors.fill: parent
            radius: parent.radius
            hoverColor: Qt.alpha(hb.filled ? Colors.primaryContainer : Colors.primaryContainerText, 0.08)
            rippleColor: Qt.alpha(hb.filled ? Colors.primaryContainer : Colors.primaryContainerText, 0.18)
            onClicked: hb.clicked()
        }

        CustomToolTip {
            content: hb.tip
            visible: hb.tip !== "" && hbRipple.containsMouse
        }
    }

    component SpeedTile: Rectangle {
        id: st
        property string icon: ""
        property real bps: 0
        property var values: []

        implicitHeight: 62
        radius: 14
        color: Qt.alpha(Colors.primaryContainerText, 0.12)

        RowLayout {
            x: 10
            y: 8
            spacing: 4

            MaterialIconSymbol {
                content: st.icon
                iconSize: 16
                customColor: Colors.primaryContainerText
            }

            CustomText {
                content: ServiceSystemInfo.formatNetSpeed(st.bps)
                size: 12
                weight: 600
                customColor: Colors.primaryContainerText
            }
        }

        CustomSparkline {
            x: 10
            width: parent.width - 20
            y: 32
            height: 22
            values: st.values
            maxPoints: root.histLength
            maxOverride: root.peak
            lineColor: Colors.primaryContainerText
            lineWidth: 2
            logScale: true
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            spacing: 10

            M3IconButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                icon: "chevron_backward"
                iconSize: 20
                visible: root.showBack
                onClicked: root.backClicked()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                CustomText {
                    Layout.fillWidth: true
                    content: "Wi-Fi"
                    family: root.displayFamily
                    renderType: Text.QtRendering
                    size: 22
                    weight: 400
                }

                CustomText {
                    Layout.fillWidth: true
                    content: !root.hardwareOn ? "Blocked by the hardware switch"
                        : !root.wifiOn ? "Off"
                        : root.scanning ? "Scanning…"
                        : root.inRange === 1 ? "1 network in range"
                        : root.inRange + " networks in range"
                    size: 12
                    weight: 400
                    customColor: Colors.surfaceVariantText
                }
            }

            Item {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40

                M3IconButton {
                    anchors.fill: parent
                    icon: "refresh"
                    iconSize: 20
                    enabledButton: root.wifiOn && !root.scanning
                    opacity: root.scanning ? 0 : root.wifiOn ? 1 : 0.4
                    onClicked: if (root.wifiOn && !root.scanning) root.startScan()
                    Behavior on opacity { EffectsAnim {} }
                }

                CustomCircularLoader {
                    anchors.centerIn: parent
                    size: 22
                    trackWidth: 2
                    waveAmplitude: 0
                    highlightColor: Colors.primary
                    trackColor: Colors.surfaceContainerHighest
                    visible: root.scanning
                }
            }

            CustomToogle {
                Layout.alignment: Qt.AlignVCenter
                isToggleOn: Networking.wifiEnabled
                opacity: root.hardwareOn ? 1 : 0.4
                onToggled: function (state) {
                    if (!root.hardwareOn) return
                    Networking.wifiEnabled = state
                }
            }
        }

        Rectangle {
            id: hero
            Layout.fillWidth: true
            Layout.preferredHeight: heroCol.implicitHeight + 32
            visible: root.current !== null
            radius: 24
            color: Colors.primaryContainer

            ColumnLayout {
                id: heroCol
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Item {
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64

                        MaterialShapes.ShapeCanvas {
                            anchors.fill: parent
                            roundedPolygon: MatrialShapeFn.getCookie9Sided()
                            color: Colors.primary
                        }

                        WifiGlyph {
                            anchors.centerIn: parent
                            size: 30
                            strength: root.current?.signalStrength ?? 0
                            color: Colors.primaryText
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        CustomText {
                            Layout.fillWidth: true
                            content: root.current?.name ?? ""
                            family: root.displayFamily
                            renderType: Text.QtRendering
                            size: 24
                            weight: 400
                            customColor: Colors.primaryContainerText
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                visible: secLabel.text !== ""
                                implicitWidth: secLabel.implicitWidth + 16
                                implicitHeight: 20
                                radius: 8
                                color: Colors.primary

                                CustomText {
                                    id: secLabel
                                    anchors.centerIn: parent
                                    content: root.securityLabel(root.current?.security)
                                    size: 12
                                    weight: 600
                                    customColor: Colors.primaryText
                                }
                            }

                            CustomText {
                                Layout.fillWidth: true
                                content: Math.round((root.current?.signalStrength ?? 0) * 100) + "% signal, "
                                    + root.strengthLabel(root.current?.signalStrength).toLowerCase()
                                size: 12
                                weight: 500
                                customColor: Colors.primaryContainerText
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SpeedTile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        icon: "arrow_downward"
                        bps: ServiceSystemInfo.netDownloadBps
                        values: root.downHist
                    }

                    SpeedTile {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        icon: "arrow_upward"
                        bps: ServiceSystemInfo.netUploadBps
                        values: root.upHist
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    HeroButton {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        filled: true
                        icon: "qr_code_2"
                        label: "Share"
                        onClicked: root.share()
                    }

                    HeroButton {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        icon: "settings"
                        label: "Settings"
                        onClicked: root.openSettings()
                    }

                    HeroButton {
                        Layout.preferredWidth: 44
                        icon: "link_off"
                        tip: "Disconnect"
                        onClicked: root.current?.disconnect()
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            visible: root.current === null
            radius: 24
            color: Colors.surfaceContainerHigh

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                Item {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48

                    MaterialShapes.ShapeCanvas {
                        anchors.fill: parent
                        roundedPolygon: MatrialShapeFn.getCookie9Sided()
                        color: Colors.surfaceContainerHighest
                    }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: !root.wifiOn ? "wifi_off"
                            : ServiceNetwork.connectionType === "ethernet" ? "lan"
                            : "wifi_find"
                        iconSize: 22
                        customColor: Colors.surfaceVariantText
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    CustomText {
                        Layout.fillWidth: true
                        content: !root.hardwareOn ? "Wi-Fi is blocked"
                            : !root.wifiOn ? "Wi-Fi is off"
                            : ServiceNetwork.connectionType === "ethernet" ? "On Ethernet"
                            : "Not connected"
                        size: 15
                        weight: 600
                    }

                    CustomText {
                        Layout.fillWidth: true
                        content: !root.hardwareOn ? "Turn off the hardware switch or airplane mode"
                            : !root.wifiOn ? "Turn it on to see networks"
                            : ServiceNetwork.connectionType === "ethernet" ? ServiceNetwork.activeInterface
                            : "Pick a network below"
                        size: 12
                        weight: 400
                        customColor: Colors.surfaceVariantText
                    }
                }

                M3IconButton {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    icon: "settings"
                    iconSize: 20
                    onClicked: root.openSettings()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                anchors.centerIn: parent
                visible: root.rows.length === 0
                spacing: 10

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 52
                    implicitHeight: 52

                    MaterialShapes.ShapeCanvas {
                        anchors.fill: parent
                        roundedPolygon: MatrialShapeFn.getSunny()
                        color: Colors.surfaceContainerHigh
                    }

                    MaterialIconSymbol {
                        anchors.centerIn: parent
                        content: root.wifiOn ? "wifi_find" : "wifi_off"
                        iconSize: 22
                        customColor: Colors.outline
                    }
                }

                CustomText {
                    Layout.alignment: Qt.AlignHCenter
                    content: !root.wifiOn ? "Networks show up when Wi-Fi is on"
                        : root.scanning ? "Looking for networks…"
                        : "No other networks found"
                    size: 12
                    weight: 400
                    customColor: Colors.outline
                }
            }

            ListView {
                id: list
                anchors.fill: parent
                visible: root.rows.length > 0
                model: ScriptModel { values: root.rows }
                spacing: 3
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: CustomScrollBar {}
                delegate: rowComponent
                displaced: Transition { SpatialAnim { properties: "y"; speed: "fast" } }
                move: Transition { SpatialAnim { properties: "y"; speed: "fast" } }
            }

            ScrollFade {
                anchors.fill: parent
                visible: list.visible
                flickable: list
                color: Colors.surface
            }
        }
    }

    Component {
        id: rowComponent

        Item {
            id: netItem

            required property var modelData
            required property int index

            readonly property bool saved: netItem.index < root.savedRows.length
            readonly property bool first: netItem.saved ? netItem.index === 0 : netItem.index === root.savedRows.length
            readonly property bool last: netItem.saved ? netItem.index === root.savedRows.length - 1
                : netItem.index === root.rows.length - 1
            readonly property bool isBusy: netItem.modelData?.state === ConnectionState.Connecting
                || netItem.modelData?.state === ConnectionState.Disconnecting
            readonly property bool secured: root.isSecured(netItem.modelData?.security)

            property real lift: 0

            width: ListView.view ? ListView.view.width : 0
            implicitHeight: (netItem.first ? header.height : 0) + 56
            transform: Translate { y: netItem.lift }

            Component.onCompleted: {
                if (root.enteredRows.has(netItem.modelData)) return
                root.enteredRows.add(netItem.modelData)
                entrance.delay = root.freshOpen ? Math.min(netItem.index, 6) * 30 : 0
                opacity = 0
                lift = 14
                entrance.start()
            }

            SequentialAnimation {
                id: entrance
                property int delay: 0
                PauseAnimation { duration: entrance.delay }
                ParallelAnimation {
                    EffectsAnim { target: netItem; property: "opacity"; to: 1 }
                    SpatialAnim { target: netItem; property: "lift"; to: 0; speed: "fast" }
                }
            }

            Connections {
                target: netItem.modelData
                ignoreUnknownSignals: true
                function onConnectionFailed(reason) {
                    root.handleFailure(netItem.modelData, reason)
                }
                function onConnectedChanged() {
                    if (netItem.modelData?.connected) {
                        root.connectionError = ""
                        if (root.pendingNetwork === netItem.modelData) root.passwordPrompt = false
                    }
                }
            }

            Item {
                id: header
                visible: netItem.first
                width: parent.width
                height: netItem.index === 0 ? 26 : 40

                CustomText {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    content: netItem.saved ? "Saved" : "Nearby"
                    size: 13
                    weight: 600
                    customColor: Colors.primary
                }
            }

            Rectangle {
                id: netRow
                y: netItem.first ? header.height : 0
                width: parent.width
                height: 56
                topLeftRadius: netItem.first ? 18 : 4
                topRightRadius: netItem.first ? 18 : 4
                bottomLeftRadius: netItem.last ? 18 : 4
                bottomRightRadius: netItem.last ? 18 : 4
                color: netRipple.containsMouse ? Colors.surfaceContainerHighest
                    : netItem.saved ? Colors.surfaceContainerHigh : Colors.surfaceContainer

                Behavior on color { EffectsColorAnim {} }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 14
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 18
                        color: netItem.saved ? Colors.secondaryContainer : Colors.surfaceContainerHigh

                        WifiGlyph {
                            anchors.centerIn: parent
                            size: 22
                            strength: netItem.modelData?.signalStrength ?? 0
                            color: netItem.saved ? Colors.secondaryContainerText : Colors.surfaceVariantText
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        CustomText {
                            Layout.fillWidth: true
                            content: netItem.modelData?.name ?? ""
                            size: 14
                            weight: 600
                        }

                        CustomText {
                            Layout.fillWidth: true
                            content: {
                                const n = netItem.modelData
                                if (n?.state === ConnectionState.Connecting) return "Connecting…"
                                if (n?.state === ConnectionState.Disconnecting) return "Disconnecting…"
                                const strength = root.strengthLabel(n?.signalStrength)
                                if (netItem.saved) return "Saved, " + strength.toLowerCase() + " signal"
                                if (!netItem.secured) return "Open network"
                                return root.securityLabel(n?.security) || strength
                            }
                            size: 12
                            weight: 400
                            customColor: Colors.surfaceVariantText
                        }
                    }

                    Item {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20

                        MaterialIconSymbol {
                            anchors.centerIn: parent
                            visible: !netItem.isBusy
                            content: netItem.secured ? "lock" : "lock_open"
                            iconSize: 18
                            fill: 1
                            customColor: netItem.secured ? Colors.outline : Colors.tertiary
                        }

                        CustomCircularLoader {
                            anchors.centerIn: parent
                            visible: netItem.isBusy
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
                    topLeftRadius: netRow.topLeftRadius
                    topRightRadius: netRow.topRightRadius
                    bottomLeftRadius: netRow.bottomLeftRadius
                    bottomRightRadius: netRow.bottomRightRadius
                    onClicked: {
                        if (netItem.isBusy) return
                        root.activate(netItem.modelData)
                    }
                }
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
                renderType: Text.QtRendering
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
