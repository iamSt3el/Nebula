import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool iconSizable: true
    readonly property real box: BarLayout.boxFor(root.itemId, root.host)
    readonly property real iconPx: BarLayout.iconPxFor(root.itemId, root.box, 18)
    readonly property real plate: BarLayout.platePxFor(root.box, root.iconPx, 18, 26)
    readonly property color plateColor: hov.containsMouse ? Colors.primaryContainer : "transparent"
    readonly property bool plateless: BarLayout.chipHovers(root.itemId, root.implicitWidth, root.implicitHeight)
    readonly property bool plateOn: root.plateColor.a > 0.01
    readonly property real labelPx: BarLayout.scaleFor(root.iconPx, 18, 13, 8)
    readonly property real gapPx: BarLayout.scaleFor(root.iconPx, 18, 6, 3)
    readonly property real padPx: root.plate - root.iconPx
    readonly property bool showPercent: BarLayout.opt(root.itemId, "showPercent") !== false
    readonly property bool fill: BarLayout.opt(root.itemId, "style") === "fill"

    readonly property var monitor: ServiceBrightness.getMonitorForScreen(layout.screen)
    readonly property real level: root.monitor?.brightness ?? 0
    readonly property bool shown: !!root.monitor
    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property bool verticalReady: true

    implicitWidth: pill.width
    implicitHeight: pill.height

    Rectangle {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        width: root.fill ? fillChip.implicitWidth : root.vertical ? Math.max(root.plate, row.implicitWidth + 8)
            : root.showPercent ? row.implicitWidth + root.padPx : root.plate
        height: root.fill ? fillChip.implicitHeight : root.plate
        radius: Math.min(width, height) / 2
        color: root.plateless || root.fill ? "transparent" : root.plateColor
        Behavior on color { ColorAnimation { duration: 150 } }

        BarFillChip {
            id: fillChip
            anchors.fill: parent
            visible: root.fill
            value: root.level
            icon: "light_mode"
            label: Math.round(root.level * 100) + ""
            widthTemplate: "100"
            vertical: root.vertical
            iconPx: root.iconPx - 2
            chipHeight: root.plate
            hovered: hov.containsMouse
            fillColor: Colors.secondaryContainer
            fillInk: Colors.secondaryContainerText
        }

        GridLayout {
            id: row
            visible: !root.fill
            anchors.centerIn: parent
            columns: root.vertical ? 1 : -1
            rowSpacing: 1
            columnSpacing: root.gapPx

            MaterialIconSymbol {
                Layout.alignment: Qt.AlignHCenter
                content: root.level > 0.66 ? "brightness_7" : root.level > 0.33 ? "brightness_6" : "brightness_5"
                iconSize: root.iconPx
                customColor: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                Behavior on customColor { ColorAnimation { duration: 150 } }
            }

            CustomText {
                visible: root.showPercent && !root.vertical
                Layout.alignment: Qt.AlignHCenter
                content: Math.round(root.level * 100) + (root.vertical ? "" : "%")
                size: root.vertical ? root.labelPx - 2 : root.labelPx
                weight: 700
                customColor: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                Behavior on customColor { ColorAnimation { duration: 150 } }
            }
        }

        MouseArea {
            id: hov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.host) root.host.openPanel("brightness", root)
            onWheel: wheel => {
                const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                if (!root.monitor || !root.monitor.ready || d === 0)
                    return
                root.monitor.setBrightness(Math.max(0.01, Math.min(1, root.level + (d > 0 ? 0.05 : -0.05))))
            }
        }
    }
}
