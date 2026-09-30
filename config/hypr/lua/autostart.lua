-- Programs that launch once on Hyprland startup
-- ~/.config/hypr/lua/autostart.lua

hl.on("hyprland.start", function()
    -- XDG desktop portal (screen sharing, file picker, etc.)
    hl.exec_cmd("~/.config/hypr/scripts/xdg.sh")

    -- Authentication agent (polkit)
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- GTK theming (applies GTK settings, icon theme, fonts)
    hl.exec_cmd("~/.config/hypr/scripts/gtk.sh")

    -- Idle + screen-lock daemon
    hl.exec_cmd("hypridle")

    -- Nebula shell, plus the clipboard watcher
    hl.exec_cmd("nebula start")

    -- Set cursor theme
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")

    -- Notify DBus / systemd of the Wayland session
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
end)
