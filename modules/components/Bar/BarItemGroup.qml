import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root

    property Item host: null
    property string itemId: ""

    readonly property var members: BarLayout.groupMembers(root.itemId).filter(i => Features.barItemOn(i))
    readonly property real gap: BarLayout.chipGap(root.itemId,
                                                  BarLayout.itemGap > 0 ? BarLayout.itemGap : 6)
    readonly property bool shown: root.shownCount > 0 || root.editing
    readonly property bool placeholder: root.shownCount === 0

    readonly property real setHeight: BarLayout.itemStyle(root.itemId, "minH", 0)
    readonly property real contentBox: root.setHeight > 0
        ? Math.max(12, root.setHeight - BarLayout.chipInset * 2) : 0

    readonly property real iconSize: 0
    readonly property bool editing: !!root.host && root.host.editing === true
    readonly property bool vertical: !!root.host && root.host.vertical === true
    readonly property bool verticalReady: true
    readonly property Item frame: root.host ? root.host.frame : null
    readonly property string panelKind: root.host ? root.host.panelKind : ""

    function hoverOpen(kind, item) {
        if (root.host)
            root.host.hoverOpen(kind, item)
    }

    function openPanel(kind, item) {
        if (root.host)
            root.host.openPanel(kind, item)
    }

    function closePanel() {
        if (root.host)
            root.host.closePanel()
    }

    function openTrayOverflow(source, limit, clicked) {
        if (root.host && root.host.openTrayOverflow)
            root.host.openTrayOverflow(source, limit, clicked)
    }

    function openTrayMenu(trayItem, source) {
        if (root.host && root.host.openTrayMenu)
            root.host.openTrayMenu(trayItem, source)
    }

    readonly property int shownCount: {
        let n = 0
        for (let i = 0; i < rep.count; i++) {
            const m = rep.itemAt(i)
            if (m && m.memberShown)
                n++
        }
        return n
    }

    implicitWidth: Math.max(row.implicitWidth, root.placeholder ? 34 : 0)
    implicitHeight: Math.max(row.implicitHeight, root.placeholder ? 26 : 0)

    Grid {
        id: row
        anchors.centerIn: parent
        spacing: root.gap
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Repeater {
            id: rep
            model: root.members

            delegate: Item {
                id: member

                required property string modelData
                readonly property bool loaded: memberLoader.status === Loader.Ready && memberLoader.item !== null
                readonly property bool memberShown: member.loaded && memberLoader.item.shown

                visible: member.memberShown
                width: member.memberShown ? memberLoader.width : 0
                height: member.memberShown ? memberLoader.height : 0

                Rectangle {
                    anchors.fill: memberLoader
                    visible: BarLayout.tintOwner(member.modelData) !== ""
                    radius: Math.min(width, height) / 2
                    color: BarLayout.tintHover(member.modelData)
                    opacity: memberHover.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                HoverHandler {
                    id: memberHover
                }

                Loader {
                    id: memberLoader
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl(BarLayout.fileFor(member.modelData))
                    width: item ? item.implicitWidth : 0
                    height: item ? item.implicitHeight : 0
                    onLoaded: {
                        item.host = root
                        if ("itemId" in item)
                            item.itemId = member.modelData
                    }
                }
            }
        }
    }

    MaterialIconSymbol {
        anchors.centerIn: parent
        visible: root.placeholder
        content: "add_circle"
        iconSize: 16
        customColor: Colors.outline
        opacity: 0.6
    }
}
