import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.customComponents

QtObject {
    component Pill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property bool lit: false
        property bool danger: false
        property bool filled: false
        property bool tonal: false
        property bool usable: true
        property int box: 40
        property string tip: ""
        signal clicked

        implicitHeight: pill.box
        implicitWidth: pill.label !== "" ? pillRow.implicitWidth + (pill.icon !== "" ? 30 : 32) : pill.box
        radius: pillArea.pressed ? 12 : pill.box / 2
        opacity: pill.usable ? 1 : 0.38
        color: pill.filled ? Colors.primary
            : pill.tonal ? Colors.primaryContainer
            : pill.lit ? Colors.secondaryContainer
            : pillArea.containsMouse && pill.usable ? Qt.alpha(Colors.surfaceText, 0.08) : "transparent"
        Behavior on radius { SpatialAnim { speed: "fast" } }
        Behavior on color { EffectsColorAnim { speed: "fast" } }

        readonly property color ink: pill.filled ? Colors.primaryText
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
            onClicked: pill.clicked()
        }

        CustomToolTip { content: pill.tip; visible: pill.tip !== "" && pillArea.containsMouse }
    }

    component Divider: Rectangle {
        implicitWidth: 1
        implicitHeight: 24
        color: Colors.outlineVariant
    }

    component Card: Rectangle {
        color: Colors.surfaceContainer
        border.width: 1
        border.color: Qt.alpha(Colors.outline, 0.18)
    }

    component SectionLabel: CustomText {
        size: 13
        weight: 500
        customColor: Colors.primary
    }

    component ChoiceChip: Rectangle {
        id: cc
        property string label: ""
        property string icon: ""
        property bool lit: false
        signal clicked
        implicitHeight: 34
        implicitWidth: ccRow.implicitWidth + 24
        radius: 17
        color: cc.lit ? Colors.secondaryContainer
            : ccArea.containsMouse ? Colors.surfaceContainerHighest : Colors.surfaceContainerHigh
        Behavior on color { EffectsColorAnim { speed: "fast" } }
        RowLayout {
            id: ccRow
            anchors.centerIn: parent
            spacing: 6
            MaterialIconSymbol {
                visible: cc.icon !== "" || cc.lit
                content: cc.lit ? "check" : cc.icon
                iconSize: 15
                customColor: cc.lit ? Colors.secondaryContainerText : Colors.surfaceVariantText
            }
            CustomText {
                content: cc.label
                size: 12
                weight: cc.lit ? 700 : 500
                customColor: cc.lit ? Colors.secondaryContainerText : Colors.surfaceText
            }
        }
        MouseArea {
            id: ccArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cc.clicked()
        }
    }
}
