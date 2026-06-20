import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.modules.utils
import qs.modules.components.Bar
import qs.modules.settings
import qs.modules.components.AppLauncher
import qs.modules.components.ToolsWidget
import qs.modules.components.Setting
import qs.modules.components.Clipboard
import qs.modules.components.Notification
import qs.modules.components.Dock
import qs.modules.components.Osd
import qs.modules.components.Widgets
import qs.modules.services
import qs.modules.customComponents

PanelWindow {
    id: layout
    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 1080
    exclusiveZone: 40
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: (workspaces.active || utility.isTodoClicked) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: maskRect
        intersection: Intersection.Xor
        Region {
            x: workspaces.x
            y: workspaces.y
            width: workspaces.width
            height: workspaces.height
            intersection: Intersection.Subtract
        }

        Region {
            x: utility.x
            y: utility.y
            width: utility.container.width
            height: utility.container.height
            intersection: Intersection.Subtract
        }

        Region {
            x: clock.x
            y: clock.y
            width: clock.width
            height: clock.height
            intersection: Intersection.Subtract
        }
    }
    Rectangle {
        id: maskRect
        implicitHeight: parent.height
        implicitWidth: parent.width
        anchors.bottom: parent.bottom
        color: "transparent"
    }

    Item {
        id: root
        anchors.fill: parent
        property real disX: 18
        property real disY: 18
        property real radX: 18
        property real radY: 18
        property real lineDis: 4
        property real clockHeight: 0
        property real clockWidth: clock.width
        property real workspaceWidth: 100
        property real utilityWidth: 100
        property bool flatBarMode: SettingsConfig.general.flatBarMode ?? true

        // ── Flat bar path ───────────────────────────────────────────────────────
        // Truly flat bar (no stepped bridges). Sections expand downward when open:
        //   • clock expands when calendar is open (cH > wH)
        //   • utility expands when dashboard/panel is open (uH > wH)
        // showArc: workspace panel open — bridge arc at workspace right + utility left
        function buildFlatBarPath(dX, dY, rX, rY, wH, wW, showArc, cX, cW, cH, uX, uW, uH, isDashboard) {
            function A(sw, ex, ey) {
                return `A ${rX} ${rY} 0 0 ${sw} ${ex} ${ey} `;
            }
            function L(x, y) {
                return `L ${x} ${y} `;
            }
            const CW = 1, CCW = 0;

            let p = `M 0 ${wH + dY} `;
            p += A(CW, dX, wH);   // BL corner

            if (showArc) {
                // Workspace panel open: concave arc at workspace right, bridge, concave arc at utility left
                p += L(wW + dX, wH);
                p += A(CW, wW, wH - dY);
                p += L(uX - dX, wH - dY);
                p += A(CCW, uX, wH);              // now at (uX, wH)
                if (uH > wH + 2 * dY) {
                    p += L(uX, uH - dY);
                    if (isDashboard) {
                        p += A(CW, uX - dX, uH);
                        p += L(uX + uW, uH);
                    } else {
                        p += A(CCW, uX + dX, uH);
                        p += L(uX + uW - dX, uH);
                    }
                    p += A(CW, uX + uW, uH + dY);
                } else {
                    p += L(uX + uW - dX, wH);
                    p += A(CW, uX + uW, wH + dY);
                }
            } else {
                // Clock section — expand downward if calendar is open, else flat
                if (cH > wH + 2 * dY) {
                    p += L(cX - dX, wH);
                    p += A(CW, cX, wH + dY);   // outer corner going down
                    p += L(cX, cH - dY);   // clock left wall
                    p += A(CCW, cX + dX, cH);        // clock BL corner
                    p += L(cX + cW - dX, cH);        // clock bottom
                    p += A(CCW, cX + cW, cH - dY);   // clock BR corner
                    p += L(cX + cW, wH + dY);   // clock right wall (up)
                    p += A(CW, cX + cW + dX, wH);        // outer corner back to flat
                }
                // else: bar is flat through the clock area — no scallop

                // Utility section — expand downward if dashboard/panel is open
                if (uH > wH + 2 * dY) {
                    p += L(uX - dX, wH);
                    p += A(CW, uX, wH + dY);   // outer corner going down
                    p += L(uX, uH - dY);   // utility left wall
                    if (isDashboard) {
                        p += A(CW, uX - dX, uH);
                        p += L(uX + uW, uH);
                    } else {
                        p += A(CCW, uX + dX, uH);
                        p += L(uX + uW - dX, uH);
                    }
                    p += A(CW, uX + uW, uH + dY);
                } else {
                    p += L(uX + uW - dX, wH);
                    p += A(CW, uX + uW, wH + dY);
                }
            }

            p += L(uX + uW, 0);
            p += L(0, 0);
            p += L(0, wH + dY);
            return p;
        }

        // ── Stepped bar path ────────────────────────────────────────────────────
        // Builds the bar SVG path. Transition arcs between sections use (disY - lineDis)
        // as their vertical offset. When lineDis == disY the offset is 0 and those arcs
        // would bulge as semicircles; this function emits a straight L segment instead.
        function buildBarPath(dX, dY, rX, rY, lD, wH, wW, showArc, cX, cW, cH, uX, uW, uH, isDashboard) {
            const eD = dY - lD;  // effectiveDis: 0 = flat bar, dY = maximum step

            function A(sw, ex, ey) {
                return `A ${rX} ${rY} 0 0 ${sw} ${ex} ${ey} `;
            }
            function L(x, y) {
                return `L ${x} ${y} `;
            }
            // Transition: flat line when eD ≈ 0, proper arc otherwise
            function T(sw, ex, ey) {
                return eD < 0.1 ? L(ex, ey) : A(sw, ex, ey);
            }
            const CW = 1, CCW = 0;

            let p = `M 0 ${wH + dY} `;
            // bottom-left corner
            p += A(CW, dX, wH);
            // workspaces bottom edge + right-bottom corner
            if (showArc) {
                p += L(wW + dX, wH);
                p += A(CW, wW, wH - dY);
            } else {
                p += L(wW - dX, wH);
                p += A(CCW, wW, wH - dY);
            }
            // workspaces right wall up to transition point
            p += L(wW, dY);
            // ── TRANSITION: workspace → bridge
            p += T(CW, wW + dX, lD);
            // bridge across to clock
            p += L(cX - dX, lD);
            // ── TRANSITION: bridge → clock left
            p += T(CW, cX, dY);
            // clock left wall + bottom corners + bottom edge + right wall
            p += L(cX, cH - dY);
            p += A(CCW, cX + dX, cH);
            p += L(cX + cW - dX, cH);
            p += A(CCW, cX + cW, cH - dY);
            p += L(cX + cW, dY);
            // ── TRANSITION: clock → bridge
            p += T(CW, cX + cW + dX, lD);
            // bridge across to utility
            p += L(uX - dX, lD);
            // ── TRANSITION: bridge → utility left
            p += T(CW, uX, dY);
            // utility left wall + bottom corners + bottom edge + right-bottom corner
            p += L(uX, uH - dY);
            if (isDashboard) {
                p += A(CW, uX - dX, uH);
                p += L(uX + uW, uH);
            } else {
                p += A(CCW, uX + dX, uH);
                p += L(uX + uW - dX, uH);
            }
            p += A(CW, uX + uW, uH + dY);
            // utility right wall up, top edge, left wall back to start
            p += L(uX + uW, 0);
            p += L(0, 0);
            p += L(0, wH + dY);
            return p;
        }

        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: "#000000"
                PathSvg {
                    path: root.flatBarMode ? root.buildFlatBarPath(root.disX, root.disY, root.radX, root.radY, workspaces.height, workspaces.width, workspaces.showArc, clock.x, clock.width, clock.height, utility.x, utility.width, utility.height, utility.isDashboard) : root.buildBarPath(root.disX, root.disY, root.radX, root.radY, root.lineDis, workspaces.height, workspaces.width, workspaces.showArc, clock.x, clock.width, clock.height, utility.x, utility.width, utility.height, utility.isDashboard)
                }
            }
        }

        Workspaces {
            id: workspaces
        }

        Clock {
            id: clock
        }

        Utility {
            id: utility
        }
    }

    property bool isSettingClicked: false
    property bool showOsd: false

    GlobalShortcut {
        name: "dashboard"
        onPressed: {
            if (Hyprland.focusedMonitor.name === layout.screen.name) {
                utility.isClicked = !utility.isClicked;
            }
        }
    }

    GlobalShortcut {
        name: "notification"
        onPressed: {
            if (Hyprland.focusedMonitor.name === layout.screen.name) {
                utility.isNotificationClicked = !utility.isNotificationClicked;
            }
        }
    }

    GlobalShortcut {
        name: "weather"
        onPressed: {
            if (Hyprland.focusedMonitor.name === layout.screen.name) {
                utility.isWeatherPanelClicked = !utility.isWeatherPanelClicked;
            }
        }
    }

    NotificationPanel {}
}
