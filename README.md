<div align="center">

# Nebula

*A dreamy desktop shell for Hyprland, built with Quickshell*

<br/>

[![Stars](https://img.shields.io/github/stars/iamSt3el/Nebula?style=for-the-badge&logo=starship&color=8B5CF6&labelColor=1a1a2e)](https://github.com/iamSt3el/Nebula/stargazers)
[![License](https://img.shields.io/github/license/iamSt3el/Nebula?style=for-the-badge&color=6D28D9&labelColor=1a1a2e)](LICENSE)
[![Quickshell](https://img.shields.io/badge/built%20with-Quickshell-a78bfa?style=for-the-badge&labelColor=1a1a2e)](https://quickshell.outfoxxed.me)

</div>

---

## Preview

<div align="center">

https://github.com/user-attachments/assets/30a3f633-4933-4bc3-8144-f51887c8eb0a

</div>

---

## Features

- **Bar** — workspaces, system tray, clock, weather, notifications, bluetooth, wifi, and media controls
- **Weather panel** — current conditions, hourly and daily forecast, UV index, humidity, wind, and visibility
- **App launcher** — fuzzy search across installed applications
- **Notification center** — grouped notifications with dismiss and action support
- **Music player** — album art, playback controls, and seek bar (any MPRIS player)
- **Music visualizer** — real-time CAVA-powered frequency bars
- **Wallpaper selector** — browse local folders or search Wallhaven online; animated transitions via awww
- **Material You theming** — colors extracted from your wallpaper; dark and light mode support
- **OSD** — smooth brightness and volume overlay on key press
- **Lock screen** — blurred wallpaper with clock, date, and profile avatar
- **Clipboard manager** — full history with image preview, powered by cliphist
- **Screenshot tool** — full screen, active window, or region capture via grimblast
- **Screen recording** — region or full-screen recording via wf-recorder with a live status pill
- **Settings panel** — configure theme, weather, AI, manga reader, Bluetooth, display, and more
- **Shutdown window** — power menu with shutdown, reboot, suspend, logout, and lock
- **Widget screen** — analog clock, date, system monitor, battery, pomodoro timer, and weather widgets
- **Manga reader** — browse WeebCentral and Comix.to, offline downloads, favorites, and read history
- **AI assistant** — chat interface powered by Google Gemini
- **Dock** — application dock with smooth hover animations

---

## Keybindings

Nebula registers global shortcuts that Hyprland dispatches to the shell. Add your own binds in your Lua keybindings file (e.g. `~/.config/hypr/lua/keybinds.lua`):

```lua
-- Pick whatever keys work for you
hl.bind("SUPER + L",             hl.dsp.global("quickshell:lock"),             { locked = true })
hl.bind("SUPER + SHIFT + S",     hl.dsp.global("quickshell:shutdown"),         { locked = true })
hl.bind("SUPER + CTRL + RETURN", hl.dsp.global("quickshell:appLauncher"))
hl.bind("SUPER + S",             hl.dsp.global("quickshell:toolsWidget"))
hl.bind("SUPER + V",             hl.dsp.global("quickshell:clipboard"))
hl.bind("SUPER + W",             hl.dsp.global("quickshell:wallpaperLauncher"))
hl.bind("SUPER + CTRL + S",      hl.dsp.global("quickshell:settingOpen"))
hl.bind("SUPER + A",             hl.dsp.global("quickshell:mangaReader"))
-- optional extras
hl.bind("SUPER + D",             hl.dsp.global("quickshell:dashboard"))
hl.bind("SUPER + N",             hl.dsp.global("quickshell:notification"))
hl.bind("SUPER + E",             hl.dsp.global("quickshell:weather"))
```

The `{ locked = true }` flag lets the bind fire even when the screen is locked.

---

## Installation

### Dependencies

| Package | Purpose |
|---------|---------|
| [Quickshell](https://quickshell.outfoxxed.me) | Shell framework |
| [awww](https://github.com/danyspin97/awww) | Wallpaper setter with transitions |
| `python-materialyoucolor` | Material You color extraction from wallpaper |
| `cava` | Audio visualizer |
| `cliphist` + `wl-copy` | Clipboard history |
| `grimblast` | Screenshot capture |
| `wf-recorder` | Screen recording |
| `playerctl` | MPRIS media player control |
| `brightnessctl` | Brightness control |
| `nmcli` (NetworkManager) | Network management |
| `bluez` / `bluetoothctl` | Bluetooth support |
| `pipewire` | Audio backend |

> `ddcutil` is optional — used for external monitor brightness via DDC/CI.

### Setup

```bash
# Clone into your Quickshell config directory
git clone https://github.com/iamSt3el/Nebula.git ~/.config/quickshell

# Launch
quickshell -p ~/.config/quickshell
```

> [!NOTE]
> Make sure your Hyprland session is running before launching Nebula.

### Autostart

Add this to your `hyprland.conf`:

```ini
exec-once = quickshell -p ~/.config/quickshell
```

---

## Configuration

Settings are stored at `~/.cache/quickshell/settings.json` and edited through the built-in **Settings panel**. Key options:

| Section | Options |
|---------|---------|
| **Theme** | Wallpaper directory, color scheme (dark/light), algorithm, transition type |
| **General** | Profile picture, display font, dock visibility, music visualizer on/off |
| **Weather** | Location (city or lat,lon), units (metric/imperial), refresh interval |
| **AI** | Google Gemini API key and model |
| **Wallhaven** | API key for online wallpaper search |

---

## Credits

| Person | Why |
|--------|-----|
| [end_4](https://github.com/end-4) | Inspiration and Quickshell patterns |
| [soramane](https://github.com/soramanew) | Design inspiration |
| [outfoxxed](https://outfoxxed.me/) | Creator of [Quickshell](https://quickshell.outfoxxed.me) |

---

<div align="center">
  <sub>made with ♥ and too many late nights</sub>
</div>
