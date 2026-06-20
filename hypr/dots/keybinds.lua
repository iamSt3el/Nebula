-- See https://wiki.hypr.land/Configuring/Basics/Binds/ for more
local mainMod = "SUPER"

--------------------------------------
---- CORE APPS & SHELL MANAGEMENT ----
--------------------------------------
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + M",
    hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"))

-- File Manager: Shifted to SHIFT+E to allow SUPER+E for Nebula Weather widget
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))

---------------------------
---- WINDOW OPERATIONS ----
---------------------------
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)

hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit")) -- Changed to T to entirely clear Vim J/K bindings

-- Floating Toggle: Shifted to SHIFT+V to allow SUPER+V for Nebula Clipboard
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.window.float({ action = "toggle" }))

-- Maximize window (keep decorations) / Fullscreen (no decorations)
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

------------------------------------------
---- VIM NAVIGATION & ARROW FALLBACKS ----
------------------------------------------
-- Move focus with mainMod + Vim keys (hjkl)
hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))

-- Move focus with mainMod + Arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

----------------------------------
---- WORKSPACES & SCRATCHPADS ----
----------------------------------
-- Switch workspaces / Move windows with mainMod + [0-9]
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Special Workspace (Scratchpad): Shifted to ALT modifiers to preserve Nebula's Tools Widget (SUPER+S)
hl.bind(mainMod .. " + ALT + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Workspace Scrolling
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Mouse Dragging Window Rules
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-----------------------------------
---- NEBULA QUICKSHELL MODULES ----
-----------------------------------
-- Quickshell global shortcuts
hl.bind(mainMod .. " + ALT + L", hl.dsp.global("quickshell:lock"), { locked = true })
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.global("quickshell:shutdown"), { locked = true })
hl.bind(mainMod .. " + Space", hl.dsp.global("quickshell:appLauncher"))
hl.bind(mainMod .. " + W", hl.dsp.global("quickshell:wallpaperLauncher"))
hl.bind(mainMod .. " + CTRL + S", hl.dsp.global("quickshell:settingOpen"))
hl.bind(mainMod .. " + A", hl.dsp.global("quickshell:mangaReader"))
hl.bind(mainMod .. " + D", hl.dsp.global("quickshell:dashboard"))
hl.bind(mainMod .. " + N", hl.dsp.global("quickshell:notification"))

-- Overriding binds cleanly:
hl.bind(mainMod .. " + S", hl.dsp.global("quickshell:toolsWidget")) -- Won't conflict with Scratchpad
hl.bind(mainMod .. " + V", hl.dsp.global("quickshell:clipboard"))   -- Won't conflict with Floating Window


------------------------------------
---- HARDWARE & MEDIA CONTROLS -----
------------------------------------
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
