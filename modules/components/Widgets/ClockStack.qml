import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

WidgetHost {
    id: root
    configKey: "clock"
    tile: Qt.size(WidgetSizes.span(2), WidgetSizes.span(3))
    defaultPos: Qt.point(100, 100)
    backdrop: false
    outlined: false

    readonly property bool alignLeft: SettingsConfig.widgets.clockAlignLeft ?? false
    readonly property int _align: root.alignLeft ? Text.AlignLeft : Text.AlignRight
    readonly property string _family: SettingsConfig.general.defaultFont ?? "Rubik"

    ClockParts { id: t }

    optionsComponent: Component {
        ClockOptions { rows: [{ key: "clockAlignLeft", label: "Align left", sub: "Hug the left edge instead of the right", def: false }] }
    }

    component Row2: MotionEnter {
        property string value: ""
        property color tone: t.ink
        width: parent.width
        dx: (root.alignLeft ? -1 : 1) * 40
        dy: 0
        animated: !root.preview

        RollText {
            width: parent.width
            horizontalAlignment: root._align
            text: parent.value
            color: parent.tone
            family: root._family
            pixelSize: 128
            weight: 700
            letterSpacing: -6
            lineHeight: 0.84
            animated: !root.preview
        }
    }

    ClockLift {
        anchors.fill: parent

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: -40

            Row2 { value: t.hourPad; delay: 60 }
            Row2 { value: t.minute; tone: t.accent; delay: 160 }

            MotionEnter {
                visible: t.showDate
                width: parent.width
                delay: 320
                dy: 12
                animated: !root.preview

                Column {
                    width: parent.width
                    topPadding: 58
                    CustomText {
                        width: parent.width
                        horizontalAlignment: root._align
                        content: t.weekday
                        customColor: t.ink
                        size: 16
                        weight: 600
                    }
                    CustomText {
                        width: parent.width
                        horizontalAlignment: root._align
                        content: t.day + " " + t.month
                        size: 16
                        weight: 500
                        customColor: t.inkVariant
                    }
                }
            }
        }
    }
}
