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

    property bool fillWidth: false
    property int iconSize: 14
    property int textSize: 11

    readonly property real fullRadius: height / 2
    readonly property real innerRadius: 4
    readonly property real gap: 2

    height: 30
    implicitWidth: fillWidth ? root.width : _row.implicitWidth

    Row {
        id: _row
        height: parent.height
        width: root.fillWidth ? root.width : implicitWidth
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
                readonly property real contentWidth:
                    (seg.hasIcon ? _icon.implicitWidth : 0)
                    + (seg.hasIcon && seg.hasLabel ? _content.spacing : 0)
                    + (seg.hasLabel ? _label.implicitWidth : 0)
                implicitWidth: seg.contentWidth + 22
                width: root.fillWidth
                    ? (root.width - (root.model.length - 1) * root.gap) / Math.max(root.model.length, 1)
                    : implicitWidth

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

                Item {
                    id: _box
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    clip: true

                    Row {
                        id: _content
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialIconSymbol {
                            id: _icon
                            visible: seg.hasIcon
                            anchors.verticalCenter: parent.verticalCenter
                            content: seg.modelData.icon ?? ""
                            iconSize: root.iconSize
                            fill: seg.active ? 1 : 0
                            Behavior on fill { NumberAnimation { duration: 200 } }
                            customColor: seg.active ? root.activeTextColor : root.inactiveTextColor
                        }

                        CustomText {
                            id: _label
                            visible: seg.hasLabel
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, Math.min(implicitWidth,
                                            _box.width - (seg.hasIcon ? _icon.implicitWidth + _content.spacing : 0)))
                            content: seg.modelData.label ?? ""
                            size: root.textSize
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            customColor: seg.active ? root.activeTextColor : root.inactiveTextColor
                        }
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
