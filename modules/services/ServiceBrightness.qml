pragma Singleton
pragma ComponentBehavior: Bound

// From https://github.com/caelestia-dots/shell with modifications.
// License: GPLv3

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

/**
 * For managing brightness of monitors. Supports both brightnessctl and ddcutil.
 */
Singleton {
    id: root

    signal brightnessChanged()

    property var ddcMonitors: []
    property var changedMonitor: null
    readonly property list<BrightnessMonitor> monitors: Quickshell.screens.map(screen => monitorComp.createObject(root, {
        screen
    }))

    function presetLabel(value: int): string {
        return ({
                1: "sRGB",
                2: "Native",
                3: "4000K",
                4: "5000K",
                5: "6500K",
                6: "7500K",
                7: "8200K",
                8: "9300K",
                9: "10000K",
                10: "11500K",
                11: "User",
                12: "User 2",
                13: "User 3"
            })[value] ?? ("0x" + value.toString(16));
    }

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.screen === screen);
    }

    function increaseBrightness(): void {
        const focusedName = Hyprland.focusedMonitor.name;
        const monitor = monitors.find(m => focusedName === m.screen.name);
        if (monitor)
            monitor.setBrightness(monitor.brightness + 0.05);
    }

    function decreaseBrightness(): void {
        const focusedName = Hyprland.focusedMonitor.name;
        const monitor = monitors.find(m => focusedName === m.screen.name);
        if (monitor)
            monitor.setBrightness(monitor.brightness - 0.05);
    }

    reloadableId: "brightness"

    onMonitorsChanged: {
        ddcMonitors = [];
        ddcProc.running = true;
    }

    Process {
        id: ddcProc

        command: ["ddcutil", "detect", "--brief"]
        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => {
                if (data.startsWith("Display ")) {
                    const lines = data.split("\n").map(l => l.trim());
                    root.ddcMonitors.push({
                        model: lines.find(l => l.startsWith("Monitor:")).split(":")[2],
                        busNum: lines.find(l => l.startsWith("I2C bus:")).split("/dev/i2c-")[1]
                    });
                }
            }
        }
        onExited: root.ddcMonitorsChanged()
    }

    component BrightnessMonitor: QtObject {
        id: monitor

        required property ShellScreen screen
        readonly property bool isDdc: root.ddcMonitors.some(m => m.model === screen.model)
        readonly property string busNum: root.ddcMonitors.find(m => m.model === screen.model)?.busNum ?? ""
        property real brightness
        property bool ready: false
        property bool hasContrast: false
        property real contrast: 0
        property int contrastMax: 100
        property int colorPreset: -1
        property var colorPresets: []

        onBrightnessChanged: {
            if (monitor.ready) {
                root.changedMonitor = monitor;
                root.brightnessChanged();
            }
        }

        function initialize() {
            monitor.ready = false;
            monitor.hasContrast = false;
            monitor.colorPreset = -1;
            monitor.colorPresets = [];
            monitor.read(true);
        }

        function read(withCaps: bool): void {
            if (isDdc) {
                const caps = withCaps ? `; ddcutil -b ${busNum} capabilities --brief` : "";
                initProc.command = ["sh", "-c", `ddcutil -b ${busNum} getvcp 10 12 14 --brief${caps}`];
            } else {
                initProc.command = ["sh", "-c", `echo "VCP 10 C $(brightnessctl g) $(brightnessctl m)"`];
            }
            initProc.running = true;
        }

        function parseLine(line: string): void {
            const capsAt = line.indexOf("vcp(");
            if (capsAt >= 0) {
                const m = line.slice(capsAt).match(/[( ]14\(([0-9A-Fa-f ]+)\)/);
                monitor.colorPresets = m ? m[1].trim().split(/\s+/).map(v => parseInt(v, 16)) : [];
                return;
            }
            const parts = line.trim().split(/\s+/);
            if (parts[0] !== "VCP")
                return;
            const code = parts[1].toLowerCase();
            if (code === "10" && parts[2] === "C") {
                monitor.brightness = parseInt(parts[3]) / parseInt(parts[4]);
                monitor.ready = true;
            } else if (code === "12" && parts[2] === "C") {
                monitor.contrastMax = parseInt(parts[4]);
                monitor.contrast = parseInt(parts[3]) / monitor.contrastMax;
                monitor.hasContrast = true;
            } else if (code === "14" && parts[2] === "SNC") {
                monitor.colorPreset = parseInt(parts[3].replace(/^x/, ""), 16);
            }
        }

        readonly property Process initProc: Process {
            stdout: SplitParser {
                onRead: data => monitor.parseLine(data)
            }
        }

        property var pending: ({})
        property bool rereadAfterWrite: false

        function setBrightness(value: real): void {
            value = Math.max(0.01, Math.min(1, value));
            const rounded = Math.round(value * 100);
            if (Math.round(brightness * 100) === rounded)
                return;
            brightness = value;
            monitor.queue("10", isDdc ? String(rounded) : `${rounded}%`);
        }

        function setContrast(value: real): void {
            if (!isDdc || !hasContrast)
                return;
            value = Math.max(0, Math.min(1, value));
            const raw = Math.round(value * contrastMax);
            if (Math.round(contrast * contrastMax) === raw)
                return;
            contrast = value;
            monitor.queue("12", String(raw));
        }

        function setColorPreset(value: int): void {
            if (!isDdc || value === colorPreset)
                return;
            colorPreset = value;
            monitor.rereadAfterWrite = true;
            monitor.queue("14", "0x" + value.toString(16).padStart(2, "0"));
        }

        function queue(code: string, value: string): void {
            monitor.pending[code] = value;
            monitor.flush();
        }

        function flush(): void {
            if (monitor.writer.running)
                return;
            const code = Object.keys(monitor.pending)[0];
            if (code === undefined) {
                if (monitor.rereadAfterWrite && !monitor.initProc.running) {
                    monitor.rereadAfterWrite = false;
                    monitor.read(false);
                }
                return;
            }
            const v = monitor.pending[code];
            delete monitor.pending[code];
            monitor.writer.command = isDdc ? ["ddcutil", "-b", busNum, "--noverify", "setvcp", code, v] : ["brightnessctl", "s", v, "--quiet"];
            monitor.writer.running = true;
        }

        readonly property Process writer: Process {
            onExited: monitor.flush()
        }

        Component.onCompleted: {
            initialize();
        }

        onBusNumChanged: {
            initialize();
        }
    }

    Component {
        id: monitorComp

        BrightnessMonitor {}
    }

    IpcHandler {
        target: "brightness"

        function increment() {
            onPressed: root.increaseBrightness()
        }

        function decrement() {
            onPressed: root.decreaseBrightness()
        }
    }

    GlobalShortcut {
        name: "brightnessIncrease"
        description: "Increase brightness"
        onPressed: root.increaseBrightness()
    }

    GlobalShortcut {
        name: "brightnessDecrease"
        description: "Decrease brightness"
        onPressed: root.decreaseBrightness()
    }
}
