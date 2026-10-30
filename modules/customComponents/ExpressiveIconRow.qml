import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root

    property var model: []
    property var iconFor: function(modelData, active) { return modelData.icon ?? "" }
    property var activeCheck: function(index) { return false }
    property var labelFor: function(modelData) { return modelData.label ?? "" }
    property bool labelActive: false
    signal triggered(int index)

    property int pressedIndex: -1
    readonly property int count: root.model.length
    readonly property real gap: 7
    readonly property real growth: 0.28
    property real minWidth: 46
    property color idleColor: Colors.surfaceContainerHigh
    property color hoverColor: Colors.surfaceContainerHighest
    property real rowHeight: 40

    readonly property string longest: root.labelActive
        ? root.model.map(m => root.labelFor(m)).reduce((a, b) => b.length > a.length ? b : a, "") : ""
    readonly property real activeW: root.labelActive ? measure.implicitWidth + 19 + 6 + 30 : 0

    CustomText {
        id: measure
        visible: false
        content: root.longest
        size: 13
        weight: 600
    }

    readonly property int perRow: root.count <= 0 ? 1
        : root.labelActive
        ? Math.max(1, Math.min(root.count, Math.floor((root.width - root.activeW) / (root.minWidth + root.gap)) + 1))
        : Math.max(1, Math.min(root.count,
                               Math.floor((root.width + root.gap) / (root.minWidth + root.gap))))
    readonly property int rowCount: root.count > 0 ? Math.ceil(root.count / root.perRow) : 0
    readonly property real baseW: root.perRow > 0
        ? (root.width - (root.perRow - 1) * root.gap) / root.perRow : 0

    implicitHeight: root.rowCount > 0
        ? root.rowCount * root.rowHeight + (root.rowCount - 1) * root.gap : 0

    Column {
        anchors.fill: parent
        spacing: root.gap

        Repeater {
            model: root.rowCount

            delegate: Row {
                id: line
                required property int index

                readonly property int from: line.index * root.perRow
                readonly property int n: Math.min(root.perRow, root.count - line.from)
                readonly property bool holdsPressed: root.pressedIndex >= line.from
                    && root.pressedIndex < line.from + line.n
                readonly property bool holdsActive: {
                    if (!root.labelActive)
                        return false
                    for (let i = line.from; i < line.from + line.n; i++)
                        if (root.activeCheck(i))
                            return true
                    return false
                }
                readonly property real wideW: Math.min(root.width, Math.max(root.baseW, root.activeW))
                readonly property real narrowW: line.n > 1 ? (root.width - line.wideW - (line.n - 1) * root.gap) / (line.n - 1) : root.width

                width: root.width
                height: root.rowHeight
                spacing: root.gap

                Repeater {
                    model: line.n

                    delegate: Rectangle {
                        id: btn
                        required property int index

                        readonly property int slot: line.from + btn.index
                        readonly property var entry: root.model[btn.slot]
                        readonly property bool active: root.activeCheck(btn.slot)
                        readonly property bool isPressed: root.pressedIndex === btn.slot

                        width: {
                            if (line.holdsActive)
                                return btn.active ? line.wideW : line.narrowW
                            if (!line.holdsPressed || line.n < 2)
                                return root.baseW
                            if (btn.isPressed)
                                return root.baseW * (1 + root.growth)
                            return root.baseW * (1 - root.growth / (line.n - 1))
                        }
                        height: root.rowHeight
                        Behavior on width { SpatialAnim { speed: "fast" } }

                        radius: btn.isPressed ? btn.height * 0.22
                              : btn.active ? btn.height * 0.32
                              : btn.height / 2
                        Behavior on radius { SpatialAnim { speed: "fast" } }

                        color: btn.active ? Colors.primary
                             : btnArea.containsMouse ? root.hoverColor
                             : root.idleColor
                        Behavior on color { EffectsColorAnim { speed: "fast" } }

                        readonly property bool named: root.labelActive && btn.active
                        clip: root.labelActive

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIconSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                content: btn.entry ? root.iconFor(btn.entry, btn.active) : ""
                                iconSize: btn.isPressed ? 16 : 19
                                Behavior on iconSize { SpatialAnim { speed: "fast" } }
                                customColor: btn.active ? Colors.primaryText : Colors.surfaceText
                                fill: btn.active ? 1 : 0
                                Behavior on fill { EffectsAnim { speed: "fast" } }
                            }

                            CustomText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: btn.named
                                content: btn.entry ? root.labelFor(btn.entry) : ""
                                size: 13
                                weight: 600
                                customColor: Colors.primaryText
                            }
                        }

                        CustomToolTip {
                            content: btn.entry ? root.labelFor(btn.entry) : ""
                            visible: btnArea.containsMouse && !btn.named && root.labelFor(btn.entry ?? {}) !== ""
                        }

                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: root.pressedIndex = btn.slot
                            onReleased: root.pressedIndex = -1
                            onCanceled: root.pressedIndex = -1
                            onClicked: root.triggered(btn.slot)
                        }
                    }
                }
            }
        }
    }
}
