import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

// M3 Connected Button Group
//
// Each segment is an independent filled button. Outer corners stay fully
// rounded (pill); inner corners tighten to a small radius where buttons meet.
// A 2dp gap separates segments so the background shows through.
// Press triggers an M3-style ripple (from repos StateLayer pattern).
//
// model:       array of { value, label?, icon? }
// activeCheck: function(value) => bool
// signal segmentClicked(value)
Item {
    id: root

    property var model: []
    property var activeCheck: function(value) { return false }
    signal segmentClicked(var value)

    property color activeColor: Colors.primary
    property color activeTextColor: Colors.primaryText
    property color inactiveColor: Colors.surfaceContainerHighest
    property color inactiveTextColor: Colors.surfaceText

    readonly property real fullRadius: height / 2
    readonly property real innerRadius: 4
    readonly property real gap: 2

    height: 30
    implicitWidth: _row.implicitWidth

    Row {
        id: _row
        height: parent.height
        spacing: root.gap

        Repeater {
            model: root.model

            delegate: Item {
                id: seg
                required property var modelData
                required property int index

                readonly property bool active: root.activeCheck(modelData.value)
                readonly property bool isFirst: index === 0
                readonly property bool isLast: index === root.model.length - 1
                readonly property bool hasIcon: !!modelData.icon
                readonly property bool hasLabel: !!modelData.label

                height: root.height
                implicitWidth: _content.implicitWidth + 22

                // Fill
                Rectangle {
                    anchors.fill: parent
                    color: seg.active ? root.activeColor : root.inactiveColor
                    Behavior on color { ColorAnimation { duration: 150 } }

                    topLeftRadius:     (seg.isFirst || seg.active) ? root.fullRadius : root.innerRadius
                    bottomLeftRadius:  (seg.isFirst || seg.active) ? root.fullRadius : root.innerRadius
                    topRightRadius:    (seg.isLast  || seg.active) ? root.fullRadius : root.innerRadius
                    bottomRightRadius: (seg.isLast  || seg.active) ? root.fullRadius : root.innerRadius
                }

                Row {
                    id: _content
                    anchors.centerIn: parent
                    spacing: 5

                    MaterialIconSymbol {
                        visible: seg.hasIcon
                        anchors.verticalCenter: parent.verticalCenter
                        content: seg.modelData.icon ?? ""
                        iconSize: 14
                        fill: seg.active ? 1 : 0
                        Behavior on fill { NumberAnimation { duration: 200 } }
                        customColor: seg.active ? root.activeTextColor : root.inactiveTextColor
                    }

                    CustomText {
                        visible: seg.hasLabel
                        anchors.verticalCenter: parent.verticalCenter
                        content: seg.modelData.label ?? ""
                        size: 11
                        customColor: seg.active ? root.activeTextColor : root.inactiveTextColor
                    }
                }

                RippleEffect {
                    anchors.fill: parent
                    topLeftRadius:     (seg.isFirst || seg.active) ? root.fullRadius : root.innerRadius
                    bottomLeftRadius:  (seg.isFirst || seg.active) ? root.fullRadius : root.innerRadius
                    topRightRadius:    (seg.isLast  || seg.active) ? root.fullRadius : root.innerRadius
                    bottomRightRadius: (seg.isLast  || seg.active) ? root.fullRadius : root.innerRadius
                    hoverColor:  Qt.alpha(seg.active ? root.activeTextColor : Colors.primary, 0.08)
                    rippleColor: Qt.alpha(seg.active ? root.activeTextColor : Colors.primary, 0.25)
                    onClicked: root.segmentClicked(seg.modelData.value)
                }
            }
        }
    }
}
