import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

Rectangle {
    id: pill
    property string icon: ""
    property string label: ""
    property bool lit: false
    property bool danger: false
    property bool alarm: false
    property bool filled: false
    property bool tonal: false
    property bool usable: true
    property int box: 44
    property string tip: ""
    readonly property bool pressed: pillArea.pressed
    readonly property bool hovered: pillArea.containsMouse
    signal clicked
    signal held

    implicitHeight: pill.box
    implicitWidth: pill.label !== "" ? pillRow.implicitWidth + (pill.icon !== "" ? 30 : 32) : pill.box
    radius: pillArea.pressed ? 12 : pill.box / 2
    opacity: pill.usable ? 1 : 0.38
    color: pill.alarm ? Colors.errorContainer
        : pill.filled ? Colors.primary
        : pill.tonal ? Colors.primaryContainer
        : pill.lit ? Colors.secondaryContainer
        : pillArea.containsMouse && pill.usable ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
    Behavior on radius { SpatialAnim { speed: "fast" } }
    Behavior on color { EffectsColorAnim { speed: "fast" } }
    Behavior on implicitWidth { SpatialAnim { speed: "fast" } }

    readonly property color ink: pill.alarm ? Colors.errorContainerText
        : pill.filled ? Colors.primaryText
        : pill.tonal ? Colors.primaryContainerText
        : pill.danger ? Colors.error
        : pill.lit ? Colors.secondaryContainerText : Colors.surfaceText

    RowLayout {
        id: pillRow
        anchors.centerIn: parent
        spacing: 7

        MaterialIconSymbol {
            visible: pill.icon !== ""
            content: pill.icon
            iconSize: 19
            customColor: pill.ink
        }

        CustomText {
            visible: pill.label !== ""
            content: pill.label
            size: 13
            weight: 600
            customColor: pill.ink
        }
    }

    MouseArea {
        id: pillArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: pill.usable
        cursorShape: Qt.PointingHandCursor
        pressAndHoldInterval: 450
        property bool wasHeld: false
        onPressed: pillArea.wasHeld = false
        onPressAndHold: {
            pillArea.wasHeld = true
            pill.held()
        }
        onClicked: if (!pillArea.wasHeld) pill.clicked()
    }

    CustomToolTip { content: pill.tip; visible: pill.tip !== "" && pillArea.containsMouse && !pillArea.pressed }
}
