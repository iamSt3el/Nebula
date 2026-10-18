import QtQuick
import QtQuick.Layouts
import qs.modules.utils

Rectangle {
    id: root

    // Marker so adjacent siblings can detect this as a card
    readonly property bool isCustomCard: true

    property int topRadius: 20
    property int bottomRadius: 20
    // Set to false to skip auto-detection and use explicit topRadius/bottomRadius
    property bool autoRadius: true

    // Children placed directly inside CustomCard go into the inner ColumnLayout
    default property alias content: _layout.data

    color: Colors.surfaceContainerHigh

    topLeftRadius:     topRadius
    topRightRadius:    topRadius
    bottomLeftRadius:  bottomRadius
    bottomRightRadius: bottomRadius

    Layout.fillWidth: true
    implicitHeight: _layout.implicitHeight + 28

    // Check only the immediately adjacent siblings.
    // - If the item directly above is also a CustomCard → flatten the top (radius 5)
    // - If the item directly below is also a CustomCard → flatten the bottom (radius 5)
    // This means cards with ANY non-card element between them stay fully rounded,
    // while truly consecutive CustomCards form a grouped stack automatically.
    Component.onCompleted: { if (autoRadius) Qt.callLater(_updateRadius) }
    onVisibleChanged: Qt.callLater(root._regroup)

    function _neighbour(dir) {
        if (!parent) return null
        const ch = parent.children
        let i = -1
        for (let k = 0; k < ch.length; k++) {
            if (ch[k] === root) { i = k; break }
        }
        if (i < 0) return null
        for (i += dir; i >= 0 && i < ch.length; i += dir) {
            if (ch[i].visible)
                return ch[i]
        }
        return null
    }

    function _regroup() {
        if (!root.parent) return
        if (root.autoRadius) root._updateRadius()
        for (const dir of [-1, 1]) {
            if (!root.parent) return
            const ch = root.parent.children
            let i = -1
            for (let k = 0; k < ch.length; k++) {
                if (ch[k] === root) { i = k; break }
            }
            for (i += dir; i >= 0 && i < ch.length; i += dir) {
                const n = ch[i]
                if (n.isCustomCard === true && n.autoRadius)
                    n._updateRadius()
                if (n.visible)
                    break
            }
        }
    }

    function _updateRadius() {
        if (!parent) return
        const prev = root._neighbour(-1)
        const next = root._neighbour(1)
        root.topRadius    = prev && prev.isCustomCard === true ? 5 : 20
        root.bottomRadius = next && next.isCustomCard === true ? 5 : 20
    }

    ColumnLayout {
        id: _layout
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14
    }
}
