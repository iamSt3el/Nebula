-- Nebula shell — autostart additions
-- Add these lines inside the hl.on("hyprland.start", ...) block
-- in your ~/.config/hypr/lua/autostart.lua (or equivalent).

-- Starts the shell, plus the cliphist watcher if it isn't running
hl.exec_cmd("nebula start")
