import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.utils
import qs.modules.settings

Item {
    id: root

    visible: false

    readonly property string cli: Quickshell.shellDir + "/bin/nebula"
    readonly property string image: Colors.sourceWallpaper || Colors.wallpaper || ""
    readonly property var schemes: ["scheme-neutral", "scheme-content", "scheme-vibrant"]

    property var palettes: ({})
    property string loadedFor: ""

    readonly property var live: ({
        primary: Colors.primary,
        primaryContainer: Colors.primaryContainer,
        secondary: Colors.secondary,
        secondaryContainer: Colors.secondaryContainer,
        tertiary: Colors.tertiary,
        tertiaryContainer: Colors.tertiaryContainer,
        surface: Colors.surface,
        surfaceContainer: Colors.surfaceContainer,
        surfaceContainerHigh: Colors.surfaceContainerHigh,
        surfaceText: Colors.surfaceText
    })

    function get(scheme, mode) {
        const cur = (SettingsConfig.theme.matugenScheme ?? "scheme-content") === scheme
                 && (SettingsConfig.theme.matugenTheme ?? "dark") === mode
        if (cur)
            return root.live
        return root.palettes[scheme + "|" + mode] ?? null
    }

    function load() {
        if (root.image === "" || runner.running)
            return
        if (root.loadedFor === root.image)
            return
        root.palettes = ({})
        root.loadedFor = root.image
        const pairs = []
        for (const s of root.schemes)
            for (const m of ["dark", "light"])
                pairs.push(s + "|" + m)
        runner.command = ["sh", "-c",
            'cli=$1; img=$2; shift 2; for p in "$@"; do ( out=$("$cli" wallpaper preview "$img" "$img" "${p%|*}" "${p#*|}" 2>/dev/null | tr -d "\\n"); printf "%s\\t%s\\n" "$p" "$out" ) & done; wait',
            "sh", root.cli, root.image].concat(pairs)
        runner.running = true
    }

    onImageChanged: settle.restart()

    Timer {
        id: settle
        interval: 700
        onTriggered: root.load()
    }

    Process {
        id: runner
        stdout: SplitParser {
            onRead: data => {
                const tab = data.indexOf("\t")
                if (tab < 0)
                    return
                try {
                    const next = Object.assign({}, root.palettes)
                    next[data.slice(0, tab)] = JSON.parse(data.slice(tab + 1))
                    root.palettes = next
                } catch (e) {
                    console.warn("[SetupPalettes] unreadable preview for", data.slice(0, tab))
                }
            }
        }
        onExited: {
            if (root.loadedFor !== root.image)
                Qt.callLater(root.load)
        }
    }
}
