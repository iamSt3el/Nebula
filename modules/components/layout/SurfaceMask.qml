import Quickshell
import QtQuick

Region {
    id: mask

    property Item surface: null
    readonly property bool live: !!mask.surface && mask.surface.visible

    x: 0
    y: 0
    width: 0
    height: 0
    intersection: Intersection.Subtract

    readonly property rect none: Qt.rect(0, 0, 0, 0)

    function blockRect(i) {
        const b = mask.live ? (mask.surface.visibleBlocks[i] ?? null) : null
        if (!b)
            return mask.none
        return mask.surface.dockHidden ? mask.surface.hiddenRect(b) : mask.surface.blockRect(b)
    }

    function tabRect(i) {
        const t = mask.live ? (mask.surface.openTabs[i] ?? null) : null
        return t ? mask.surface.tabRect(t) : mask.none
    }

    component BlockSlot: Region {
        required property int index
        readonly property rect r: mask.blockRect(index)
        x: r.x
        y: r.y
        width: r.width
        height: r.height
        intersection: Intersection.Combine
    }

    component TabSlot: Region {
        required property int index
        readonly property rect r: mask.tabRect(index)
        x: r.x
        y: r.y
        width: r.width
        height: r.height
        intersection: Intersection.Combine
    }

    BlockSlot { index: 0 }
    BlockSlot { index: 1 }
    BlockSlot { index: 2 }
    BlockSlot { index: 3 }
    BlockSlot { index: 4 }
    BlockSlot { index: 5 }
    BlockSlot { index: 6 }
    BlockSlot { index: 7 }
    BlockSlot { index: 8 }
    BlockSlot { index: 9 }
    BlockSlot { index: 10 }
    BlockSlot { index: 11 }
    BlockSlot { index: 12 }
    BlockSlot { index: 13 }
    BlockSlot { index: 14 }
    BlockSlot { index: 15 }
    BlockSlot { index: 16 }
    BlockSlot { index: 17 }
    BlockSlot { index: 18 }
    BlockSlot { index: 19 }
    BlockSlot { index: 20 }
    BlockSlot { index: 21 }
    BlockSlot { index: 22 }
    BlockSlot { index: 23 }
    TabSlot { index: 0 }
    TabSlot { index: 1 }
    TabSlot { index: 2 }
    TabSlot { index: 3 }
}
