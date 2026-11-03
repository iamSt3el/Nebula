import QtQuick
import QtQuick.Layouts
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Rectangle {
    id: card

    property int number: 0
    property string title: ""
    property string detail: ""
    property string icon: ""
    property bool selected: false
    property bool first: true
    property bool last: true
    property real padding: 16
    default property alias extra: extraHolder.data
    property alias trailing: trailHolder.data

    signal clicked

    readonly property real bigRadius: 22
    readonly property real smallRadius: 6
    readonly property color ink: card.selected ? Colors.primaryContainerText : Colors.surfaceText

    topLeftRadius: card.selected || card.first ? card.bigRadius : card.smallRadius
    topRightRadius: card.topLeftRadius
    bottomLeftRadius: card.selected || card.last ? card.bigRadius : card.smallRadius
    bottomRightRadius: card.bottomLeftRadius

    Behavior on topLeftRadius { NumberAnimation { duration: M3Motion.container.radiusDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: M3Motion.container.curve } }
    Behavior on bottomLeftRadius { NumberAnimation { duration: M3Motion.container.radiusDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: M3Motion.container.curve } }

    color: card.selected ? Colors.primaryContainer : Colors.surfaceContainer
    Behavior on color { EffectsColorAnim {} }

    implicitHeight: column.implicitHeight + card.padding * 2

    RippleEffect {
        anchors.fill: parent
        topLeftRadius: card.topLeftRadius
        topRightRadius: card.topRightRadius
        bottomLeftRadius: card.bottomLeftRadius
        bottomRightRadius: card.bottomRightRadius
        onClicked: card.clicked()
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: card.padding
        spacing: 10

        ColumnLayout {
            id: extraHolder
            Layout.fillWidth: true
            visible: children.length > 0
            spacing: 0
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                visible: card.number > 0
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 9
                color: card.selected ? Colors.primary : Colors.surfaceContainerHighest
                Behavior on color { EffectsColorAnim {} }

                CustomText {
                    anchors.centerIn: parent
                    content: String(card.number)
                    size: 13
                    weight: 600
                    customColor: card.selected ? Colors.primaryText : Colors.surfaceVariantText
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                CustomText {
                    Layout.fillWidth: true
                    content: card.title
                    size: 15
                    weight: 500
                    customColor: card.ink
                    elide: Text.ElideRight
                }

                CustomText {
                    Layout.fillWidth: true
                    visible: card.detail !== ""
                    content: card.detail
                    size: 13
                    weight: 400
                    customColor: Qt.alpha(card.ink, 0.78)
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            Row {
                id: trailHolder
                visible: children.length > 0
                spacing: 4
            }

            MaterialIconSymbol {
                visible: card.icon !== ""
                content: card.icon
                iconSize: 22
                fill: card.selected ? 1 : 0
                customColor: card.selected ? Colors.primaryContainerText : Colors.surfaceVariantText
            }
        }
    }
}
