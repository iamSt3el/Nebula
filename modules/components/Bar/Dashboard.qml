import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.services
import qs.modules.settings
import qs.modules.components.Bar.DashboardSections
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/material-shapes.js" as MatrialShapeFn

Item{
    id: root
    anchors.fill: parent

    Component.onCompleted: ServiceSystemInfo.retain()
    Component.onDestruction: ServiceSystemInfo.release()
    implicitHeight: col.implicitHeight
    property string panelMode: ""   // "" | "wifi" | "bluetooth"
    property bool   compact:   false

    property var parentPos
    property var wifiPos
    property var bluetoothPos
    property var pos


    readonly property bool isPill: SettingsConfig.general.barMode === "pill"

    opacity: 0
    scale: root.isPill ? 1 : 0.8

    NumberAnimation on opacity {
        from: 0; to: 1; duration: 400; running: true
    }

    NumberAnimation on scale {
        from: root.isPill ? 1 : 0.8
        to: 1
        duration: 400
        running: true
    }


    Connections {
        target: ServiceNetwork
        function onWifiEnabledChanged() {
            SettingsConfig.toggles = Object.assign({}, SettingsConfig.toggles, { airplaneMode: !ServiceNetwork.wifiEnabled })
        }
    }

    Connections {
        target: ServicePipewire
        function onMutedChanged() {
            SettingsConfig.toggles = Object.assign({}, SettingsConfig.toggles, { speakerMuted: ServicePipewire.muted })
        }
        function onMicMutedChanged() {
            SettingsConfig.toggles = Object.assign({}, SettingsConfig.toggles, { micMuted: ServicePipewire.micMuted })
        }
    }




    // Overlay backdrop — fades in/out independently
    Rectangle {
        id: overlayBackdrop
        anchors.fill: parent
        z: 1
        radius: 20
        color: Qt.alpha(Colors.surface, 0.7)
        opacity: root.panelMode !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    // Panel container — persistent so states/transitions actually animate
    Rectangle {
        id: container
        z: 2
        enabled: root.panelMode !== ""

        // Default (closed) position — tracks the tile that was last clicked
        x: root.pos ? root.pos.x : 0
        y: root.pos ? root.pos.y : 0
        // Closed size matches the controls section it grows out of
        width: (root.controlsItem?.width ?? 300)
        height: 60
        opacity: 0

        color: Colors.surfaceContainerHigh
        radius: 20
        clip: true

        states: [
            State {
                name: "wifi"
                when: root.panelMode === "wifi"
                PropertyChanges {
                    target: container
                    x: root.parentPos ? root.parentPos.x : 0
                    y: root.parentPos ? root.parentPos.y : 0
                    width: (root.controlsItem?.width ?? 300)
                    height: (root.controlsItem?.height ?? 60) + 400
                    opacity: 1
                }
            },
            State {
                name: "bluetooth"
                when: root.panelMode === "bluetooth"
                PropertyChanges {
                    target: container
                    x: root.parentPos ? root.parentPos.x : 0
                    y: root.parentPos ? root.parentPos.y : 0
                    width: (root.controlsItem?.width ?? 300)
                    height: (root.controlsItem?.height ?? 60) + 400
                    opacity: 1
                }
            }
        ]

        transitions: Transition {
            NumberAnimation {
                properties: "x,y,width,height,opacity"
                duration: 300
                easing.type: Easing.InOutCirc
            }
        }

        // Show content after open animation completes
        Timer {
            id: contentTimer
            interval: 300
            onTriggered: panelLoader.active = true
        }

        Connections {
            target: root
            function onPanelModeChanged() {
                panelLoader.active = false
                if (root.panelMode !== "") contentTimer.start()
            }
        }

        Loader {
            id: panelLoader
            active: false
            anchors.fill: parent
            visible: active
            sourceComponent: root.panelMode === "wifi" ? wifiComponent : bluetoothComponent
        }

        Component {
            id: wifiComponent
            Wifi {
                onBackClicked: {
                    root.panelMode = ""
                    panelLoader.active = false
                }
            }
        }

        Component {
            id: bluetoothComponent
            Bluetooth {
                onBackClicked: {
                    root.panelMode = ""
                    panelLoader.active = false
                }
            }
        }
    }

    NumberAnimation on opacity{
        from: 0
        to: 1
        duration: 200
        running: true
    }


    signal toggleDashboard
    property bool active: false//hoverHandler.hovered

    onActiveChanged:{
        if(!active) root.toggleDashboard()
    }


    // HoverHandler{
    //     id: hoverHandler
    // }

    // ── Sections ──────────────────────────────────────────────────────────
    // Order and visibility both come from SettingsConfig.dashboard. Sections
    // report their size through implicitHeight rather than Layout attachments,
    // because a Loader can pass a size up but not a Layout attached property.
    readonly property var defaultOrder: [
        "profile", "controls", "quickActions", "music",
        "calendar", "cpu", "gpu", "memory", "network"
    ]

    readonly property var sectionOrder: {
        const saved = SettingsConfig.dashboard?.order
        if (!Array.isArray(saved) || saved.length === 0) return root.defaultOrder
        // Tolerate a stale saved order: drop keys that no longer exist and
        // append any section added since it was written.
        const known = saved.filter(k => root.defaultOrder.indexOf(k) !== -1)
        const missing = root.defaultOrder.filter(k => known.indexOf(k) === -1)
        return known.concat(missing)
    }

    function shows(key) {
        if (!(SettingsConfig.dashboard?.[key] ?? true)) return false
        // The network graph needs more height than the pill dashboard has
        if (key === "network" && root.compact) return false
        return true
    }

    // The wifi/bluetooth overlay sizes itself from the controls section, so the
    // driver has to hand back a reference the Loader would otherwise hide.
    property Item controlsItem: null

    Component { id: cProfile
        DashProfile { compact: root.compact; onToggleDashboard: root.toggleDashboard() } }

    Component { id: cControls
        DashControls {
            compact: root.compact
            coordSpace: root
            panelMode: root.panelMode
            Component.onCompleted: root.controlsItem = this
            Component.onDestruction: if (root.controlsItem === this) root.controlsItem = null
            onOpenPanel: function(mode, pPos, p) {
                root.parentPos = pPos
                root.pos = p
                root.panelMode = mode
            }
        } }

    Component { id: cQuickActions; DashQuickActions { compact: root.compact } }
    Component { id: cMusic;        DashMusic        { compact: root.compact } }
    Component { id: cCalendar;     DashCalendar     { compact: root.compact } }
    Component { id: cCpu;          DashCpu          { compact: root.compact } }
    Component { id: cGpu;          DashGpu          { compact: root.compact } }
    Component { id: cMemory;       DashMemory       { compact: root.compact } }
    Component { id: cNetwork;      DashNetwork      { compact: root.compact } }

    function componentFor(key) {
        switch (key) {
            case "profile":      return cProfile
            case "controls":     return cControls
            case "quickActions": return cQuickActions
            case "music":        return cMusic
            case "calendar":     return cCalendar
            case "cpu":          return cCpu
            case "gpu":          return cGpu
            case "memory":       return cMemory
            case "network":      return cNetwork
        }
        return null
    }

    ColumnLayout{
        id: col
        anchors.fill: parent
        spacing:         root.compact ? 7 : 10
        anchors.margins: root.compact ? 7 : 10

        Repeater {
            model: root.sectionOrder

            delegate: Loader {
                required property string modelData

                active:  root.shows(modelData)
                visible: active          // an inactive Loader still takes space
                Layout.fillWidth: true
                Layout.preferredHeight: item ? item.implicitHeight : 0
                sourceComponent: root.componentFor(modelData)
            }
        }

    }

    // What the panel has to be to fit the sections exactly: the layout's own
    // content height plus the margins it sits inside. Containers read this
    // rather than measuring col themselves.
    readonly property real contentHeight: col.implicitHeight + 2 * col.anchors.margins
}
