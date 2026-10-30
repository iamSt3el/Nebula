pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property var variants: [
        { value: "veil",     label: "Veil",     role: "Default",    blurb: "Sharp wallpaper, clock and sign-in on a bottom scrim", backdrop: "veil", clear: true, bareWall: true, handoff: true, flight: "arc", flyDelay: 260, flyIn: 950, flyOut: 760, shadeDelay: 640, handBack: 40, clearBack: 500 },
        { value: "bloom",    label: "Bloom",    role: "Shapes",     blurb: "The time set in morphing Material shapes",              backdrop: "bloom" },
        { value: "deck",     label: "Deck",     role: "Music",      blurb: "Album art in a cookie with the progress on its edge",  backdrop: "deck" },
        { value: "tessera",  label: "Tessera",  role: "Tiles",      blurb: "A mosaic of Material tone tiles",                      backdrop: "tessera" },
        { value: "window",   label: "Window",   role: "Shape",      blurb: "Your wallpaper gathers into a Material cookie",        backdrop: "window", deskBlur: false, clear: true, handoff: true, flight: "glide", flyDelay: 100, flyIn: 900, flyOut: 700, handBack: 0, clearBack: 440, deskFade: 700, deskBack: 0 },
        { value: "snapshot", label: "Snapshot", role: "Desktop",    blurb: "Your desktop shrinks into a card of where you left off", backdrop: "carry", carry: true, deskBlur: false, deskFade: 360, deskBack: 560 }
    ]

    readonly property string fallback: "veil"

    readonly property var _legacy: ({
        "aurora": "veil", "terminal": "veil", "marquee": "veil", "seijaku": "veil",
        "orbit": "veil", "darkroom": "veil", "tear": "veil", "gather": "snapshot", "playing": "snapshot",
        "yakou": "veil", "kaisatsu": "veil", "broadsheet": "veil",
        "centered": "veil", "sheet": "veil", "card": "veil", "split": "veil",
        "panel": "veil", "frosted": "veil", "minimal": "veil", "halo": "veil"
    })

    function normalize(value) {
        const legacy = root._legacy[value ?? ""]
        if (legacy !== undefined)
            return legacy
        for (let i = 0; i < root.variants.length; i++)
            if (root.variants[i].value === value)
                return value
        return root.fallback
    }

    function indexOf(value) {
        const v = root.normalize(value)
        for (let i = 0; i < root.variants.length; i++)
            if (root.variants[i].value === v)
                return i
        return 0
    }

    function entry(value) {
        return root.variants[root.indexOf(value)]
    }

    function backdropFor(value) {
        return root.entry(value).backdrop
    }
}
