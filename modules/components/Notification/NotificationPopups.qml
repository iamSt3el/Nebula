import QtQuick
import Quickshell
import qs.modules.utils
import qs.modules.settings
import qs.modules.services
import qs.modules.components.Bar

Item {
    id: popups

    property var surfaces: []
    readonly property Item appsSurface: {
        BarLayout.allBlocks
        const hasApps = s => BarLayout.blocksOn(s.edge).some(b => b.items.some(i => i.split("#")[0] === "dockApps"))
        return popups.surfaces.find(s => s && s.visible && hasApps(s))
            ?? popups.surfaces.find(s => s && s.visible && s.edge === BarLayout.sysEdge && s.present) ?? null
    }

    property string mode: "corner"
    readonly property string style: popups.mode
    readonly property bool enabled_: popups.style === "icon" && popups.visible
    readonly property var live: popups.enabled_ ? [...ServiceNotification.popups].reverse() : []
    readonly property var front: popups.live.length > 0 ? popups.live[0] : null
    readonly property bool active: popups.front !== null
    property var shown: null
    property bool hovered: false
    readonly property rect hit: loader.item && loader.item.hit ? loader.item.hit : Qt.rect(0, 0, 0, 0)

    onFrontChanged: if (popups.front) popups.shown = popups.front

    function ease(on) {
        return on ? M3Motion.spatialCurve("default") : [0.3, 0.0, 0.8, 0.15, 1, 1]
    }

    function appKeyFor(n) {
        if (!n) return ""
        GlobalStates.dockIconsVersion
        const map = GlobalStates.dockIconItems
        const keys = Object.keys(map)
        const cands = []
        const de = (n.notification?.desktopEntry ?? "").toLowerCase()
        if (de !== "") cands.push(de)
        const an = (n.appName ?? "").toLowerCase()
        if (an !== "") {
            cands.push(an)
            cands.push(an.replace(/\s+/g, "-"))
            const hit = DesktopEntries.heuristicLookup(n.appName)
            if (hit && hit.id) cands.push(String(hit.id).toLowerCase())
        }
        for (const c of cands) {
            for (const k of keys) {
                if (k === c || k.endsWith("." + c) || c.endsWith("." + k) || k.replace(/\.desktop$/, "") === c)
                    return k
            }
        }
        return ""
    }

    Binding {
        target: ServiceNotification
        property: "popupsPaused"
        value: popups.hovered && popups.active
        when: popups.style === "icon"
    }

    Binding {
        target: GlobalStates
        property: "dockPeek"
        value: popups.active && popups.style === "icon"
    }

    Loader {
        id: loader
        anchors.fill: parent
        active: popups.style === "icon"
        sourceComponent: iconComp
    }

    Component { id: iconComp; NotifIconBubble { host: popups } }
}
