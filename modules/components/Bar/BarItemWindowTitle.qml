import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true
    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property bool verticalReady: true
    readonly property bool flexible: !root.vertical
    readonly property bool tint: BarLayout.opt(root.itemId, "tint") === true
    readonly property real roundT: root.host && root.host.roundT !== undefined ? root.host.roundT : 0
    readonly property real fixedPart: root.tint ? 36 : 40
    readonly property bool appIcon: BarLayout.opt(root.itemId, "icon") !== "generic"
    readonly property string appId: ToplevelManager.activeToplevel ? (ToplevelManager.activeToplevel.appId ?? "") : ""
    readonly property string iconSrc: root.appIcon && root.appId !== "" && ServiceApps.list.length >= 0
        ? Quickshell.iconPath(DesktopEntries.heuristicLookup(root.appId)?.icon ?? "", true) : ""
    readonly property color ink: root.tint ? Colors.secondaryContainerText : Colors.surfaceText
    readonly property color subInk: root.tint ? Qt.alpha(Colors.secondaryContainerText, 0.75) : Colors.outline

    readonly property real setWidth: BarLayout.opt(root.itemId, "width") ?? 160
    readonly property bool fixed: root.setWidth > 0
    readonly property real target: root.fixed ? root.setWidth : 200
    readonly property real cap: root.host && root.host.maxWidth > 0
        ? Math.max(0, Math.min(root.target, root.host.maxWidth - root.host.fixedWidth - root.fixedPart))
        : root.target

    implicitWidth: root.vertical ? 32 : root.fixedPart + (titleBox.visible ? titleBox.width : 0) + (root.tint ? 12 : 0)
    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        visible: root.tint
        radius: height / 2
        color: Colors.secondaryContainer
    }

    Rectangle {
        x: root.vertical ? (parent.width - width) / 2 : root.tint ? 4 : 0
        anchors.verticalCenter: parent.verticalCenter
        width: root.tint ? 24 : 32
        height: width
        radius: root.tint ? 12 : 10 + (width / 2 - 10) * root.roundT
        color: root.tint ? Colors.surfaceContainerLowest : Colors.surfaceContainer

        IconImage {
            anchors.centerIn: parent
            visible: root.iconSrc !== ""
            implicitSize: root.tint ? 16 : 20
            source: root.iconSrc
        }

        MaterialIconSymbol {
            anchors.centerIn: parent
            visible: root.iconSrc === ""
            content: Hyprland.activeToplevel ? "web_asset" : "desktop_windows"
            iconSize: root.tint ? 15 : 18
            customColor: root.ink
        }
    }

    Item {
        id: titleBox
        x: root.fixedPart
        anchors.verticalCenter: parent.verticalCenter
        visible: root.cap > 4 && !root.vertical
        width: root.fixed ? root.cap : titleCol.implicitWidth
        height: titleCol.implicitHeight

        ColumnLayout {
            id: titleCol
            width: implicitWidth
            spacing: 0

            CustomText {
                visible: BarLayout.opt(root.itemId, "lines") !== "one"
                Layout.maximumWidth: root.cap
                content: ToplevelManager.activeToplevel
                         ? (ToplevelManager.activeToplevel.appId ?? "")
                         : "Desktop"
                size: 10
                weight: 700
                customColor: root.subInk
                elide: Text.ElideRight
            }
            CustomText {
                Layout.maximumWidth: root.cap
                content: ToplevelManager.activeToplevel
                         ? (ToplevelManager.activeToplevel.title ?? "")
                         : "Workspace " + (Hyprland.focusedMonitor?.activeWorkspace?.id ?? "")
                size: 12
                weight: 800
                customColor: root.ink
                elide: Text.ElideRight
            }
        }
    }
}
