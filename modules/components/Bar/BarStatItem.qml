import QtQuick
import qs.modules.utils
import qs.modules.services
import qs.modules.customComponents

Item {
    id: root

    property Item host: null
    property string itemId: ""
    readonly property bool shown: true

    property string icon: ""
    property real value: 0
    property string label: ""
    property string tip: ""
    property string widthTemplate: ""
    property string compactLabel: ""
    property string defaultShape: "cookie9"

    readonly property bool iconSizable: true
    readonly property real box: BarLayout.boxFor(root.itemId, root.host)
    readonly property real iconPx: BarLayout.iconPxFor(root.itemId, root.box, 16)
    readonly property real plate: BarLayout.platePxFor(root.box, root.iconPx, 16, 26)
    readonly property string style: {
        const s = BarLayout.opt(root.itemId, "style") ?? "text"
        if (s === "text" || s === "segring" || s === "shape")
            return s
        return ({ cookie: "shape", liquid: "shape", dial: "segring", rings: "segring", orbit: "segring",
                  radial: "segring", speedo: "segring", ring: "segring", gauge: "segring" })[s] ?? "text"
    }
    readonly property bool shaped: root.style === "shape"
    readonly property string shapeName: BarLayout.opt(root.itemId, "shape") ?? root.defaultShape
    readonly property bool filled: BarLayout.opt(root.itemId, "meter") === "fill"
    readonly property real angle: BarLayout.itemStyle(root.itemId, "rotate", 0)
    readonly property bool showIcon: BarLayout.opt(root.itemId, "showIcon") !== false
    readonly property bool showValue: !root.shaped && BarLayout.opt(root.itemId, "showValue") !== false
    readonly property real k: root.iconPx / 16
    function px(v) { return Math.round(v * root.k) }

    readonly property bool bigShape: root.shaped && !!root.host && root.host.split === true
    readonly property string plateShape: root.bigShape ? root.shapeName : ""
    readonly property bool hoverPlate: false
    readonly property color plateTone: root.bigShape ? (root.host.plateFill ?? Colors.surface) : Colors.surface

    readonly property bool vertical: !!root.host && root.host.vertical === true
        && (!root.host.compactFor || root.host.compactFor(root.itemId))
    readonly property bool verticalReady: root.vertical
    readonly property string shortValue: root.compactLabel !== "" ? root.compactLabel
        : root.label.replace("%", "").replace("°C", "°")

    implicitWidth: root.bigShape ? root.host.barH
        : root.verticalReady ? Math.max(root.plate, content.implicitWidth + 6)
        : content.implicitWidth + BarLayout.scaleFor(root.iconPx, 16, 12, 6)
    implicitHeight: root.bigShape ? root.host.barH
        : root.verticalReady ? content.implicitHeight + 8 : Math.max(root.plate, content.implicitHeight)

    Component.onCompleted: ServiceSystemInfo.retain()
    Component.onDestruction: ServiceSystemInfo.release()

    readonly property real load: Math.max(0, Math.min(1, root.value))
    readonly property color loadColor: BarLayout.roleColor(BarLayout.opt(root.itemId, "color") ?? "primary")

    Grid {
        id: content
        anchors.centerIn: parent
        visible: !root.bigShape
        spacing: root.verticalReady ? 2 : root.px(6)
        rows: root.verticalReady ? -1 : 1
        columns: root.verticalReady ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        MaterialIconSymbol {
            visible: root.showIcon && root.style === "text"
            content: root.icon
            iconSize: root.iconPx
            customColor: Colors.surfaceText
        }

        Loader {
            active: root.style === "segring"
            visible: active
            sourceComponent: MeterSegmentRing {
                implicitWidth: root.px(26)
                implicitHeight: root.px(26)
                segments: 8
                gapDegrees: 12
                thickness: Math.max(2.5, root.px(3.5))
                value: root.load
                color: root.loadColor
                StatIcon { size: root.px(12) }
            }
        }

        Loader {
            active: root.shaped && !root.bigShape
            visible: active
            sourceComponent: StatShape {
                implicitWidth: root.px(26)
                implicitHeight: root.px(26)
                track: Colors.surfaceContainerHighest
                iconSize: root.customIcon > 0 ? root.customIcon : root.px(12)
            }
        }

        CustomText {
            id: valueText
            visible: root.showValue
            width: root.verticalReady ? valueText.implicitWidth : Math.max(valueText.implicitWidth, widthProbe.advanceWidth)
            font.features: { "tnum": 1 }
            content: root.verticalReady ? root.shortValue : root.label
            size: root.verticalReady ? root.px(11) : root.px(13)
            weight: 700
        }
    }

    Loader {
        anchors.centerIn: parent
        active: root.bigShape
        sourceComponent: StatShape {
            width: BarLayout.plateH(root.itemId, root.host.barH)
            height: width
            onPlate: true
            iconSize: root.customIcon
        }
    }

    TextMetrics {
        id: widthProbe
        font: valueText.font
        text: root.widthTemplate
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
    }

    CustomToolTip {
        content: root.tip !== "" ? root.tip : root.label
        visible: hov.containsMouse
    }

    readonly property real customIcon: BarLayout.itemStyle(root.itemId, "iconSize", 0)
    component StatIcon: MaterialIconSymbol {
        property real size: 12
        readonly property real box: 2 * Math.round((root.customIcon > 0 ? root.customIcon : size) / 2)
        x: Math.round((parent.width - box) / 2)
        y: Math.round((parent.height - box) / 2)
        width: box
        height: box
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: root.showIcon
        content: root.icon
        iconSize: box
        customColor: Colors.surfaceText
    }

    component StatShape: BarShapeMeter {
        value: root.load
        shape: root.shapeName
        filled: root.filled
        angle: root.angle
        icon: root.icon
        showIcon: root.showIcon
        tone: root.loadColor
        onTone: BarLayout.onRoleColor(BarLayout.opt(root.itemId, "color") ?? "primary")
        ground: root.plateTone
    }
}
