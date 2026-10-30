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
    readonly property color plateColor: hov.containsMouse ? Colors.primaryContainer : Qt.alpha(Colors.primaryContainer, 0)
    readonly property bool plateless: BarLayout.chipHovers(root.itemId, root.implicitWidth, root.implicitHeight)
    readonly property bool plateOn: root.plateColor.a > 0.01
    readonly property real labelPx: BarLayout.scaleFor(root.iconPx, 18, 13, 8)
    readonly property real gapPx: BarLayout.scaleFor(root.iconPx, 18, 6, 3)
    readonly property real padPx: root.plate - root.iconPx
    readonly property bool showPercent: BarLayout.opt(root.itemId, "showPercent") !== false
    readonly property string style: BarLayout.opt(root.itemId, "style") ?? "icon"
    readonly property bool cookie: root.style === "cookie" || root.style === "fill" || root.style === "sweep"
    readonly property bool sweep: root.style === "sweep"
    readonly property bool filled: root.style === "fill" || BarLayout.opt(root.itemId, "meter") === "fill"
    readonly property bool bigCookie: root.cookie && !!root.host && root.host.split === true
    readonly property string shapeName: BarLayout.opt(root.itemId, "shape") ?? "sunny"
    readonly property string plateShape: root.bigCookie ? root.shapeName : ""
    readonly property real plateInset: root.bigCookie && !root.filled && !root.sweep ? sunCookie.ring : 0
    readonly property bool hoverPlate: !root.cookie
    property bool armed: false
    property real sunAngle: 0
    property real lastLevel: -1
    onLevelChanged: {
        if (root.armed && root.lastLevel >= 0 && root.level !== root.lastLevel) {
            root.sunAngle += (root.level - root.lastLevel) * 180
            sunSettle.restart()
        }
        root.lastLevel = root.level
    }
    Timer {
        id: sunSettle
        interval: 700
        onTriggered: root.sunAngle = Math.round(root.sunAngle / 90) * 90
    }
    Timer {
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }
    readonly property color plateTone: root.bigCookie ? (root.host.plateFill ?? Colors.surface) : Colors.surface

    readonly property var monitor: ServiceBrightness.getMonitorForScreen(layout.screen)
    readonly property real level: root.monitor?.brightness ?? 0
    readonly property bool shown: !!root.monitor
    readonly property bool onSide: !!root.host && root.host.vertical === true
    readonly property bool sideCompact: root.onSide && (!root.host.compactFor || root.host.compactFor(root.itemId))
    readonly property bool vertical: root.onSide
    readonly property bool sideNum: root.vertical && !root.sideCompact && root.showPercent && !root.cookie
    readonly property bool verticalReady: root.vertical

    implicitWidth: pill.width
    implicitHeight: pill.height

    Rectangle {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        width: root.bigCookie ? root.host.barH
            : root.vertical ? Math.max(root.plate, row.implicitWidth + 8)
            : root.showPercent && !root.cookie ? row.implicitWidth + root.padPx : root.plate
        height: root.bigCookie ? root.host.barH
            : root.sideNum ? row.implicitHeight + 8 : root.plate
        radius: Math.min(width, height) / 2
        color: root.plateless || root.cookie ? Qt.alpha(root.plateColor, 0) : root.plateColor
        Behavior on color { ColorAnimation { duration: 150 } }

        GridLayout {
            id: row
            anchors.centerIn: parent
            columns: root.vertical ? 1 : -1
            rowSpacing: 1
            columnSpacing: root.gapPx

            BarShapeMeter {
                id: sunCookie
                Layout.alignment: Qt.AlignHCenter
                visible: root.cookie
                Layout.preferredWidth: root.bigCookie ? BarLayout.plateH(root.itemId, root.host.barH) : Math.round(root.iconPx * 1.45)
                Layout.preferredHeight: Layout.preferredWidth
                value: root.level
                shape: root.shapeName
                thickness: BarLayout.opt(root.itemId, "thickness") ?? -1
                filled: root.filled
                sweep: root.sweep
                tone: BarLayout.roleColor(BarLayout.opt(root.itemId, "color") ?? "primary")
                onTone: BarLayout.onRoleColor(BarLayout.opt(root.itemId, "color") ?? "primary")
                angle: BarLayout.itemStyle(root.itemId, "rotate", 0)
                icon: "light_mode"
                iconAngle: root.sunAngle
                spins: true
                iconSize: BarLayout.itemStyle(root.itemId, "iconSize", 0)
                track: root.bigCookie ? "transparent" : Colors.surfaceContainerHighest
                ground: root.plateTone
                onPlate: root.bigCookie
            }

            MaterialIconSymbol {
                Layout.alignment: Qt.AlignHCenter
                visible: !root.cookie
                content: root.level > 0.66 ? "brightness_7" : root.level > 0.33 ? "brightness_6" : "brightness_5"
                iconSize: root.iconPx
                customColor: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                Behavior on customColor { ColorAnimation { duration: 150 } }
            }

            CustomText {
                visible: root.showPercent && !root.vertical && !root.cookie
                Layout.alignment: Qt.AlignHCenter
                content: Math.round(root.level * 100) + (root.vertical ? "" : "%")
                size: root.vertical ? root.labelPx - 2 : root.labelPx
                weight: 700
                customColor: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                Behavior on customColor { ColorAnimation { duration: 150 } }
            }

            BarSideNumber {
                visible: root.sideNum
                Layout.alignment: Qt.AlignHCenter
                value: Math.round(root.level * 100) + ""
                maxWidth: (root.host ? root.host.barH : 40) - 10
                ink: hov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                size: root.labelPx - 1
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
