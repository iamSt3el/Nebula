import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Rectangle {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: ServicePhone.found
    readonly property bool iconSizable: true
    readonly property real box: BarLayout.boxFor(root.itemId, root.host)
    readonly property real iconPx: BarLayout.iconPxFor(root.itemId, root.box, 18)
    readonly property real plate: BarLayout.platePxFor(root.box, root.iconPx, 18, 28)
    readonly property bool open: !!root.host && root.host.panelKind === "phoneStatus"
    readonly property bool away: !ServicePhone.ready
    readonly property bool low: ServicePhone.ready && ServicePhone.low
    readonly property bool showPercent: BarLayout.opt(root.itemId, "showPercent") !== false
    readonly property bool showSignal: BarLayout.opt(root.itemId, "showSignal") !== false
    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property bool verticalReady: true
    readonly property color plateColor: hov.containsMouse || root.open ? Colors.primaryContainer
         : root.low ? Qt.alpha(Colors.error, 0.15) : "transparent"
    readonly property bool plateless: BarLayout.chipHovers(root.itemId, root.implicitWidth,
                                                           root.implicitHeight)
    readonly property bool plateOn: root.plateColor.a > 0.01
    readonly property real labelPx: BarLayout.scaleFor(root.iconPx, 18, 13, 8)
    readonly property real gapPx: BarLayout.scaleFor(root.iconPx, 18, 6, 2)
    readonly property real padPx: root.plate - root.iconPx
    readonly property color ink: hov.containsMouse || root.open ? Colors.primaryContainerText
                               : root.low ? Colors.error : root.away ? Colors.surfaceVariantText : Colors.surfaceText

    readonly property string label: !ServicePhone.paired ? "Pair"
        : root.away ? "Away"
        : ServicePhone.battery >= 0 ? ServicePhone.battery + "%" : ""
    readonly property bool labelOn: root.label !== "" && (root.showPercent || root.away)

    implicitWidth: root.vertical ? Math.max(root.plate, row.implicitWidth + 8)
        : root.labelOn || root.barsOn ? row.implicitWidth + root.padPx : root.plate
    implicitHeight: root.vertical ? Math.max(root.plate, row.implicitHeight + 8) : root.plate
    radius: Math.min(width, height) / 2
    color: root.plateless ? "transparent" : root.plateColor
    border.width: root.low && !hov.containsMouse && !root.open ? 2 : 0
    border.color: Colors.error
    opacity: root.away && !hov.containsMouse && !root.open ? 0.6 : 1
    Behavior on color { EffectsColorAnim { speed: "fast" } }
    Behavior on opacity { EffectsAnim { speed: "fast" } }

    readonly property bool barsOn: root.showSignal && !root.away && ServicePhone.bars >= 0 && !root.vertical

    Grid {
        id: row
        anchors.centerIn: parent
        spacing: root.vertical ? 1 : root.gapPx
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        MaterialIconSymbol {
            content: root.away ? "mobile_off" : "smartphone"
            iconSize: root.iconPx
            customColor: root.ink
        }

        CustomText {
            visible: root.labelOn
            content: root.vertical && !root.away ? String(ServicePhone.battery) : root.label
            size: root.vertical ? root.labelPx - 2 : root.labelPx
            weight: root.away ? 500 : 700
            customColor: root.ink
        }

        MaterialIconSymbol {
            visible: ServicePhone.ready && ServicePhone.charging && !root.vertical
            content: "bolt"
            iconSize: root.iconPx - 4
            customColor: hov.containsMouse || root.open ? root.ink : Colors.primary
        }

        Row {
            visible: root.barsOn
            spacing: 2
            height: Math.round(root.iconPx * 0.72)

            Repeater {
                model: 4
                delegate: Rectangle {
                    required property int index
                    anchors.bottom: parent.bottom
                    width: 3
                    height: Math.round(parent.height * (index + 1) / 4)
                    radius: 1
                    color: index < ServicePhone.bars ? root.ink : Qt.alpha(root.ink, 0.25)
                }
            }
        }

        CustomText {
            visible: root.barsOn && ServicePhone.netType !== ""
            content: ServicePhone.netType
            size: root.labelPx - 2
            weight: 700
            customColor: hov.containsMouse || root.open ? root.ink : Colors.surfaceVariantText
        }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                ServicePhone.ring()
            else if (root.host)
                root.host.openPanel("phoneStatus", root)
        }
    }

    CustomToolTip {
        content: ServicePhone.label + (!ServicePhone.paired ? ", not paired"
            : root.away ? ", not nearby"
            : ServicePhone.battery >= 0 ? " · " + ServicePhone.battery + "%" + (ServicePhone.charging ? ", charging" : "") : "")
        detail: ServicePhone.ready ? "Middle-click to ring it" : ""
        visible: hov.containsMouse && !root.open
    }
}
