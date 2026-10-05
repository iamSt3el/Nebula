pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.modules.settings
import qs.modules.services
import qs.modules.utils
import "BarOps.js" as BarOps

Singleton {
    id: root

    readonly property var groups: ["Core", "Dock", "Stats", "Toggles", "Launchers", "Layout"]

    readonly property var statStyleChoices: [
        { "value": "text",      "label": "Text",           "icon": "text_fields" },
        { "value": "dial",      "label": "Tick dial",      "icon": "speed" },
        { "value": "rings",     "label": "Twin ring",      "icon": "radio_button_checked" },
        { "value": "cookie",    "label": "Cookie",         "icon": "cookie" },
        { "value": "liquid",    "label": "Liquid",         "icon": "water_drop" },
        { "value": "speedo",    "label": "Speedo",         "icon": "avg_pace" },
        { "value": "orbit",     "label": "Orbit",          "icon": "orbit" },
        { "value": "radial",    "label": "Radial history", "icon": "sunny" },
        { "value": "segring",   "label": "Segment ring",   "icon": "donut_large" },
        { "value": "splittrack", "label": "Split track",    "icon": "linear_scale" },
        { "value": "tag",       "label": "Tagged track",   "icon": "label" },
        { "value": "underline", "label": "Underline",      "icon": "format_underlined" },
        { "value": "capsules",  "label": "Capsules",       "icon": "view_week" },
        { "value": "rising",    "label": "Rising cells",   "icon": "signal_cellular_alt" },
        { "value": "ruler",     "label": "Ruler",          "icon": "straighten" },
        { "value": "dots",      "label": "Dot matrix",     "icon": "grid_on" },
        { "value": "heat",      "label": "Heat strip",     "icon": "view_column" },
        { "value": "thumb",     "label": "Thumb",          "icon": "toggle_on" },
        { "value": "labelbar",  "label": "Label pill",     "icon": "battery_horiz_050" }
    ]
    function statStyleWith(extra) {
        return { "key": "style", "label": "Style", "type": "grid", "default": "text",
                 "choices": root.statStyleChoices.concat(extra) }
    }
    readonly property var statStyle: root.statStyleWith([])
    readonly property var showIconOpt: { "key": "showIcon", "label": "Show icon", "type": "toggle", "default": true }
    readonly property var showValueOpt: { "key": "showValue", "label": "Show value", "type": "toggle", "default": true }
    readonly property var showLabelOpt: { "key": "showLabel", "label": "Show label", "type": "toggle", "default": false }
    readonly property var dockShowOpt: {
        "key": "show", "label": "Show", "type": "grid", "default": "all",
        "choices": [
            { "value": "all",      "label": "All",      "icon": "apps" },
            { "value": "pinned",   "label": "Pinned",   "icon": "push_pin" },
            { "value": "unpinned", "label": "Running",  "icon": "play_circle" },
            { "value": "idle",     "label": "Idle",     "icon": "pause_circle" }
        ]
    }

    readonly property var colorRoleOpt: {
        "key": "role", "label": "Colour", "type": "grid", "default": "primary",
        "choices": [
            { "value": "primary",     "label": "Primary" },
            { "value": "secondary",   "label": "Secondary" },
            { "value": "tertiary",    "label": "Tertiary" },
            { "value": "outline",     "label": "Outline" },
            { "value": "surfaceText", "label": "Text" }
        ]
    }

    function musicOptions(style) {
        return [{ key: "style", label: "Style", type: "grid", default: style,
                  choices: [{ value: "pill",    label: "Transport", icon: "skip_next" },
                            { value: "develop", label: "Develop",   icon: "filter_b_and_w" },
                            { value: "drop",    label: "Drop",      icon: "water_drop" },
                            { value: "buttons", label: "Buttons",   icon: "view_week" },
                            { value: "shelf",   label: "Shelf",     icon: "shelves" },
                            { value: "counter", label: "Counter",   icon: "timer" },
                            { value: "shape",   label: "Shape",     icon: "interests" }] },
                { key: "panel", label: "Panel", type: "choice", default: "match",
                  choices: [{ value: "match", label: "Same as style" }, { value: "side", label: "Side by side" },
                            { value: "develop", label: "Develop" }, { value: "drop", label: "Drop" },
                            { value: "buttons", label: "Buttons" }, { value: "shelf", label: "Shelf" },
                            { value: "counter", label: "Counter" }, { value: "shape", label: "Shape" }] },
                { key: "hideIdle", label: "Hide when nothing plays", type: "toggle", default: false }]
    }

    function roleColor(name) {
        switch (name) {
        case "secondary":   return Colors.secondary
        case "tertiary":    return Colors.tertiary
        case "outline":     return Colors.outline
        case "surfaceText": return Colors.surfaceText
        }
        return Colors.primary
    }

    readonly property var catalog: [
        { id: "workspaces",    label: "Workspaces",    icon: "view_week",            group: "Core",
          options: [{ key: "style", label: "Style", type: "grid", default: "pill",
                      choices: [{ value: "pill",    label: "Pill",      icon: "view_week" },
                                { value: "shapes",  label: "Shapes",    icon: "interests" },
                                { value: "worm",    label: "Worm",      icon: "more_horiz" },
                                { value: "goo",     label: "Goo",       icon: "bubble_chart" },
                                { value: "bounce",  label: "Bounce",    icon: "sports_basketball" },
                                { value: "numbers", label: "Numbers",   icon: "pin" },
                                { value: "kanji",   label: "Kanji",     icon: "translate" },
                                { value: "lanterns", label: "Lanterns", icon: "light" },
                                { value: "house",   label: "House",     icon: "cottage" },
                                { value: "stars",   label: "Stars",     icon: "auto_awesome" },
                                { value: "map",     label: "Window map", icon: "dashboard" },
                                { value: "dial",    label: "Dial",      icon: "speed" },
                                { value: "ring",    label: "Segment ring", icon: "donut_large" },
                                { value: "viewfinder", label: "Viewfinder", icon: "center_focus_weak" }] },
                    { key: "size", label: "Size (%)", type: "slider", min: 100, step: 10, default: 100,
                      max: Math.max(100, Math.floor((Appearance.size.barHeight - 4) / 3) * 10),
                      sub: "Grows up to the bar's height (" + Appearance.size.barHeight + " px). Raise the bar height to go bigger." },
                    { key: "numbers", label: "Show numbers", type: "toggle", setting: "showWorkspaceNumbers", default: false,
                      onlyIf: { key: "style", values: ["pill"] } }] },
        { id: "windowTitle",   label: "Window title",  icon: "web_asset",            group: "Core", surfaces: ["bar"],
          options: [{ key: "lines", label: "Lines", type: "choice", default: "two",
                      choices: [{ value: "two", label: "Two" }, { value: "one", label: "One" }] },
                    { key: "width", label: "Width", type: "slider", min: 100, max: 360, step: 20, default: 160, auto: "Fit text" },
                    { key: "icon", label: "Icon", type: "choice", default: "app",
                      choices: [{ value: "app", label: "App icon" }, { value: "generic", label: "Generic" }] },
                    { key: "tint", label: "Tinted chip", type: "toggle", default: false }] },
        { id: "clock",         label: "Clock",         icon: "schedule",             group: "Core",
          options: [{ key: "style", label: "Style", type: "grid", default: "display",
                      choices: [{ value: "display",   label: "Display",     icon: "schedule" },
                                { value: "inline",    label: "Time · Date", icon: "more_horiz" },
                                { value: "stack",     label: "Stacked",     icon: "view_agenda" },
                                { value: "datefirst", label: "Date first",  icon: "today" },
                                { value: "twotone",   label: "Two tone",    icon: "contrast" },
                                { value: "ampm",      label: "AM/PM",       icon: "wb_sunny" },
                                { value: "tab",       label: "Day tab",     icon: "label" },
                                { value: "tiles",     label: "Tiles",       icon: "grid_view" },
                                { value: "side",      label: "Side date",   icon: "vertical_split" },
                                { value: "mono",      label: "Seconds",     icon: "timer" },
                                { value: "long",      label: "Long form",   icon: "notes" }] },
                    { key: "use24", label: "24-hour", type: "toggle", default: false },
                    { key: "panel", label: "Calendar panel", type: "grid", default: "rail",
                      choices: [{ value: "rail",   label: "Date rail", icon: "view_sidebar" },
                                { value: "sheet",  label: "Day sheet", icon: "event_note" },
                                { value: "weeks",  label: "Weeks",     icon: "calendar_view_week" },
                                { value: "shapes", label: "Shapes",    icon: "interests" }] },
                    { key: "live", label: "Live island (volume, notifications, charging)", type: "toggle", default: false },
                    { key: "dndBadge", label: "Moon when Do not disturb is on", type: "toggle", default: true }] },
        { id: "music",         label: "Music",         icon: "music_note",           group: "Core",
          options: root.musicOptions("pill") },
        { id: "rec",           label: "Recording",     icon: "screen_record",        group: "Core",
          options: [{ key: "showTime", label: "Show timer", type: "toggle", default: true }] },
        { id: "tray",          label: "System tray",   icon: "apps",                 group: "Core", surfaces: ["bar"],
          options: [{ key: "visible", label: "Visible icons", type: "slider", min: 1, max: 8, step: 1, default: 3, auto: "All" }] },
        { id: "weather",       label: "Weather",       icon: "partly_cloudy_day",    group: "Core",
          options: [{ key: "showIcon", label: "Show icon", type: "toggle", default: true }] },
        { id: "volume",        label: "Volume",        icon: "volume_up",            group: "Core",
          options: [{ key: "style", label: "Style", type: "choice", default: "icon",
                      choices: [{ value: "icon", label: "Icon" }, { value: "fill", label: "Fill" }] },
                    { key: "showPercent", label: "Show percentage", type: "toggle", default: true,
                      onlyIf: { key: "style", values: ["icon"] } }] },
        { id: "brightness",    label: "Brightness",    icon: "brightness_6",         group: "Core",
          options: [{ key: "style", label: "Style", type: "choice", default: "icon",
                      choices: [{ value: "icon", label: "Icon" }, { value: "fill", label: "Fill" }] },
                    { key: "showPercent", label: "Show percentage", type: "toggle", default: true,
                      onlyIf: { key: "style", values: ["icon"] } }] },
        { id: "powerMode",     label: "Power mode",    icon: "energy_savings_leaf",  group: "Core", options: [root.showLabelOpt] },
        { id: "wifi",         label: "Network",       icon: "wifi",                 group: "Core" },
        { id: "bluetooth",     label: "Bluetooth",     icon: "bluetooth",            group: "Core" },
        { id: "notifications", label: "Notifications", icon: "notifications",        group: "Core",
          options: [{ key: "popupStyle", label: "Popups", type: "choice", setting: "notifPopupStyle", default: "corner",
                      choices: [{ value: "corner", label: "Corner" }, { value: "bar", label: "Bar tab" },
                                { value: "dock", label: "Dock toast" }, { value: "icon", label: "Icon bubble" }] }] },
        { id: "battery",       label: "Battery",       icon: "battery_android_full", group: "Core",
          options: [{ key: "style", label: "Style", type: "choice", default: "icon",
                      choices: [{ value: "icon", label: "Icon" }, { value: "fill", label: "Fill" }] },
                    { key: "showPercent", label: "Show percentage", type: "toggle", default: false,
                      onlyIf: { key: "style", values: ["icon"] } }] },
        { id: "status",        label: "Status cluster", icon: "tune",               group: "Core",
          options: [{ key: "privacy", label: "Privacy dots (mic, screen share)", type: "toggle", default: true },
                    { key: "battery", label: "Battery", type: "toggle", default: true }] },
        { id: "privacy",       label: "Privacy",       icon: "privacy_tip",          group: "Core" },
        { id: "keyboard",      label: "Keyboard",      icon: "keyboard",             group: "Core",
          options: [{ key: "layout", label: "Show layout", type: "toggle", default: true },
                    { key: "caps", label: "Show caps lock", type: "toggle", default: true }] },
        { id: "sun",           label: "Sun arc",       icon: "wb_twilight",          group: "Core",
          options: [{ key: "showLabel", label: "Show time to sunrise/sunset", type: "toggle", default: true }] },
        { id: "nextEvent",     label: "Next holiday",  icon: "event",                group: "Core",
          options: [{ key: "days", label: "Look ahead (days)", type: "slider", min: 7, max: 120, step: 1, default: 30 },
                    { key: "width", label: "Name width", type: "slider", min: 60, max: 240, step: 10, default: 140 }] },
        { id: "week",          label: "Week number",   icon: "date_range",           group: "Core" },
        { id: "dashboard",     label: "Dashboard",     icon: "dashboard",            group: "Core" },

        { id: "dockApps",      label: "App icons",     icon: "apps",                 group: "Dock", surfaces: ["dock"], multi: true,
          options: [root.dockShowOpt, { key: "dim", label: "Dim", type: "toggle", default: false }] },
        { id: "dockSearch",    label: "Search field",  icon: "search",               group: "Dock", surfaces: ["dock"],
          options: [{ key: "width", label: "Width", type: "slider", min: 120, max: 360, step: 10, default: 200 }] },
        { id: "dockWorkspaces", label: "Workspace groups", icon: "view_column",      group: "Dock", surfaces: ["dock"],
          options: [{ key: "showEmpty", label: "Show empty workspaces", type: "toggle", default: false }] },
        { id: "dockMusic",     label: "Music player",  icon: "music_note",           group: "Dock", surfaces: ["dock"],
          options: root.musicOptions("pill") },

        { id: "cpu",           label: "CPU",           icon: "memory",               group: "Stats", options: [root.statStyleWith([{ "value": "columns", "label": "Per-core", "icon": "bar_chart" }]), root.showIconOpt, root.showValueOpt] },
        { id: "memory",        label: "Memory",        icon: "memory_alt",           group: "Stats", options: [root.statStyleWith([{ "value": "stacked", "label": "Stacked", "icon": "stacked_bar_chart" }]), root.showIconOpt, root.showValueOpt] },
        { id: "temperature",   label: "Temperature",   icon: "device_thermostat",    group: "Stats", options: [root.statStyle, root.showIconOpt, root.showValueOpt] },
        { id: "gpu",           label: "GPU",           icon: "developer_board",      group: "Stats", options: [root.statStyle, root.showIconOpt, root.showValueOpt] },
        { id: "netSpeed",      label: "Net speed",     icon: "swap_vert",            group: "Stats",
          options: [{ key: "style", label: "Style", type: "grid", default: "text",
                      choices: [{ value: "text", label: "Text", icon: "text_fields" },
                                { value: "heat", label: "Heat strip", icon: "view_column" },
                                { value: "radial", label: "Radial history", icon: "sunny" },
                                { value: "mirror", label: "Mirror", icon: "compare_arrows" }] },
                    { key: "direction", label: "Show", type: "choice", default: "both",
                      choices: [{ value: "down", label: "Down" }, { value: "up", label: "Up" }, { value: "both", label: "Both" }] },
                    root.showIconOpt, root.showValueOpt] },

        { id: "micMute",       label: "Mic",           icon: "mic",                  group: "Toggles",
          options: [root.showLabelOpt, { key: "onlyMuted", label: "Only show when muted", type: "toggle", default: false }] },
        { id: "focus",         label: "Focus timer",   icon: "timer",                group: "Toggles",
          options: [{ key: "dots", label: "Session dots", type: "toggle", default: true },
                    { key: "focusMin", label: "Focus (min)", type: "slider", setting: "focusMinutes", min: 5, max: 90, step: 5, default: 25 },
                    { key: "shortMin", label: "Short break (min)", type: "slider", setting: "focusShortBreak", min: 1, max: 30, step: 1, default: 5 },
                    { key: "longMin", label: "Long break (min)", type: "slider", setting: "focusLongBreak", min: 5, max: 45, step: 5, default: 15 },
                    { key: "rounds", label: "Sessions per round", type: "slider", setting: "focusRounds", min: 2, max: 8, step: 1, default: 4 }] },
        { id: "caffeine",      label: "Caffeine",      icon: "coffee",               group: "Toggles", options: [root.showLabelOpt] },
        { id: "dnd",           label: "Do not disturb", icon: "do_not_disturb_on",   group: "Toggles", options: [root.showLabelOpt] },
        { id: "gameMode",      label: "Game mode",     icon: "sports_esports",       group: "Toggles", options: [root.showLabelOpt] },

        { id: "launcher",      label: "Apps",          icon: "apps",                 group: "Launchers",
          options: [root.showLabelOpt,
                    { key: "hWindow", label: "Window", type: "heading" },
                    { key: "position", label: "Opens", type: "choice", setting: "launcherPosition", default: "edge",
                      choices: [{ value: "item", label: "From item" }, { value: "edge", label: "Left edge" }, { value: "center", label: "Centre" }] },
                    { key: "radius", label: "Corner radius", type: "slider", setting: "launcherRadius", min: 0, max: 40, step: 2, default: -1,
                      auto: "Match bar", onlyIf: { key: "position", values: ["edge", "center"] } },
                    { key: "hLayout", label: "Layout", type: "heading" },
                    { key: "style", label: "Style", type: "grid", setting: "launcherStyle", default: "list",
                      choices: ServiceLauncher.styles.map(x => ({ value: x.value, label: x.label, icon: x.icon })) },
                    { key: "iconSize", label: "Icon size", type: "slider", setting: "launcherIconSize", min: 20, max: 48, step: 2, default: 30 },
                    { key: "hOrder", label: "Order", type: "heading" },
                    { key: "sort", label: "Sort", type: "choice", setting: "launcherSort", default: "az",
                      choices: [{ value: "az", label: "A to Z" }, { value: "used", label: "Most used" }] },
                    { key: "hModes", label: "Search modes", type: "heading" },
                    { key: "calc", label: "Calculator  =", type: "toggle", setting: "launcherCalc", default: true },
                    { key: "run", label: "Run  >", type: "toggle", setting: "launcherRun", default: true },
                    { key: "emoji", label: "Emoji  :", type: "toggle", setting: "launcherEmoji", default: true },
                    { key: "windows", label: "Windows  w", type: "toggle", setting: "launcherWindows", default: true }] },
        { id: "clipboard",     label: "Clipboard",     icon: "content_paste",        group: "Launchers",
          options: [root.showLabelOpt,
                    { key: "style", label: "Panel style", type: "choice", setting: "clipboardStyle", default: "list",
                      choices: [{ value: "list", label: "List + preview", icon: "view_list" }, { value: "fan", label: "Card fan", icon: "style" }, { value: "board", label: "Board", icon: "dashboard" }] },
                    { key: "place", label: "Opens as", type: "choice", setting: "clipboardPanelMode", default: "dock",
                      choices: [{ value: "dock", label: "From the dock", icon: "dock_to_bottom" }, { value: "center", label: "Centre panel", icon: "center_focus_strong" }] }] },
        { id: "tools",         label: "Tools",         icon: "screenshot_monitor",   group: "Launchers", options: [root.showLabelOpt] },
        { id: "wallpaper",     label: "Wallpaper",     icon: "wallpaper",            group: "Launchers",
          options: [root.showLabelOpt,
                    { key: "style", label: "Panel style", type: "grid", setting: "wallpaperStyle", default: "classic",
                      choices: ServiceWallpaper.panelStyles.map(x => ({ value: x.value, label: x.label, icon: x.icon })) },
                    { key: "place", label: "Opens as", type: "choice", setting: "wallpaperPanelMode", default: "dock",
                      choices: [{ value: "dock", label: "From the dock", icon: "dock_to_bottom" }, { value: "center", label: "Centre panel", icon: "center_focus_strong" }] }] },
        { id: "overview",      label: "Overview",      icon: "grid_view",            group: "Launchers", options: [root.showLabelOpt] },
        { id: "settings",      label: "Settings",      icon: "settings",             group: "Launchers", options: [root.showLabelOpt] },
        { id: "power",         label: "Power",         icon: "power_settings_new",   group: "Launchers", options: [root.showLabelOpt] },
        { id: "soundscape",    label: "Soundscape",    icon: "graphic_eq",           group: "Launchers", options: [root.showLabelOpt] },
        { id: "scenes",        label: "Scenes",        icon: "view_quilt",           group: "Launchers", options: [root.showLabelOpt] },

        { id: "spacer",        label: "Spacer",        icon: "space_bar",            group: "Layout", multi: true,
          options: [{ key: "width", label: "Width", type: "slider", min: 4, max: 120, step: 4, default: 16 }] },
        { id: "separator",     label: "Separator",     icon: "horizontal_rule",      group: "Layout", multi: true,
          options: [{ key: "style", label: "Style", type: "grid", default: "line",
                      choices: [{ value: "line", label: "Line", icon: "more_vert" },
                                { value: "dot", label: "Dot", icon: "fiber_manual_record" },
                                { value: "accent", label: "Accent", icon: "format_color_fill" },
                                { value: "gap", label: "Gap", icon: "space_bar" }] },
                    { key: "height", label: "Height", type: "slider", min: 8, max: 32, step: 2, default: 18,
                      onlyIf: { key: "style", values: ["line", "accent"] } },
                    { key: "thickness", label: "Thickness", type: "slider", min: 1, max: 4, step: 1, default: 1 }] },
        { id: "shape",         label: "Shape",         icon: "category",             group: "Layout", multi: true,
          options: [{ key: "shape", label: "Shape", type: "shape", default: "cookie6" },
                    { key: "size", label: "Size", type: "slider", min: 10, max: 32, step: 2, default: 18 },
                    root.colorRoleOpt,
                    { key: "fill", label: "Style", type: "grid", default: "filled",
                      choices: [{ value: "filled", label: "Filled" }, { value: "outline", label: "Outline" }] },
                    { key: "motion", label: "Motion", type: "grid", default: "none",
                      choices: [{ value: "none", label: "Still" }, { value: "spin", label: "Spin" },
                                { value: "pulse", label: "Pulse" }] },
                    { key: "speed", label: "Speed", type: "slider", min: 1, max: 10, step: 1, default: 4,
                      onlyIf: { key: "motion", values: ["spin", "pulse"] } }] },
        { id: "logo",          label: "Nebula logo",   icon: "deployed_code",        group: "Layout", multi: true,
          options: [{ key: "look", label: "Look", type: "grid", default: "chip",
                      choices: [{ value: "plain",  label: "Plain",  icon: "crop_free" },
                                { value: "chip",   label: "Soft chip", icon: "circle" },
                                { value: "filled", label: "Filled", icon: "radio_button_checked" },
                                { value: "ring",   label: "Ring",   icon: "radio_button_unchecked" }] },
                    { key: "size", label: "Size", type: "slider", min: 14, max: 32, step: 2, default: 20 },
                    root.colorRoleOpt,
                    { key: "action", label: "When clicked", type: "grid", default: "dashboard",
                      choices: [{ value: "none",      label: "Nothing", icon: "block" },
                                { value: "dashboard", label: "Dashboard", icon: "space_dashboard" },
                                { value: "launcher",  label: "Apps", icon: "apps" },
                                { value: "overview",  label: "Overview", icon: "grid_view" },
                                { value: "pie",       label: "Quick actions", icon: "donut_small" },
                                { value: "power",     label: "Power", icon: "power_settings_new" },
                                { value: "settings",  label: "Settings", icon: "settings" }] }] },
        { id: "glyph",         label: "Icon",          icon: "emoji_symbols",        group: "Layout", multi: true,
          options: [{ key: "symbol", label: "Symbol", type: "text", default: "favorite" },
                    { key: "size", label: "Size", type: "slider", min: 12, max: 32, step: 2, default: 18 },
                    root.colorRoleOpt,
                    { key: "chip", label: "Chip backing", type: "toggle", default: false }] },
        { id: "equalizer",     label: "Equalizer",     icon: "graphic_eq",           group: "Layout", multi: true,
          options: [{ key: "bars", label: "Bars", type: "slider", min: 3, max: 7, step: 1, default: 5 },
                    { key: "height", label: "Height", type: "slider", min: 8, max: 24, step: 2, default: 16 },
                    root.colorRoleOpt] },
        { id: "text",          label: "Text",          icon: "text_fields",          group: "Layout", multi: true,
          options: [{ key: "text", label: "Text", type: "text", default: "Text" },
                    { key: "command", label: "Command", type: "text", default: "" },
                    { key: "interval", label: "Refresh (s)", type: "slider", min: 1, max: 60, step: 1, default: 5 },
                    { key: "size", label: "Size", type: "slider", min: 10, max: 18, step: 1, default: 13 },
                    { key: "bold", label: "Bold", type: "toggle", default: true }] },
        { id: "group",         label: "Group",         icon: "join_inner",           group: "Layout", multi: true }
    ]

    readonly property var anchorNames: ["left", "center", "right"]

    function baseId(id) {
        const k = id.indexOf("#")
        return k < 0 ? id : id.slice(0, k)
    }

    function entry(id) {
        const base = root.baseId(id)
        return root.catalog.find(e => e.id === base) ?? null
    }

    function fileFor(id) {
        const base = root.baseId(id)
        return "BarItem" + base.charAt(0).toUpperCase() + base.slice(1) + ".qml"
    }

    function newInstanceId(base) {
        return base + "#" + Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36)
    }

    function defaultBlocks() {
        const g = SettingsConfig.general ?? {}
        const centreItems = ["clock"]
        const right = ["rec", "tray"]
        if (g.barWeather ?? true)
            right.push("weather")
        right.push("volume", "wifi", "bluetooth", "notifications", "battery", "dashboard")
        return [
            { id: "left",   anchor: "left",   items: ["workspaces", "windowTitle"] },
            { id: "center", anchor: "center", items: centreItems },
            { id: "right",  anchor: "right",  items: right }
        ]
    }

    function urlFor(id) {
        return Qt.resolvedUrl(root.fileFor(id))
    }

    function allows(id, surface) {
        return BarOps.allows(root.entry(id), surface)
    }

    property var _stableCache: ({})

    function _stable(key, value) {
        const text = JSON.stringify(value)
        const hit = root._stableCache[key]
        if (hit && hit.text === text)
            return hit.value
        root._stableCache[key] = { text: text, value: value }
        return value
    }

    readonly property var dockConfig: root._stable("dockConfig", (SettingsConfig.bar ?? {}).dock ?? ({}))

    function _list(v) {
        return (v !== undefined && v !== null && typeof v.length === "number")
            ? Array.prototype.slice.call(v) : undefined
    }

    readonly property var allBlocks: {
        const saved = root._list(SettingsConfig.bar?.blocks)
        return root._stable("allBlocks", BarOps.sanitize((saved && saved.length) ? saved : root.defaultBlocks(), {
            migrated: root.dockConfig.edgeModel === true,
            dockItems: root._list(root.dockConfig.items),
            musicOn: (SettingsConfig.general ?? {}).dockMusicPlayer ?? true
        }, id => root.entry(id), root.anchorNames))
    }

    readonly property var blocks: root.allBlocks.filter(b => b.edge === "top")
    readonly property var bottomBlocks: root.allBlocks.filter(b => b.edge === "bottom")
    readonly property bool dockOn: (SettingsConfig.general ?? {}).dock ?? true
    readonly property var sides: root._stable("sides", BarOps.sidesOf(SettingsConfig.bar))
    readonly property string barSide: root.sides.bar
    readonly property string dockSide: root.sides.dock

    function sideOf(edge) {
        return edge === "bottom" ? root.dockSide : root.barSide
    }

    function setSide(which, side) {
        root._patch(BarOps.withSide(SettingsConfig.bar, which, side))
    }
    readonly property bool dockPresent: root.bottomBlocks.some(b => b.items.length > 0)

    Binding {
        target: GlobalStates
        property: "dockPresent"
        value: root.dockPresent
    }

    readonly property var itemGroups: root._stable("itemGroups", SettingsConfig.bar?.groups ?? ({}))
    readonly property var placedIds: {
        const out = {}
        for (const b of root.allBlocks)
            for (const i of root._list(b.items))
                out[i] = true
        return out
    }
    readonly property var groupedIds: {
        const out = []
        const g = root.itemGroups
        for (const key in g) {
            if (!root.placedIds[key])
                continue
            for (const id of root._list(g[key]))
                out.push(id)
        }
        return out
    }
    readonly property var hiddenItems: BarOps.hidden(root.catalog, root.allBlocks, root.groupedIds)

    property QtObject editor: null

    property bool settled: false

    Timer {
        interval: 1000
        running: SettingsConfig.settingsReady && !root.settled
        onTriggered: root.settled = true
    }

    readonly property bool sysPanelOpen: GlobalStates.clipboardOpen || GlobalStates.wallpaperOpen
        || GlobalStates.panelPreview === "wallpaper" || GlobalStates.panelPreview === "clipboard"
        || GlobalStates.osdOpen
    readonly property bool needSysHost: root.sysPanelOpen
        && (!root.dockOn || !root.bottomBlocks.some(b => b.anchor === "center"))
    readonly property string sysHostId: {
        if (root.needSysHost)
            return "__sys"
        const c = root.bottomBlocks.find(b => b.anchor === "center")
        return c ? c.id : ""
    }
    readonly property var sysHostBlock: ({ id: "__sys", anchor: "center", edge: "bottom", items: [] })

    readonly property var moreBlock: ({ id: "__more", anchor: "right", edge: "top", items: ["more"] })

    function blockById(id) {
        if (id === "__sys")
            return root.sysHostBlock
        if (id === "__more")
            return root.moreBlock
        return root.allBlocks.find(b => b.id === id) ?? null
    }

    function idsFor(anchor, edge) {
        const e = edge === "bottom" ? "bottom" : "top"
        const ids = (e === "bottom" && !root.dockOn) ? []
            : root.allBlocks.filter(b => b.anchor === anchor && b.edge === e).map(b => b.id)
        if (e === "bottom" && anchor === "center" && root.needSysHost)
            ids.push("__sys")
        return ids
    }

    function newBlockId() {
        return "b" + Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36)
    }

    function _clone() {
        return root.allBlocks.map(b => ({ id: b.id, anchor: b.anchor, edge: b.edge, items: b.items.slice() }))
    }

    function _patch(patch) {
        SettingsConfig.bar = Object.assign({}, SettingsConfig.bar ?? {}, patch)
    }

    function _statePatch(list) {
        const d = Object.assign({}, root.dockConfig, { edgeModel: true })
        delete d.items
        const patch = { blocks: list, dock: d }
        const groups = root._prunedGroups(list)
        if (groups)
            patch.groups = groups
        return patch
    }

    function _prunedGroups(list) {
        const placed = {}
        for (const b of list)
            for (const i of root._list(b.items))
                placed[i] = true
        const out = {}
        let dropped = false
        for (const key in root.itemGroups) {
            if (placed[key])
                out[key] = root._list(root.itemGroups[key])
            else
                dropped = true
        }
        return dropped ? out : null
    }

    function _write(list) {
        root._patch(root._statePatch(list))
    }

    function moveItem(itemId, toBlock, index) {
        const e = root.entry(itemId)
        const id = (e && e.multi && itemId.indexOf("#") < 0) ? root.newInstanceId(itemId) : itemId
        const next = BarOps.move(root.allBlocks, id, toBlock, index, i => root.entry(i))
        if (next)
            root._write(next)
    }

    function hideItem(itemId) {
        const patch = root._statePatch(BarOps.hide(root.allBlocks, itemId))
        if (itemId.indexOf("#") >= 0) {
            const m = Object.assign({}, root.margins)
            delete m[itemId]
            const op = Object.assign({}, root.itemOptions)
            delete op[itemId]
            patch.margins = m
            patch.options = op
        }
        if (root.itemStyles[itemId] !== undefined) {
            const st = Object.assign({}, root.itemStyles)
            delete st[itemId]
            patch.itemStyles = st
        }
        if (root.isGroup(itemId) && root.itemGroups[itemId] !== undefined) {
            const groups = {}
            for (const key in root.itemGroups)
                if (key !== itemId)
                    groups[key] = root._list(root.itemGroups[key])
            patch.groups = groups
        }
        root._patch(patch)
    }

    function addBlock(anchor, edge) {
        const e = edge === "bottom" ? "bottom" : "top"
        const list = root._clone()
        const block = { id: root.newBlockId(), anchor: anchor, edge: e, items: [] }
        if (anchor === "right") {
            const k = list.findIndex(b => b.anchor === "right" && b.edge === e)
            if (k < 0) list.push(block)
            else list.splice(k, 0, block)
        } else {
            let k = -1
            list.forEach((b, i) => { if (b.anchor === anchor && b.edge === e) k = i })
            if (k < 0) list.push(block)
            else list.splice(k + 1, 0, block)
        }
        root._write(list)
        return block.id
    }

    function removeBlock(id) {
        const b = root.blockById(id)
        if (!b || (b.edge === "top" && root.blocks.length <= 1))
            return
        const patch = root._statePatch(root._clone().filter(x => x.id !== id))
        if (root.blockStyles[id] !== undefined) {
            const st = Object.assign({}, root.blockStyles)
            delete st[id]
            patch.blockStyles = st
        }
        root._patch(patch)
    }

    function moveBlock(id, anchor, index, edge) {
        const list = root._clone()
        const k = list.findIndex(b => b.id === id)
        if (k < 0)
            return
        const blk = list[k]
        const e = (edge === "top" || edge === "bottom") ? edge : blk.edge
        if (!BarOps.canMoveBlock(blk, e, i => root.entry(i)))
            return
        if (blk.edge === "top" && e === "bottom" && root.blocks.length <= 1)
            return
        list.splice(k, 1)
        blk.anchor = anchor
        blk.edge = e
        const same = []
        list.forEach((b, i) => { if (b.anchor === anchor && b.edge === e) same.push(i) })
        let at = list.length
        if (index < same.length) at = same[index]
        else if (same.length) at = same[same.length - 1] + 1
        list.splice(at, 0, blk)
        root._write(list)
    }

    function pruneEmpty() {
        const list = root._clone()
        const kept = BarOps.prune(list)
        if (kept.length === list.length)
            return
        root._write(kept)
    }

    readonly property var blockStyles: root._stable("blockStyles", SettingsConfig.bar?.blockStyles ?? ({}))

    function blockStyle(blockId, key, def) {
        const st = root.blockStyles[blockId]
        const v = st ? st[key] : undefined
        return v === undefined ? def : v
    }

    function setBlockStyle(blockId, key, value) {
        const all = Object.assign({}, root.blockStyles)
        all[blockId] = Object.assign({}, all[blockId] ?? {}, { [key]: value })
        root._patch({ blockStyles: all })
    }

    readonly property var shapes: root._stable("shapes", BarOps.blockShapes(SettingsConfig.bar, SettingsConfig.general, root.allBlocks))

    function blockShape(blockId, edge) {
        if (blockId === "__more") {
            const r = root.allBlocks.find(b => b.anchor === "right" && b.edge === "top")
            return BarOps.shapeIn(root.shapes, r ? r.id : blockId, "top")
        }
        return BarOps.shapeIn(root.shapes, blockId, edge)
    }

    function blockPanels(blockId, edge) {
        const v = root.blockStyle(blockId, "panels", "")
        if (v === "floating" || v === "attached")
            return v
        return BarOps.isBottom(edge) ? "attached" : "floating"
    }

    function edgeShapes(edge) {
        return root.shapes.edges[BarOps.isBottom(edge) ? "bottom" : "top"]
    }

    function _setShapes(edge, pick) {
        const e = BarOps.isBottom(edge) ? "bottom" : "top"
        const all = Object.assign({}, root.blockStyles)
        for (const b of root.allBlocks) {
            if (BarOps.edgeOf(b) !== e)
                continue
            const s = pick(b.id) ?? root.blockShape(b.id, e)
            all[b.id] = Object.assign({}, all[b.id] ?? {}, { shape: s })
        }
        root._patch({ blockStyles: all })
    }

    function setBlockShape(blockId, shape) {
        const b = root.blockById(blockId)
        if (!b || !BarOps.isShape(shape))
            return
        root._setShapes(b.edge, id => id === blockId ? shape : undefined)
    }

    function setEdgeShape(edge, shape) {
        if (BarOps.isShape(shape))
            root._setShapes(edge, () => shape)
    }

    function blockLabel(blockId) {
        const b = root.blockById(blockId)
        if (!b)
            return ""
        const name = b.anchor === "center" ? "Centre" : (b.anchor === "left" ? "Left" : "Right")
        const same = root.allBlocks.filter(x => x.anchor === b.anchor && x.edge === b.edge)
        if (same.length < 2)
            return name
        return name + " " + (same.findIndex(x => x.id === blockId) + 1)
    }

    readonly property var margins: root._stable("margins", SettingsConfig.bar?.margins ?? ({}))

    function marginsFor(id) {
        const m = root.margins[id]
        return (m && m.length === 2) ? m : [0, 0]
    }

    function setMargin(id, side, px) {
        const cur = root.marginsFor(id).slice()
        cur[side === "left" ? 0 : 1] = Math.max(0, Math.min(40, Math.round(px)))
        const next = Object.assign({}, root.margins)
        if (cur[0] === 0 && cur[1] === 0) delete next[id]
        else next[id] = cur
        root._patch({ margins: next })
    }

    readonly property var itemStyles: root._stable("itemStyles", SettingsConfig.bar?.itemStyles ?? ({}))

    function itemStyle(id, key, def) {
        const st = root.itemStyles[id]
        const v = st ? st[key] : undefined
        return v === undefined ? def : v
    }

    function setItemStyle(id, key, value) {
        const all = Object.assign({}, root.itemStyles)
        const cur = Object.assign({}, all[id] ?? {}, { [key]: value })
        if ((cur.tint ?? "none") === "none") {
            delete cur.tint
            delete cur.radius
            delete cur.minW
            delete cur.minH
            delete cur.shape
        }
        if (!cur.iconSize)
            delete cur.iconSize
        if (Object.keys(cur).length === 0)
            delete all[id]
        else
            all[id] = cur
        root._patch({ itemStyles: all })
    }

    function iconPx(id, def) {
        const v = root.itemStyle(id, "iconSize", 0)
        return v > 0 ? v : def
    }

    function iconOnly(contentWidth, contentHeight) {
        return contentWidth > 0 && contentHeight > 0 && contentWidth <= contentHeight + 8
    }

    function chipShape(id) {
        return root.itemStyle(id, "shape", "none")
    }

    function chipShaped(id, contentWidth, contentHeight) {
        return root.chipShape(id) !== "none" && root.iconOnly(contentWidth, contentHeight)
    }

    readonly property real chipInset: 4
    readonly property real glyphRatio: 0.64

    function iconFromBox(box) {
        return Math.max(10, Math.min(40, Math.round(box * root.glyphRatio)))
    }

    function boxFor(id, host) {
        const hosted = host && host.contentBox ? host.contentBox : 0
        if (hosted > 0)
            return hosted
        const h = root.itemStyle(id, "minH", 0)
        return h > 0 ? Math.max(12, h - root.chipInset * 2) : 0
    }

    function iconPxFor(id, box, defIcon) {
        const v = root.itemStyle(id, "iconSize", 0)
        if (v > 0)
            return v
        return box > 0 ? root.iconFromBox(box) : defIcon
    }

    function platePxFor(box, icon, defIcon, defPlate) {
        if (box > 0)
            return box
        return icon === defIcon ? defPlate : Math.round(defPlate * icon / defIcon)
    }

    function scaleFor(icon, defIcon, value, floor) {
        return icon === defIcon ? value : Math.max(floor, Math.round(value * icon / defIcon))
    }

    function chipHovers(id, contentWidth, contentHeight) {
        return root.itemStyle(id, "tint", "none") !== "none"
            && root.chipShaped(id, contentWidth, contentHeight)
    }

    function chipPad(id) {
        return root.itemStyle(id, "pad", 10)
    }

    function chipGap(id, fallback) {
        const g = root.itemStyle(id, "gap", -1)
        return g >= 0 ? g : fallback
    }

    function chipSide(id, contentWidth, contentHeight, barH) {
        const auto = Math.max(contentWidth, contentHeight) + root.chipPad(id)
        return Math.min(barH, Math.max(auto, root.itemStyle(id, "minH", 0)))
    }

    function chipW(id, contentWidth, contentHeight, barH) {
        if (root.itemStyle(id, "tint", "none") === "none")
            return 0
        if (root.chipShaped(id, contentWidth, contentHeight))
            return root.chipSide(id, contentWidth, contentHeight, barH)
        return Math.max(contentWidth + root.chipPad(id) * 2, root.itemStyle(id, "minW", 0))
    }

    function chipH(id, contentHeight, barH, contentWidth) {
        if (root.itemStyle(id, "tint", "none") === "none")
            return 0
        if (root.chipShaped(id, contentWidth, contentHeight))
            return root.chipSide(id, contentWidth, contentHeight, barH)
        return Math.min(barH, Math.max(contentHeight + 8, root.itemStyle(id, "minH", 0)))
    }

    function chipRadius(id, h) {
        const r = root.itemStyle(id, "radius", -1)
        return r < 0 ? h / 2 : r
    }

    function chipColor(id) {
        return Qt.alpha(root.roleColor(root.itemStyle(id, "tint", "primary")), 0.18)
    }

    function isGroup(id) {
        return root.baseId(id) === "group"
    }

    function groupMembers(groupId) {
        return root._list(root.itemGroups[groupId] ?? [])
    }

    function groupOwning(itemId) {
        const g = root.itemGroups
        for (const key in g)
            if (root._list(g[key]).indexOf(itemId) >= 0)
                return key
        return ""
    }

    function _groupsPatch(groups, blocks) {
        const patch = { groups: groups }
        if (blocks)
            Object.assign(patch, root._statePatch(blocks))
        root._patch(patch)
    }

    function addToGroup(groupId, itemId) {
        const e = root.entry(itemId)
        const id = (e && e.multi && itemId.indexOf("#") < 0) ? root.newInstanceId(itemId) : itemId
        const groups = {}
        for (const key in root.itemGroups)
            groups[key] = root._list(root.itemGroups[key]).filter(x => x !== id)
        groups[groupId] = (groups[groupId] ?? []).concat([id])
        const list = root._clone()
        BarOps.strip(list, id)
        root._groupsPatch(groups, list)
    }

    function removeFromGroup(groupId, itemId) {
        const groups = {}
        for (const key in root.itemGroups)
            groups[key] = root._list(root.itemGroups[key]).filter(x => x !== itemId)
        root._groupsPatch(groups, null)
    }

    function moveInGroup(groupId, itemId, delta) {
        const cur = root.groupMembers(groupId)
        const next = BarOps.reorder(cur, itemId, delta)
        if (next.join("\u0000") === cur.join("\u0000"))
            return
        const groups = {}
        for (const key in root.itemGroups)
            groups[key] = root._list(root.itemGroups[key])
        groups[groupId] = next
        root._patch({ groups: groups })
    }

    function clearGroup(groupId) {
        if (root.itemGroups[groupId] === undefined)
            return
        const groups = {}
        for (const key in root.itemGroups)
            if (key !== groupId)
                groups[key] = root._list(root.itemGroups[key])
        root._patch({ groups: groups })
    }

    function clearItemStyle(id) {
        if (!(id in root.itemStyles))
            return
        const all = Object.assign({}, root.itemStyles)
        delete all[id]
        root._patch({ itemStyles: all })
    }

    function clearMargins(id) {
        if (!(id in root.margins))
            return
        const next = Object.assign({}, root.margins)
        delete next[id]
        root._patch({ margins: next })
    }

    readonly property var panelSpecs: ({
        "calendar":  { "label": "Calendar",  "minW": 320, "maxW": 640, "defW": 400, "minH": 300, "maxH": 560,  "defH": 400 },
        "weather":   { "label": "Weather",   "minW": 300, "maxW": 720, "defW": 340, "minH": 360, "maxH": 1600, "defH": -1 },
        "dashboard": { "label": "Dashboard", "minW": 280, "maxW": 1200, "defW": 320, "minH": 280, "maxH": 1600, "defH": 1020, "autoH": true },
        "launcher":  { "label": "Launcher", "minW": ServiceLauncher.minWidth, "maxW": ServiceLauncher.maxWidth,
                       "defW": ServiceLauncher.defaultWidth, "minH": ServiceLauncher.minHeight,
                       "maxH": ServiceLauncher.maxHeight, "defH": ServiceLauncher.defaultHeight }
    })
    readonly property var panelOpeners: ({ "clock": "calendar", "weather": "weather", "dashboard": "dashboard", "launcher": "launcher", "wallpaper": "wallpaper", "clipboard": "clipboard" })
    readonly property var panelSizes: root._stable("panelSizes", SettingsConfig.bar?.panelSizes ?? ({}))
    property var panelDraft: null

    function draftOf(kind) {
        if (kind === "launcher") return ServiceLauncher.draft
        return root.panelDraft && root.panelDraft.kind === kind ? root.panelDraft : null
    }

    function setDraft(kind, w, h) {
        if (kind === "launcher") ServiceLauncher.draft = { w: w, h: h }
        else root.panelDraft = { kind: kind, w: w, h: h }
    }

    function panelCustom(kind) {
        return kind === "launcher" ? ServiceLauncher.customSize : kind in root.panelSizes
    }

    function isPlaced(id) {
        return root.allBlocks.some(b => b.items.indexOf(id) >= 0)
            || (root.groupedIds ?? []).indexOf(id) >= 0
    }

    function panelHostItem(kind) {
        if (kind === "calendar") return "clock"
        if (kind === "dashboard" && !root.isPlaced("dashboard")) {
            const logo = root.logoFor("dashboard")
            if (logo !== "")
                return logo
            if (root.isPlaced("notifications"))
                return "notifications"
        }
        return kind
    }

    function logoFor(action) {
        const ids = []
        root.allBlocks.forEach(b => b.items.forEach(id => ids.push(id)))
        const found = ids.find(id => root.baseId(id) === "logo" && (root.opt(id, "action") ?? "dashboard") === action)
        return found ?? ""
    }

    function panelFor(id) {
        if (!id) return ""
        if (id.indexOf("dash:") === 0) return "dashboard"
        return root.panelOpeners[root.baseId(id)] ?? ""
    }

    function clampPanelW(kind, w) {
        const s = root.panelSpecs[kind]
        return Math.round(Math.max(s.minW, Math.min(s.maxW, w)))
    }

    function clampPanelH(kind, h) {
        const s = root.panelSpecs[kind]
        return h < 0 ? -1 : Math.round(Math.max(s.minH, Math.min(s.maxH, h)))
    }

    function panelW(kind) {
        if (kind === "launcher") return ServiceLauncher.panelWidth
        const s = root.panelSpecs[kind]
        if (!s) return 0
        const d = root.panelDraft
        if (d && d.kind === kind) return d.w
        const own = root.panelSizes[kind]
        return own && typeof own.w === "number" ? root.clampPanelW(kind, own.w) : s.defW
    }

    function panelH(kind) {
        if (kind === "launcher") return ServiceLauncher.panelHeight
        const s = root.panelSpecs[kind]
        if (!s) return -1
        const d = root.panelDraft
        if (d && d.kind === kind) return d.h
        const own = root.panelSizes[kind]
        return own && typeof own.h === "number" ? root.clampPanelH(kind, own.h)
            : s.defH > 0 ? Math.min(s.defH, root.panelCapH) : s.defH
    }

    readonly property int panelCapH: Math.max(280, Quickshell.screens.reduce((m, sc) => Math.min(m, sc.height), 100000) - 60)

    function floatPanelW(kind) {
        if (kind === "dashboard" && !root.panelSizes.dashboard && !(root.panelDraft && root.panelDraft.kind === kind))
            return 300
        return root.panelW(kind)
    }

    function panelHeightIn(kind, auto, room) {
        const h = root.panelH(kind)
        return Math.max(0, Math.min(room, h < 0 ? auto : h))
    }

    function panelPresets(kind) {
        const s = root.panelSpecs[kind]
        if (!s)
            return []
        const mid = (a, b) => Math.round((a + b) / 2)
        return [
            { value: "snug", label: "Snug", w: s.minW, h: s.defH < 0 ? -1 : s.minH },
            { value: "roomy", label: "Roomy", w: s.defW, h: s.defH, reset: true },
            { value: "wide", label: "Wide", w: mid(s.defW, s.maxW), h: s.defH < 0 ? -1 : mid(s.defH, s.maxH) }
        ]
    }

    function presetActive(kind, value) {
        const p = root.panelPresets(kind).find(x => x.value === value)
        return !!p && root.panelW(kind) === root.clampPanelW(kind, p.w) && root.panelH(kind) === root.clampPanelH(kind, p.h)
    }

    function applyPreset(kind, value) {
        const p = root.panelPresets(kind).find(x => x.value === value)
        if (!p)
            return
        if (p.reset) root.clearPanelSize(kind)
        else root.setPanelSize(kind, p.w, p.h)
    }

    function setPanelSize(kind, w, h) {
        if (kind === "launcher") {
            ServiceLauncher.setSize(w, h)
            return
        }
        if (!root.panelSpecs[kind]) return
        const s = root.panelSpecs[kind]
        const next = Object.assign({}, root.panelSizes)
        const cw = root.clampPanelW(kind, w)
        const ch = root.clampPanelH(kind, h)
        if (cw === s.defW && ch === s.defH) delete next[kind]
        else next[kind] = { "w": cw, "h": ch }
        root.panelDraft = null
        root._patch({ panelSizes: next })
    }

    function clearPanelSize(kind) {
        if (kind === "launcher") {
            ServiceLauncher.clearSize()
            return
        }
        root.panelDraft = null
        if (!(kind in root.panelSizes))
            return
        const next = Object.assign({}, root.panelSizes)
        delete next[kind]
        root._patch({ panelSizes: next })
    }

    readonly property var itemOptions: root._stable("itemOptions", SettingsConfig.bar?.options ?? ({}))

    function specFor(id, key) {
        const e = root.entry(id)
        if (!e || !e.options)
            return null
        return e.options.find(o => o.key === key) ?? null
    }

    function opt(id, key) {
        const s = root.specFor(id, key)
        if (s && s.setting)
            return (SettingsConfig.general ?? {})[s.setting] ?? s.default
        const own = root.itemOptions[id]
        const v = own ? own[key] : undefined
        return v !== undefined ? v : (s ? s.default : undefined)
    }

    function setOption(id, key, value) {
        const s = root.specFor(id, key)
        if (s && s.setting) {
            const g = {}
            g[s.setting] = value
            SettingsConfig.general = Object.assign({}, SettingsConfig.general, g)
            return
        }
        const next = Object.assign({}, root.itemOptions)
        const own = Object.assign({}, next[id] ?? {})
        own[key] = value
        next[id] = own
        root._patch({ options: next })
    }

    readonly property real itemGap: (SettingsConfig.bar ?? {}).itemGap ?? 6
    readonly property real blockGap: (SettingsConfig.bar ?? {}).blockGap ?? -1
    readonly property real cornerRadius: (SettingsConfig.bar ?? {}).radius ?? 18

    function sizeValue(key, def) {
        const v = (SettingsConfig.bar ?? {})[key]
        return v !== undefined && v !== null ? v : def
    }

    function setSize(key, value) {
        const o = {}
        o[key] = value
        root._patch(o)
    }

    readonly property var screenBorder: Object.assign({ on: false, size: 8, radius: 20, top: true, right: true, bottom: true, left: true },
                                                      SettingsConfig.bar?.border ?? {})

    function setBorder(patch) {
        root._patch({ border: Object.assign({}, root.screenBorder, patch) })
    }

    function dockSize(key, def) {
        const v = root.dockConfig[key]
        return v !== undefined && v !== null ? v : def
    }

    function setDockSize(key, value) {
        const d = Object.assign({}, root.dockConfig)
        d[key] = value
        root._patch({ dock: d })
    }

    readonly property real dockHeight: root.dockSize("height", 60)
    readonly property real dockIconSize: root.dockSize("iconSize", 32)
    readonly property real dockItemGap: root.dockSize("itemGap", 2)
    readonly property real dockRadius: root.dockSize("radius", 18)
    readonly property real dockBlockGap: root.dockSize("blockGap", -1)
    readonly property real dockPillGap: root.dockSize("pillGap", (SettingsConfig.general ?? {}).pillMargin ?? 6)

    readonly property bool dockMusic: BarOps.hasDockMusic(root.allBlocks)

    function setDockMusic(on) {
        root._write(BarOps.setDockMusic(root.allBlocks, on, root.newBlockId()))
    }

    function reset() {
        root.panelDraft = null
        root._patch({ blocks: [], dock: {}, margins: {}, options: {}, groups: {}, panelSizes: {},
                      itemStyles: {}, blockStyles: {},
                      height: 40, itemGap: 6, blockGap: -1, radius: 18 })
    }

    function syncAnimated(model, ids, role, leaving) {
        for (let i = 0; i < model.count; i++) {
            const id = model.get(i)[role]
            if (ids.indexOf(id) < 0) leaving[id] = true
            else delete leaving[id]
        }
        root.syncModel(model, ids, role, leaving)
    }

    function dropLeaving(model, ids, role, leaving, id) {
        delete leaving[id]
        root.syncModel(model, ids, role, leaving)
    }

    function syncModel(model, wanted, role, leaving) {
        const ids = wanted.slice()
        if (leaving) {
            for (let i = 0; i < model.count; i++) {
                const id = model.get(i)[role]
                if (ids.indexOf(id) < 0 && leaving[id])
                    ids.splice(Math.min(i, ids.length), 0, id)
            }
        }
        for (let i = 0; i < ids.length; i++) {
            if (i < model.count && model.get(i)[role] === ids[i])
                continue
            let found = -1
            for (let j = i + 1; j < model.count; j++) {
                if (model.get(j)[role] === ids[i]) {
                    found = j
                    break
                }
            }
            if (found >= 0) {
                model.move(found, i, 1)
            } else {
                const o = { leaving: false }
                o[role] = ids[i]
                model.insert(i, o)
            }
        }
        while (model.count > ids.length)
            model.remove(model.count - 1)
        for (let i = 0; i < model.count; i++) {
            const lv = !!(leaving && leaving[model.get(i)[role]])
            if (model.get(i).leaving !== lv)
                model.setProperty(i, "leaving", lv)
        }
    }

    Connections {
        target: GlobalStates
        function onBarEditModeChanged() {
            if (!GlobalStates.barEditMode) root.pruneEmpty()
        }
    }

    IpcHandler {
        target: "bar"
        function edit(): void { GlobalStates.barEditMode = true }
        function done(): void { GlobalStates.barEditMode = false }
        function reset(): void { root.reset() }
        function state(): string {
            return JSON.stringify({ margins: root.margins, options: root.itemOptions, bar: SettingsConfig.bar, hidden: root.hiddenItems,
                                    bottom: root.bottomBlocks })
        }
    }

    GlobalShortcut {
        name: "barEdit"
        onPressed: GlobalStates.barEditMode = !GlobalStates.barEditMode
    }
}
