import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

// M3 Connected Button Group.
// Spec: BetweenSpace 2dp, inner corners CornerValueSmall (8dp), CornerValueExtraSmall
// (4dp) while pressed, and 50% (fully round) on the selected segment. Outer corners
// stay CornerFull. Pressing a segment expands it by ExpandedRatio (0.15) and
// compresses its neighbours.
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
    readonly property real innerRadius: 8
    readonly property real pressedInnerRadius: 4
    readonly property real gap: 2
    readonly property real expandedRatio: 0.15

    property int pressedIndex: -1

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
                readonly property bool isPressed: root.pressedIndex === index
                readonly property bool isNeighbour:
                    root.pressedIndex >= 0 && Math.abs(root.pressedIndex - index) === 1

                height: root.height

                readonly property real contentWidth:
                    (seg.hasIcon ? _icon.implicitWidth : 0)
                    + (seg.hasIcon && seg.hasLabel ? _content.spacing : 0)
                    + (seg.hasLabel ? _label.implicitWidth : 0)

                readonly property real baseWidth: root.fillWidth
                    ? (root.width - (root.model.length - 1) * root.gap)
                      / Math.max(root.model.length, 1)
                    : seg.contentWidth + 22

                // Pressed segment grows by expandedRatio; neighbours give the room back.
                readonly property real _grow: seg.baseWidth * root.expandedRatio
                readonly property int  _neighbours:
                    root.pressedIndex < 0 ? 0
                    : ((root.pressedIndex > 0 ? 1 : 0)
                       + (root.pressedIndex < root.model.length - 1 ? 1 : 0))

                implicitWidth: seg.baseWidth
                width: {
                    if (seg.isPressed) return seg.baseWidth + seg._grow
                    if (seg.isNeighbour && seg._neighbours > 0)
                        return Math.max(seg.baseWidth * 0.5,
                                        seg.baseWidth - seg._grow / seg._neighbours)
                    return seg.baseWidth
                }
                Behavior on width {
                    NumberAnimation {
                        duration: M3Motion.spatial.fastDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: M3Motion.spatial.fastCurve
                    }
                }

                readonly property real _inner:
                    seg.active ? root.fullRadius
                    : seg.isPressed ? root.pressedInnerRadius
                    : root.innerRadius

                readonly property real tl: seg.isFirst ? root.fullRadius : seg._inner
                readonly property real bl: seg.isFirst ? root.fullRadius : seg._inner
                readonly property real tr: seg.isLast  ? root.fullRadius : seg._inner
                readonly property real br: seg.isLast  ? root.fullRadius : seg._inner

                Rectangle {
                    anchors.fill: parent
                    color: seg.active ? root.activeColor : root.inactiveColor
                    Behavior on color {
                        ColorAnimation { duration: M3Motion.effects.fastDuration }
                    }

                    topLeftRadius: seg.tl
                    bottomLeftRadius: seg.bl
                    topRightRadius: seg.tr
                    bottomRightRadius: seg.br
                    Behavior on topLeftRadius     { NumberAnimation { duration: M3Motion.container.radiusDuration } }
                    Behavior on bottomLeftRadius  { NumberAnimation { duration: M3Motion.container.radiusDuration } }
                    Behavior on topRightRadius    { NumberAnimation { duration: M3Motion.container.radiusDuration } }
                    Behavior on bottomRightRadius { NumberAnimation { duration: M3Motion.container.radiusDuration } }
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
                            Behavior on fill {
                                NumberAnimation { duration: M3Motion.effects.defaultDuration }
                            }
                            customColor: seg.active ? root.activeTextColor
                                                    : root.inactiveTextColor
                        }

                        CustomText {
                            id: _label
                            visible: seg.hasLabel
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, Math.min(implicitWidth,
                                _box.width - (seg.hasIcon
                                    ? _icon.implicitWidth + _content.spacing : 0)))
                            content: seg.modelData.label ?? ""
                            size: root.textSize
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            customColor: seg.active ? root.activeTextColor
                                                    : root.inactiveTextColor
                        }
                    }
                }

                RippleEffect {
                    anchors.fill: parent
                    topLeftRadius: seg.tl
                    bottomLeftRadius: seg.bl
                    topRightRadius: seg.tr
                    bottomRightRadius: seg.br
                    hoverColor: Qt.alpha(seg.active ? root.activeTextColor
                                                    : Colors.primary, 0.08)
                    rippleColor: Qt.alpha(seg.active ? root.activeTextColor
                                                     : Colors.primary, 0.25)
                    onPressedChanged: root.pressedIndex = pressed ? seg.index : -1
                    onClicked: root.segmentClicked(seg.modelData.value)
                }
            }
        }
    }
}
