import QtQuick
import qs.modules.utils
import qs.modules.settings
import qs.modules.customComponents

Item {
    id: root

    property Item hostBlock: null
    property var blockIds: []

    implicitWidth: col.implicitWidth + 24
    implicitHeight: col.implicitHeight + 24

    Item {
        id: proxy
        visible: false
        readonly property bool vertical: false
        readonly property real barH: Appearance.size.barHeight
        readonly property real iconSize: 0
        readonly property real contentBox: 0
        readonly property real maxWidth: -1
        readonly property real fixedWidth: 0
        readonly property bool editing: false
        readonly property bool bottomEdge: false
        readonly property var editor: null
        readonly property Item frame: root.hostBlock ? root.hostBlock.frame : null
        readonly property string panelKind: root.hostBlock ? root.hostBlock.panelKind : ""

        function opener() {
            return root.hostBlock ? root.hostBlock.itemFor("more") : null
        }
        function openPanel(k, item) {
            if (root.hostBlock)
                root.hostBlock.openPanel(k, proxy.opener())
        }
        function hoverOpen(k, item) {
        }
        function closePanel() {
            if (root.hostBlock)
                root.hostBlock.closePanel()
        }
        function openTrayOverflow(source, limit, clicked) {
            if (root.hostBlock)
                root.hostBlock.openTrayOverflow(proxy.opener(), limit, true)
        }
        function openTrayMenu(trayItem, source) {
            if (root.hostBlock)
                root.hostBlock.openTrayMenu(trayItem, proxy.opener())
        }
        function registerDrop() {
        }
        function appMenu() {
        }
        function appEntered() {
        }
        function appExited() {
        }
    }

    Column {
        id: col
        x: 12
        y: 12
        spacing: 8

        Repeater {
            model: root.blockIds

            Rectangle {
                id: row
                required property string modelData
                readonly property var info: BarLayout.blockById(row.modelData)
                visible: itemRow.implicitWidth > 0
                width: itemRow.implicitWidth + 16
                height: proxy.barH
                radius: height / 2
                color: Colors.surfaceContainerHigh

                Row {
                    id: itemRow
                    anchors.centerIn: parent
                    spacing: BarLayout.itemGap

                    Repeater {
                        model: row.info ? row.info.items : []

                        Loader {
                            id: cell
                            required property string modelData
                            anchors.verticalCenter: parent.verticalCenter
                            source: Qt.resolvedUrl(BarLayout.fileFor(cell.modelData))
                            visible: !!cell.item && cell.item.shown !== false
                            onLoaded: {
                                cell.item.host = proxy
                                if ("itemId" in cell.item)
                                    cell.item.itemId = cell.modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
