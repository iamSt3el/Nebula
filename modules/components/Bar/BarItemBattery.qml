import QtQuick
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
         : root.low ? Qt.alpha(Colors.error, 0.15) : "transparent"
    readonly property bool plateless: BarLayout.chipHovers(root.itemId, root.implicitWidth,
                                                           root.implicitHeight)
    readonly property bool plateOn: root.plateColor.a > 0.01
    readonly property real labelPx: BarLayout.scaleFor(root.iconPx, 18, 13, 8)
    readonly property real gapPx: BarLayout.scaleFor(root.iconPx, 18, 4, 2)
    readonly property real padPx: root.plate - root.iconPx
    readonly property bool low: ServiceUPower.powerLevel < 0.2 && !ServiceUPower.isCharging
    readonly property bool showPercent: BarLayout.opt(root.itemId, "showPercent") === true
    readonly property bool fill: BarLayout.opt(root.itemId, "style") === "fill"
    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property bool verticalReady: true
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

    implicitWidth: root.fill ? fillChip.implicitWidth : root.vertical ? Math.max(root.plate, battRow.implicitWidth + 8)
        : root.showPercent ? battRow.implicitWidth + root.padPx : root.plate
    implicitHeight: root.fill ? fillChip.implicitHeight : root.plate
    radius: Math.min(width, height) / 2
    color: root.plateless || root.fill ? "transparent" : root.plateColor
    Behavior on color { ColorAnimation { duration: 150 } }

    BarFillChip {
        id: fillChip
        anchors.fill: parent
        visible: root.fill
        value: ServiceUPower.powerLevel
        icon: ServiceUPower.isCharging ? "bolt" : root.low ? "battery_alert" : "battery_android_full"
        label: Math.round(ServiceUPower.powerLevel * 100) + "%"
        vertical: root.vertical
        iconPx: root.iconPx - 2
        chipHeight: root.plate
        hovered: hov.containsMouse
        trackColor: root.low ? Colors.errorContainer : Colors.surfaceContainerHigh
        fillColor: root.low ? Colors.error : Colors.primaryContainer
        ink: root.low ? Colors.errorContainerText : Colors.surfaceText
        fillInk: root.low ? Colors.errorText : Colors.primaryContainerText
    }

    Grid {
        id: battRow
        visible: !root.fill
        anchors.centerIn: parent
        spacing: root.vertical ? 1 : root.gapPx
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        MaterialIconSymbol {
            content: {
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
