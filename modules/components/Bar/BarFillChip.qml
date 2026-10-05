import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root

    property real value: 0
    property string icon: ""
    property string label: ""
    property string widthTemplate: "100%"
    property real iconPx: 16
    property real labelPx: 12
    property real chipHeight: 28
    property real minWidth: 0
    property bool hovered: false
    property bool vertical: false
    property color trackColor: Colors.surfaceContainerHigh
    property color fillColor: Colors.primaryContainer
    property color ink: Colors.surfaceText
    property color fillInk: Colors.primaryContainerText

    readonly property real frac: Math.max(0, Math.min(1, root.value))

    readonly property string shownLabel: root.vertical ? root.label.replace("%", "") : root.label

    implicitWidth: root.vertical ? root.chipHeight : Math.max(root.minWidth, inner.implicitWidth + 20)
    implicitHeight: root.vertical ? Math.max(root.chipHeight, inner.implicitHeight + 18) : root.chipHeight

    Rectangle {
        anchors.fill: parent
        radius: Math.min(width, height) / 2
        color: root.hovered ? Qt.lighter(root.trackColor, 1.25) : root.trackColor
        Behavior on color { EffectsColorAnim {} }
    }

    Item {
        id: fillClip
        width: root.vertical ? root.width : root.width * root.frac
        height: root.vertical ? root.height * root.frac : root.height
        y: root.height - height
        clip: true
        Behavior on width { SpatialAnim { speed: "fast" } }
        Behavior on height { SpatialAnim { speed: "fast" } }

        Rectangle {
            y: -fillClip.y
            width: root.width
            height: root.height
            radius: Math.min(width, height) / 2
            color: root.fillColor
            Behavior on color { EffectsColorAnim {} }
        }
    }


    TextMetrics {
        id: probe
        font.family: SettingsConfig.general.defaultFont ?? "Rubik"
        font.pixelSize: root.labelPx
        font.weight: 700
        text: root.widthTemplate
    }

    Grid {
        id: inner
        x: root.vertical ? (root.width - width) / 2 : 10
        y: (root.height - height) / 2
        spacing: root.vertical ? 2 : 5
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        layoutDirection: Qt.LeftToRight

        MaterialIconSymbol {
            visible: root.icon !== ""
            content: root.icon
            iconSize: root.iconPx
            customColor: root.ink
        }

        CustomText {
            visible: !root.vertical && root.label !== ""
            width: Math.max(implicitWidth, probe.advanceWidth)
            font.features: { "tnum": 1 }
            content: root.label
            size: root.labelPx
            weight: 700
            customColor: root.ink
        }
    }

    Item {
        id: fillInkClip
        y: fillClip.y
        width: fillClip.width
        height: fillClip.height
        clip: true

        Grid {
            id: innerFill
            x: inner.x
            y: inner.y - fillInkClip.y
            spacing: inner.spacing
            rows: inner.rows
            columns: inner.columns
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            CustomText {
                visible: root.vertical && root.shownLabel !== ""
                font.features: { "tnum": 1 }
                content: root.shownLabel
                size: root.labelPx - 1
                weight: 700
                customColor: root.fillInk
            }

            MaterialIconSymbol {
                visible: root.icon !== ""
                content: root.icon
                iconSize: root.iconPx
                customColor: root.fillInk
            }

            CustomText {
                visible: !root.vertical && root.label !== ""
                width: Math.max(implicitWidth, probe.advanceWidth)
                font.features: { "tnum": 1 }
                content: root.label
                size: root.labelPx
                weight: 700
                customColor: root.fillInk
            }
        }
    }
}
