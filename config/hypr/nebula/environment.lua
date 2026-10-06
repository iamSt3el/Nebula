local home = os.getenv("HOME")

hl.env("QT_QPA_PLATFORM",                     "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME",                "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR",         "1")

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE",    "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

hl.env("QML_IMPORT_PATH", home .. "/.local/lib/qt6/qml")
hl.env("NEBULA_VENV",     home .. "/.local/state/quickshell/.venv")
