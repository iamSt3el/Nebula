pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.services
import qs.modules.settings
import qs.modules.customComponents
import "../../MatrialShapes/" as MaterialShapes
import "../../MatrialShapes/shape-library.js" as ShapeLibrary

WidgetHost {
    id: root
    configKey: "clock"
    tile: Qt.size(WidgetSizes.span(4), WidgetSizes.span(2))
    defaultPos: Qt.point(100, 100)
    backdrop: false
    outlined: false

    readonly property string shapeLock: SettingsConfig.widgets.clockShapeLock ?? ""
    readonly property bool spin: SettingsConfig.widgets.clockSpin ?? true
    readonly property var digitShapes: ["cookie12", "clover4", "sunny", "flower", "cookie4",
                                        "softBurst", "cookie6", "cookie7", "clover8", "cookie9"]
    readonly property string _family: SettingsConfig.general.defaultFont ?? "Rubik"

    property real spinPhase: 0
    Timer {
        interval: 100
        repeat: true
        running: root.spin && !root.preview
        onTriggered: root.spinPhase += 0.1
    }

    ClockParts { id: t }
    readonly property string digits: t.hourPad + t.minute

    optionsComponent: Component {
        ColumnLayout {
            spacing: 12
            ShapePicker {
                Layout.fillWidth: true
                selected: root.shapeLock
                autoHint: "A different shape for each digit"
                onPicked: name => SettingsConfig.widgets = Object.assign({}, SettingsConfig.widgets, { clockShapeLock: name })
            }
            ClockOptions {
                Layout.fillWidth: true
                rows: [{ key: "clockSpin", label: "Slow rotation", sub: "The shapes turn gently while idle", def: true }]
            }
        }
    }

    component Digit: MotionEnter {
        id: dg
        required property int index
        readonly property string value: root.digits.charAt(dg.index)
        width: 88
        height: 88
        dy: 0
        fromScale: 0.3
        fromRotation: -40
        delay: 60 + dg.index * 80
        animated: !root.preview

        ClockLift {
            anchors.fill: parent
            strength: 0.7

            rotation: {
                if (!root.spin || root.preview)
                    return 0
                const period = 90 + dg.index * 9
                const frac = (root.spinPhase % period) / period
                return dg.index % 2 === 0 ? frac * 360 : 360 - frac * 360
            }

            MaterialShapes.ShapeCanvas {
                anchors.fill: parent
                roundedPolygon: root.shapeLock !== "" ? (ShapeLibrary.get(root.shapeLock) ?? ShapeLibrary.get("circle"))
                                                      : ShapeLibrary.get(root.digitShapes[parseInt(dg.value) || 0])
                color: dg.index < 2 ? Colors.primary : Colors.primaryContainer
            }
        }

        Text {
            anchors.centerIn: parent
            text: dg.value
            color: dg.index < 2 ? Colors.primaryText : Colors.primaryContainerText
            font.family: root._family
            font.pixelSize: 58
            font.weight: 700
            renderType: Text.QtRendering
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 14

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Digit { index: 0 }
            Digit { index: 1 }

            MotionEnter {
                anchors.verticalCenter: parent.verticalCenter
                dy: 0
                fromScale: 0
                delay: 200
                animated: !root.preview

                ClockLift {
                    width: 16
                    height: 34
                    Column {
                        anchors.centerIn: parent
                        spacing: 12
                        Repeater {
                            model: 2
                            Rectangle { width: 10; height: 10; radius: 5; color: Colors.surfaceText }
                        }
                    }
                }
            }

            Digit { index: 2 }
            Digit { index: 3 }
        }

        MotionEnter {
            visible: t.showDate
            anchors.horizontalCenter: parent.horizontalCenter
            delay: 420
            dy: 12
            animated: !root.preview

            ClockLift {
                width: dateText.implicitWidth
                height: dateText.implicitHeight
                CustomText {
                    id: dateText
                    content: t.weekday + ", " + t.month + " " + t.day
                    size: 17
                    weight: 600
                }
            }
        }
    }
}
