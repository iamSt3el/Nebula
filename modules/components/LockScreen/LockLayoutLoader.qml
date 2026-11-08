pragma ComponentBehavior: Bound

import QtQuick

Loader {
    id: root

    property string variant: "veil"
    property var context: null
    property bool preview: false
    property bool exiting: false
    property bool greeter: false
    property bool handoff: false
    property real handoffReveal: 1
    property bool handoffDate: false
    property var sources: ({})
    property url desk: ""
    property var cfg: root.greeter ? LockSession.greeterCfg : LockSession.lockCfg

    readonly property Item authField: root.item ? root.item.authField : null

    sourceComponent: {
        switch (LockCatalog.normalize(root.variant)) {
        case "bloom":    return cBloom
        case "deck":     return cDeck
        case "tessera":  return cTessera
        case "window":   return cWindow
        case "snapshot": return cSnapshot
        case "ring":     return cRing
        default:         return cVeil
        }
    }

    Component { id: cVeil;     LockLayoutVeil     { context: root.context; preview: root.preview; exiting: root.exiting; greeter: root.greeter; cfg: root.cfg; handoff: root.handoff; handoffReveal: root.handoffReveal; handoffDate: root.handoffDate } }
    Component { id: cBloom;    LockLayoutBloom    { context: root.context; preview: root.preview; exiting: root.exiting; greeter: root.greeter; cfg: root.cfg } }
    Component { id: cDeck;     LockLayoutDeck     { context: root.context; preview: root.preview; exiting: root.exiting; greeter: root.greeter; cfg: root.cfg } }
    Component { id: cTessera;  LockLayoutTessera  { context: root.context; preview: root.preview; exiting: root.exiting; greeter: root.greeter; cfg: root.cfg } }
    Component { id: cWindow;   LockLayoutWindow   { context: root.context; preview: root.preview; exiting: root.exiting; greeter: root.greeter; cfg: root.cfg; handoff: root.handoff; handoffReveal: root.handoffReveal; handoffDate: root.handoffDate } }
    Component { id: cRing;     LockLayoutRing     { context: root.context; preview: root.preview; exiting: root.exiting; greeter: root.greeter; cfg: root.cfg; handoff: root.handoff; handoffReveal: root.handoffReveal; handoffDate: root.handoffDate } }
    Component { id: cSnapshot; LockLayoutSnapshot { context: root.context; preview: root.preview; exiting: root.exiting; greeter: root.greeter; cfg: root.cfg; sources: root.sources; desk: root.desk } }
}
