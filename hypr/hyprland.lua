-- Refer to the wiki for more information: https://wiki.hypr.land/Configuring/Start/

---------------------
---- MY PROGRAMS ----
---------------------
-- Declared globally so modules inside dots/ can access them
terminal    = "kitty"
fileManager = "nautilus --new-window"
menu        = "hyprlauncher"

--------------------
---- LOAD MODULES ----
--------------------
require("dots.monitors")
require("dots.env")
require("dots.permissions")
require("dots.look_and_feel")
require("dots.input")
require("dots.keybinds")
require("dots.rules")

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user set-environment QML2_IMPORT_PATH=$HOME/.local/lib/qt6/qml")
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("systemctl --user start quickshell.service")
end)
