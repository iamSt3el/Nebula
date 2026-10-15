import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.customComponents

Rectangle {
    id: root

    property var info: ({})
    property string variant: "tile"
    property color offColor: Colors.surfaceContainerHigh
    property bool expandable: false
    signal clicked()
    signal opened()

    readonly property bool on: root.info.on ?? false
    readonly property color ink: root.on ? Colors.primaryText : Colors.surfaceText
    readonly property color subInk: root.on ? Colors.primaryText : Colors.surfaceVariantText

    implicitHeight: root.variant === "wide" ? 56 : root.variant === "icon" ? 48 : 60
    radius: root.variant === "wide" ? height / 2 : area.pressed ? 12 : 18
    color: root.on ? Colors.primary : root.offColor
    Behavior on color { EffectsColorAnim {} }
    Behavior on radius { SpatialAnim { speed: "fast" } }

    RowLayout {
        visible: root.variant === "wide"
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 12
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 20
            color: root.on ? Colors.primaryText : Colors.surfaceContainerHighest

            MaterialIconSymbol {
                anchors.centerIn: parent
                content: root.info.icon ?? ""
                iconSize: 20
                fill: root.on ? 1 : 0
                customColor: root.on ? Colors.primary : Colors.surfaceVariantText
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            CustomText { Layout.fillWidth: true; content: root.info.label ?? ""; size: 13; weight: 800; customColor: root.ink }
            CustomText { Layout.fillWidth: true; content: root.info.sub ?? ""; size: 11; weight: 600; customColor: root.subInk }
        }

        MaterialIconSymbol {
            visible: root.expandable
            content: "chevron_right"
            iconSize: 20
            customColor: root.subInk
        }
    }

    ColumnLayout {
        visible: root.variant === "tile"
        anchors.centerIn: parent
        width: parent.width - 12
        spacing: 3

        MaterialIconSymbol {
            Layout.alignment: Qt.AlignHCenter
            content: root.info.icon ?? ""
            iconSize: 20
            fill: root.on ? 1 : 0
            customColor: root.on ? Colors.primaryText : Colors.surfaceVariantText
        }

        CustomText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            content: root.info.key === "wifi" || root.info.key === "bluetooth" ? (root.info.sub ?? "") : (root.info.label ?? "")
            size: 12
            weight: 800
            customColor: root.on ? Colors.primaryText : Colors.surfaceVariantText
        }
    }

    MaterialIconSymbol {
        visible: root.variant === "icon"
        anchors.centerIn: parent
        content: root.info.icon ?? ""
        iconSize: 22
        fill: root.on ? 1 : 0
        customColor: root.on ? Colors.primaryText : Colors.surfaceVariantText
    }

    RippleEffect {
        id: area
        anchors.fill: parent
        radius: root.radius
        hoverColor: Qt.alpha(root.ink, 0.08)
        rippleColor: Qt.alpha(root.ink, 0.16)
        onClicked: root.expandable && root.variant === "wide" ? root.opened() : root.clicked()
    }

    RippleEffect {
        visible: root.expandable && root.variant === "wide"
        x: 8
        y: (parent.height - 40) / 2
        width: 40
        height: 40
        radius: 20
        hoverColor: Qt.alpha(root.ink, 0.12)
        rippleColor: Qt.alpha(root.ink, 0.2)
        onClicked: root.clicked()
    }

    CustomToolTip {
        content: (root.info.label ?? "") + (root.info.sub ? ": " + root.info.sub : "")
        visible: root.variant === "icon" && area.containsMouse
    }
}
