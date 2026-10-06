local mainMod = "SUPER"

local terminal    = "kitty"
local fileManager = "dolphin"
local browser     = "firefox"

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + R",      hl.dsp.global("quickshell:appLauncher"))
hl.bind(mainMod .. " + M",      hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

hl.bind(mainMod .. " + Q",         hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("kill $(hyprctl activewindow -j | jq -r .pid)"))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + T",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + C",         hl.dsp.window.center())
hl.bind(mainMod .. " + Y",         hl.dsp.window.pin())
hl.bind(mainMod .. " + P",         hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",         hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + K",         hl.dsp.layout("swapsplit"))
hl.bind(mainMod .. " + G",         hl.dsp.group.toggle())
hl.bind(mainMod .. " + CTRL + Tab", hl.dsp.group.next())

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left"  }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up"    }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down"  }))

hl.bind(mainMod .. " + ALT + left",  hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + ALT + up",    hl.dsp.window.swap({ direction = "u" }))
hl.bind(mainMod .. " + ALT + down",  hl.dsp.window.swap({ direction = "d" }))

hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = 50,  y = 0,   relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -50, y = 0,   relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0,   y = 50,  relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0,   y = -50, relative = true }), { repeating = true })

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("ALT + Tab", hl.dsp.window.cycle_next(),   { repeating = true })
hl.bind("ALT + Tab", hl.dsp.window.bring_to_top(), { repeating = true })

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + Tab",          hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + SHIFT + Tab",  hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.focus({ workspace = "empty" }))
hl.bind(mainMod .. " + mouse_down",   hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",     hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + Z",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
