import QtQuick
import qs.modules.utils
import qs.modules.customComponents

Item {
    id: root

    property int value: 0
    property int val: root.value
    property int inc: 10
    property int min: 0
    property int limit: 100
    property color color: Colors.surfaceContainerHighest
    property color valueColor: Colors.secondaryContainer
    property color valueTextColor: Colors.secondaryContainerText
    property string suffix: ""

    readonly property real outerRadius: root.height / 2
    readonly property real innerRadius: 4
    readonly property real pressedInnerRadius: 4
    readonly property real buttonWidth: 48
    readonly property real valueWidth: 64
    readonly property real grow: 8
    readonly property real pillWidth: Math.max(root.valueWidth, Math.ceil(valueText.implicitWidth) + 24)

    onValueChanged: if (root.val !== root.value) root.val = root.value

    implicitWidth: root.buttonWidth * 2 + root.pillWidth + row.spacing * 2
    implicitHeight: 40

    function step(dir) {
        const next = Math.max(root.min, Math.min(root.limit, root.val + dir * root.inc))
        if (next !== root.val)
            root.val = next
    }

    component StepButton: Rectangle {
        id: btn

        property int dir: 1
        property string icon: ""
        readonly property bool lead: btn.dir < 0
        readonly property bool can: btn.dir < 0 ? root.val > root.min : root.val < root.limit
        readonly property bool down: area.pressed && btn.can
        readonly property real inner: btn.down ? root.pressedInnerRadius : root.innerRadius

        width: root.buttonWidth + (btn.down ? root.grow : 0)
        height: root.height
        topLeftRadius: btn.lead ? root.outerRadius : btn.inner
        bottomLeftRadius: btn.lead ? root.outerRadius : btn.inner
        topRightRadius: btn.lead ? btn.inner : root.outerRadius
        bottomRightRadius: btn.lead ? btn.inner : root.outerRadius
        color: !btn.can ? root.color
            : btn.down ? Qt.tint(root.color, Qt.alpha(Colors.surfaceText, 0.12))
            : area.containsMouse ? Qt.tint(root.color, Qt.alpha(Colors.surfaceText, 0.08))
            : root.color

        Behavior on width { SpatialAnim { speed: "fast" } }
        Behavior on topLeftRadius { SpatialAnim { speed: "fast" } }
        Behavior on bottomLeftRadius { SpatialAnim { speed: "fast" } }
        Behavior on topRightRadius { SpatialAnim { speed: "fast" } }
        Behavior on bottomRightRadius { SpatialAnim { speed: "fast" } }
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        MaterialIconSymbol {
            anchors.centerIn: parent
            content: btn.icon
            iconSize: btn.down ? 22 : 20
            fill: 1
            customColor: btn.can ? Colors.surfaceText : Qt.alpha(Colors.surfaceText, 0.38)

            Behavior on iconSize { SpatialAnim { speed: "fast" } }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.can ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: if (btn.can) {
                root.step(btn.dir)
                repeat.interval = 420
                repeat.restart()
            }
            onReleased: repeat.stop()
            onCanceled: repeat.stop()
        }

        Timer {
            id: repeat
            repeat: true
            onTriggered: {
                repeat.interval = 70
                if (btn.can)
                    root.step(btn.dir)
                else
                    repeat.stop()
            }
        }
    }

    Row {
        id: row
        anchors.fill: parent
        spacing: 2

        StepButton {
            id: minus
            dir: -1
            icon: "remove"
        }

        Rectangle {
            width: root.pillWidth - (minus.down ? root.grow : 0) - (plus.down ? root.grow : 0)
            height: root.height
            radius: root.innerRadius
            color: root.valueColor

            Behavior on width { SpatialAnim { speed: "fast" } }

            CustomText {
                id: valueText
                anchors.centerIn: parent
                content: root.val + root.suffix
                size: 14
                weight: 600
                customColor: root.valueTextColor
            }
        }

        StepButton {
            id: plus
            dir: 1
            icon: "add"
        }
    }
}
