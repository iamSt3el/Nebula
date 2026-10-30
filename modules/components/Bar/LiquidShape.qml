pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes

Item {
    id: ls

    component LiquidInk: Item {
        id: ink
        property color tone
        property string label: ""
        property int labelSize: 34
        property string icon: ""
        property int iconSize: 18

        Column {
            anchors.centerIn: parent
            spacing: 0

            CustomText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: ink.label !== ""
                content: ink.label
                family: SettingsConfig.general?.displayFont || "Titan One"
                renderType: Text.QtRendering
                size: ink.labelSize
                weight: 400
                customColor: ink.tone
            }
            MaterialIconSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: ink.icon !== ""
                content: ink.icon
                iconSize: ink.iconSize
                fill: 1
                customColor: ink.tone
            }
        }
    }

    property string shape: "cookie4"
    property real level: 0
    property color fill: Colors.secondary
    property color track: Colors.surfaceContainerHighest
    property color ink: Colors.surfaceText
    property color onInk: Colors.secondaryText
    property string label: ""
    property int labelSize: 34
    property string icon: ""
    property int iconSize: 18
    readonly property real liquidH: Math.round(ls.height * Math.max(0, Math.min(1, ls.level)))

    Behavior on level { SpatialAnim { speed: "slow" } }

    MaterialShapes.ShapeCanvas {
        anchors.fill: parent
        roundedPolygon: ls.shape
        color: ls.track
    }

    LiquidInk {
        anchors.fill: parent
        tone: ls.ink
        label: ls.label
        labelSize: ls.labelSize
        icon: ls.icon
        iconSize: ls.iconSize
    }

    Item {
        id: liquid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: ls.liquidH
        clip: true

        MaterialShapes.ShapeCanvas {
            y: liquid.height - ls.height
            width: ls.width
            height: ls.height
            roundedPolygon: ls.shape
            color: ls.fill
        }

        LiquidInk {
            y: liquid.height - ls.height
            width: ls.width
            height: ls.height
            tone: ls.onInk
            label: ls.label
            labelSize: ls.labelSize
            icon: ls.icon
            iconSize: ls.iconSize
        }
    }
}
