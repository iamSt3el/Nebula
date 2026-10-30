import QtQuick
import Quickshell.Services.UPower
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true
    readonly property bool iconSizable: true
    readonly property real box: BarLayout.boxFor(root.itemId, root.host)
    readonly property real iconPx: BarLayout.iconPxFor(root.itemId, root.box, 18)
    readonly property real plate: BarLayout.platePxFor(root.box, root.iconPx, 18, 28)
    readonly property color plateColor: hov.containsMouse ? Colors.primaryContainer
         : root.low ? Qt.alpha(Colors.error, 0.15) : Qt.alpha(Colors.primaryContainer, 0)
    readonly property bool plateless: BarLayout.chipHovers(root.itemId, root.implicitWidth,
                                                           root.implicitHeight)
    readonly property bool plateOn: root.plateColor.a > 0.01
    readonly property real labelPx: BarLayout.scaleFor(root.iconPx, 18, 13, 8)
    readonly property real gapPx: BarLayout.scaleFor(root.iconPx, 18, 4, 2)
    readonly property real padPx: root.plate - root.iconPx
    readonly property bool low: ServiceUPower.powerLevel < 0.2 && !ServiceUPower.isCharging
    readonly property string style: BarLayout.opt(root.itemId, "style") ?? "icon"
    readonly property bool shaped: root.style === "fill" || root.style === "shape" || root.style === "sweep"
    readonly property bool showPercent: BarLayout.opt(root.itemId, "showPercent") === true
        && root.style !== "pill" && !root.shaped
    readonly property bool glyph: ["cell", "pill", "ring", "tall", "bars"].indexOf(root.style) >= 0
    readonly property bool bigCookie: root.shaped && !!root.host && root.host.split === true
    readonly property string plateShape: root.bigCookie ? (BarLayout.opt(root.itemId, "shape") ?? "cookie9") : ""
    readonly property bool hoverPlate: !root.shaped
    readonly property real plateInset: root.bigCookie && root.style === "shape" ? battMeter.ring : 0
    readonly property color plateTone: root.bigCookie ? (root.host.plateFill ?? Colors.surface) : Colors.surface
    readonly property string iconName: {
        if (ServiceUPower.isCharging) return "battery_android_bolt"
        const l = ServiceUPower.powerLevel
        if (l === 1)  return "battery_android_full"
        if (l > 0.9)  return "battery_android_6"
        if (l > 0.7)  return "battery_android_5"
        if (l > 0.5)  return "battery_android_4"
        if (l > 0.3)  return "battery_android_3"
        if (l > 0.2)  return "battery_android_2"
        if (l > 0.0)  return "battery_android_1"
        return "battery_android_0"
    }
    readonly property real glyphSize: {
        const s = root.style === "pill" ? Math.round(root.iconPx * 1.45) : Math.round(root.iconPx * 1.3)
        if (root.style === "pill" && root.onSide && root.host)
            return Math.min(s, Math.floor((root.host.barH - 6) / 1.5))
        return s
    }
    readonly property bool onSide: !!root.host && root.host.vertical === true
    readonly property bool sideCompact: root.onSide && (!root.host.compactFor || root.host.compactFor(root.itemId))
    readonly property bool vertical: root.onSide
    readonly property bool sideNum: root.vertical && !root.sideCompact && root.showPercent
    readonly property bool verticalReady: root.vertical
    readonly property bool critical: ServiceUPower.powerLevel > 0 && ServiceUPower.powerLevel <= 0.15 && !ServiceUPower.isCharging

    onCriticalChanged: if (!root.critical) root.opacity = 1

    SequentialAnimation on opacity {
        running: root.critical
        loops: Animation.Infinite
        NumberAnimation { to: 0.4; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
    }
    readonly property color ink: hov.containsMouse ? Colors.primaryContainerText
                               : root.low ? Colors.error : Colors.surfaceText

    implicitWidth: root.bigCookie ? root.host.barH
        : root.vertical ? Math.max(root.plate, battRow.implicitWidth + 8)
        : root.showPercent || (root.glyph && glyphItem.implicitWidth > root.plate - 4) ? battRow.implicitWidth + root.padPx : root.plate
    implicitHeight: root.bigCookie ? root.host.barH
        : root.sideNum ? battRow.implicitHeight + 8 : root.plate
    radius: Math.min(width, height) / 2
    color: root.plateless || root.shaped ? Qt.alpha(root.plateColor, 0) : root.plateColor
    Behavior on color { ColorAnimation { duration: 150 } }

    Grid {
        id: battRow
        anchors.centerIn: parent
        spacing: root.vertical ? 1 : root.gapPx
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        BarShapeMeter {
            id: battMeter
            visible: root.shaped
            width: root.bigCookie ? BarLayout.plateH(root.itemId, root.host.barH) : Math.round(root.iconPx * 1.45)
            height: width
            value: ServiceUPower.powerLevel
            shape: BarLayout.opt(root.itemId, "shape") ?? "cookie9"
            thickness: BarLayout.opt(root.itemId, "thickness") ?? -1
            filled: root.style === "fill"
            sweep: root.style === "sweep"
            angle: BarLayout.itemStyle(root.itemId, "rotate", 0)
            icon: root.iconName
            iconSize: BarLayout.itemStyle(root.itemId, "iconSize", 0)
            tone: root.low ? Colors.error : BarLayout.roleColor(BarLayout.opt(root.itemId, "color") ?? "primary")
            onTone: root.low ? Colors.errorText : BarLayout.onRoleColor(BarLayout.opt(root.itemId, "color") ?? "primary")
            track: root.bigCookie ? "transparent" : Colors.surfaceContainerHighest
            ground: root.plateTone
            onPlate: root.bigCookie
        }

        BatteryGlyph {
            id: glyphItem
            visible: root.glyph
            kind: root.glyph ? root.style : "cell"
            size: root.glyphSize
            level: ServiceUPower.powerLevel
            charging: ServiceUPower.isCharging
            plugged: !ServiceUPower.isCharging && !UPower.onBattery && UPower.displayDevice.isPresent
            saver: ServiceUPower.powerProfile === 0
            missing: !UPower.displayDevice.isPresent
            showNumber: root.style === "pill"
            mono: hov.containsMouse
            ink: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
            ground: root.plateOn ? Qt.tint(Colors.surface, root.plateColor) : Colors.surface
        }

        MaterialIconSymbol {
            visible: !root.glyph && !root.shaped
            content: root.iconName
            iconSize: root.iconPx
            customColor: root.ink
        }

        CustomText {
            visible: root.showPercent && !root.vertical
            content: Math.round(ServiceUPower.powerLevel * 100) + (root.vertical ? "" : "%")
            size: root.vertical ? root.labelPx - 2 : root.labelPx
            weight: 700
            customColor: root.ink
        }

        BarSideNumber {
            visible: root.sideNum
            value: Math.round(ServiceUPower.powerLevel * 100) + ""
            maxWidth: (root.host ? root.host.barH : 40) - 10
            ink: root.ink
            size: root.labelPx - 1
        }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.host) root.host.openPanel("battery", root)
    }

    CustomToolTip {
        content: (ServiceUPower.isCharging ? "Charging · " : "")
               + Math.round(ServiceUPower.powerLevel * 100) + "%"
        detail: ServiceUPower.isCharging && ServiceUPower.timeToFull !== "0m" ? "Full in " + ServiceUPower.timeToFull : ""
        visible: hov.containsMouse && !(root.host && root.host.panelKind === "battery")
    }
}
