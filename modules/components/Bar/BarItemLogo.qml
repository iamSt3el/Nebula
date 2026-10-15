import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import qs.modules.components.LockScreen

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true

    readonly property string look: BarLayout.opt(root.itemId, "look") ?? "chip"
    readonly property real size: BarLayout.opt(root.itemId, "size") ?? 20
    readonly property string role: BarLayout.opt(root.itemId, "role") ?? "primary"
    readonly property string action: {
        const a = BarLayout.opt(root.itemId, "action") ?? "launcher"
        return a === "dashboard" ? "launcher" : a
    }
    readonly property bool clickable: root.action !== "none"
    readonly property bool hot: area.containsMouse && root.clickable
    readonly property color tone: BarLayout.roleColor(root.role)
    readonly property color onTone: {
        switch (root.role) {
        case "secondary":   return Colors.secondaryText
        case "tertiary":    return Colors.tertiaryText
        case "outline":
        case "surfaceText": return Colors.surface
        }
        return Colors.primaryText
    }

    readonly property real box: root.look === "plain" ? root.size + 6 : root.size + 12
    readonly property bool active: {
        switch (root.action) {
        case "power":     return !!root.host && root.host.panelKind === "power"
        case "launcher":  return GlobalStates.appLauncherOpen
        case "overview":  return GlobalStates.overviewOpen
        case "settings":  return GlobalStates.settingsOpen
        }
        return false
    }

    implicitWidth: root.box
    implicitHeight: root.box

    function trigger() {
        switch (root.action) {
        case "power":
            if (root.host) root.host.openPanel("power", root)
            break
        case "launcher":
            GlobalStates.appLauncherOpen = !GlobalStates.appLauncherOpen
            break
        case "overview":
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen
            break
        case "settings":
            GlobalStates.settingsOpen = !GlobalStates.settingsOpen
            break
        case "pie":
            GlobalStates.pieRequested()
            break
        }
    }

    Rectangle {
        anchors.centerIn: parent
        visible: root.look !== "plain" && root.look !== "avatar"
        width: root.box
        height: root.box
        radius: root.hot || root.active ? root.box * 0.32 : root.box / 2
        color: root.look === "filled" ? (root.hot ? Qt.lighter(root.tone, 1.08) : root.tone)
             : root.look === "chip" ? Qt.alpha(root.tone, root.hot || root.active ? 0.28 : 0.16)
             : "transparent"
        border.width: root.look === "ring" ? 1.5 : 0
        border.color: Qt.alpha(root.tone, root.hot || root.active ? 0.9 : 0.55)
        Behavior on radius { SpatialAnim { speed: "fast" } }
        Behavior on color { EffectsColorAnim { speed: "fast" } }
    }

    LockShapeImage {
        anchors.centerIn: parent
        visible: root.look === "avatar"
        width: root.box
        height: root.box
        source: root.look === "avatar" ? (SettingsConfig.general.profile ?? "") : ""
        shapeName: "circle"
        sourceSize: 96
    }

    NebulaLogo {
        anchors.centerIn: parent
        visible: root.look !== "avatar"
        width: root.size
        height: root.size
        color: root.look === "filled" ? root.onTone : root.tone
        rotation: root.hot ? -8 : 0
        Behavior on rotation { SpatialAnim { speed: "fast" } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.trigger()
    }

    CustomToolTip {
        content: {
            switch (root.action) {
            case "power":     return "Power menu"
            case "launcher":  return "Apps"
            case "overview":  return "Overview"
            case "settings":  return "Nebula settings"
            case "pie":       return "Quick actions"
            }
            return "Nebula"
        }
        visible: area.containsMouse && root.clickable
    }
}
