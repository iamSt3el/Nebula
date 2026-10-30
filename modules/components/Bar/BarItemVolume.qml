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
    readonly property bool iconSizable: true
    readonly property real box: BarLayout.boxFor(root.itemId, root.host)
    readonly property real iconPx: BarLayout.iconPxFor(root.itemId, root.box, 18)
    readonly property real plate: BarLayout.platePxFor(root.box, root.iconPx, 18, 26)
    readonly property color plateColor: volHov.containsMouse ? Colors.primaryContainer : Qt.alpha(Colors.primaryContainer, 0)
    readonly property bool plateless: BarLayout.chipHovers(root.itemId, root.implicitWidth,
                                                           root.implicitHeight)
    readonly property bool plateOn: root.plateColor.a > 0.01
    readonly property real labelPx: BarLayout.scaleFor(root.iconPx, 18, 13, 8)
    readonly property real gapPx: BarLayout.scaleFor(root.iconPx, 18, 6, 3)
    readonly property real padPx: root.plate - root.iconPx
    readonly property string style: BarLayout.opt(root.itemId, "style") ?? "icon"
    readonly property bool cookie: root.style === "cookie" || root.style === "fill" || root.style === "sweep"
    readonly property bool sweep: root.style === "sweep"
    readonly property bool filled: root.style === "fill" || BarLayout.opt(root.itemId, "meter") === "fill"
    readonly property bool bigCookie: root.cookie && !!root.host && root.host.split === true
    readonly property string shapeName: BarLayout.opt(root.itemId, "shape") ?? "cookie9"
    readonly property string plateShape: root.bigCookie ? root.shapeName : ""
    readonly property real plateInset: root.bigCookie && !root.filled && !root.sweep ? volCookie.ring : 0
    readonly property bool hoverPlate: !root.cookie
    readonly property color plateTone: root.bigCookie ? (root.host.plateFill ?? Colors.surface) : Colors.surface
    readonly property bool headphones: {
        const s = ServicePipewire.sink
        const t = ((s?.description ?? "") + " " + (s?.name ?? "") + " " + (s?.nickname ?? "")).toLowerCase()
        return /headphone|headset|earbud|buds|airpods|bluez/.test(t)
    }
    readonly property bool onSide: !!root.host && root.host.vertical === true
    readonly property bool sideCompact: root.onSide && (!root.host.compactFor || root.host.compactFor(root.itemId))
    readonly property bool vertical: root.onSide
    readonly property bool sideNum: root.vertical && !root.sideCompact && BarLayout.opt(root.itemId, "showPercent") !== false && !ServicePipewire.muted && !root.cookie
    readonly property bool verticalReady: root.vertical

    implicitWidth: volPill.width
    implicitHeight: volPill.height

    Rectangle {
        id: volPill
        anchors.verticalCenter: parent.verticalCenter
        width: root.bigCookie ? root.host.barH
            : root.vertical ? Math.max(root.plate, volRow.implicitWidth + 8)
            : volRow.implicitWidth + root.padPx
        height: root.bigCookie ? root.host.barH
            : root.sideNum ? volRow.implicitHeight + 8 : root.plate
        radius: Math.min(width, height) / 2
        color: root.plateless || root.cookie ? Qt.alpha(root.plateColor, 0) : root.plateColor
        Behavior on color { ColorAnimation { duration: 150 } }

        GridLayout {
            id: volRow
            anchors.centerIn: parent
            columns: root.vertical ? 1 : -1
            rowSpacing: 1
            columnSpacing: root.gapPx

            BarShapeMeter {
                id: volCookie
                Layout.alignment: Qt.AlignHCenter
                visible: root.cookie
                Layout.preferredWidth: root.bigCookie ? BarLayout.plateH(root.itemId, root.host.barH) : Math.round(root.iconPx * 1.45)
                Layout.preferredHeight: Layout.preferredWidth
                value: ServicePipewire.muted ? 0 : ServicePipewire.volume
                shape: root.shapeName
                thickness: BarLayout.opt(root.itemId, "thickness") ?? -1
                filled: root.filled
                sweep: root.sweep
                angle: BarLayout.itemStyle(root.itemId, "rotate", 0)
                icon: ServicePipewire.muted ? "volume_off" : root.headphones ? "headphones" : "volume_up"
                iconSize: BarLayout.itemStyle(root.itemId, "iconSize", 0)
                tone: BarLayout.roleColor(BarLayout.opt(root.itemId, "color") ?? "primary")
                onTone: BarLayout.onRoleColor(BarLayout.opt(root.itemId, "color") ?? "primary")
                track: root.bigCookie ? "transparent" : Colors.surfaceContainerHighest
                ground: root.plateTone
                onPlate: root.bigCookie
            }

            MaterialIconSymbol {
                Layout.alignment: Qt.AlignHCenter
                visible: !root.cookie
                content: ServicePipewire.muted ? "volume_off"
                       : ServicePipewire.volume > 0.6 ? "volume_up"
                       : ServicePipewire.volume > 0.2 ? "volume_down"
                       : "volume_mute"
                iconSize: root.iconPx
                customColor: volHov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                Behavior on customColor { ColorAnimation { duration: 150 } }
            }

            CustomText {
                visible: BarLayout.opt(root.itemId, "showPercent") !== false && !root.vertical && !root.cookie
                Layout.alignment: Qt.AlignHCenter
                content: ServicePipewire.muted ? "Muted"
                       : Math.round(ServicePipewire.volume * 100) + (root.vertical ? "" : "%")
                size: root.vertical ? root.labelPx - 2 : root.labelPx; weight: 700
                customColor: volHov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                Behavior on customColor { ColorAnimation { duration: 150 } }
            }

            BarSideNumber {
                visible: root.sideNum
                Layout.alignment: Qt.AlignHCenter
                value: Math.round(ServicePipewire.volume * 100) + ""
                maxWidth: (root.host ? root.host.barH : 40) - 10
                ink: volHov.containsMouse ? Colors.primaryContainerText : Colors.surfaceText
                size: root.labelPx - 1
            }
        }

        MouseArea {
            id: volHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    ServicePipewire.toggleMute()
                else if (root.host)
                    root.host.openPanel("sound", root)
            }
            onWheel: wheel => {
                const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                if (d > 0)
                    ServicePipewire.incrementVolume(0.05)
                else if (d < 0)
                    ServicePipewire.decrementVolume(0.05)
            }
        }
    }
}
