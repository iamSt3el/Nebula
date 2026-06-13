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

- **Bar** — workspaces, system tray, clock, network, battery, and media controls
- **Weather panel** — current conditions, hourly forecast, daily forecast, UV, pressure, humidity, wind, and visibility
- **App launcher** — fuzzy search across installed applications
- **Notification center** — grouped notifications with dismiss and action support
- **Music player** — album art, playback controls, and a smooth seek bar
- **Music visualizer** — real-time CAVA-powered frequency bars with custom colors
- **Wallpaper selector** — browse local folders or search Wallhaven online; animated transitions via awww
- **Material You theming** — colors extracted from your wallpaper using Matugen
- **OSD** — smooth overlay for brightness and volume changes
- **Lock screen** — blurred background with time, date, and profile art
- **Clipboard manager** — full history with image preview support
- **Screenshot tool** — full screen, active window, or region capture via grimblast
- **Settings panel** — configure everything in one place: theme, sound, networking, Bluetooth, AI, weather, display, manga reader, and keybindings
- **Bluetooth** — scan, pair, and manage devices
- **AI assistant** — powered by Google Gemini

---

## Installation

### Dependencies

| Package | Purpose |
|---------|---------|
| [Quickshell](https://quickshell.outfoxxed.me) | Shell framework |
| [awww](https://github.com/danyspin97/awww) | Wallpaper setter with transitions |
| [matugen](https://github.com/InioX/matugen) | Material You color generation |
| `cava` | Audio visualizer |
| `cliphist` + `wl-copy` | Clipboard history |
| `grimblast` | Screenshots |
| `playerctl` | Media player control |
| `brightnessctl` | Brightness control |
| `nmcli` | Network management |
| `bluez` / `bluetoothctl` | Bluetooth support |
| `pipewire` | Audio (PipeWire backend) |

> `ddcutil` is optional — used for external monitor brightness control.

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

Add this to your `hyprland.conf` to start Nebula automatically:

```ini
exec-once = quickshell -p ~/.config/quickshell
```

---

## Configuration

Settings are stored at `~/.cache/quickshell/settings.json` and can be edited through the built-in **Settings panel** (accessible from the bar). Key options include:

- **Theme** — wallpaper directory, color scheme (dark/light), Matugen algorithm, transition type
- **Wallhaven** — API key for online wallpaper search
- **Weather** — location (city name or lat,lon), units (metric/imperial), refresh interval
- **General** — profile picture, font, dock visibility, music visualizer settings
- **AI** — Google Gemini API key and model selection

---

## TODOs

- [x] Config file for easy customization
- [x] Weather widget and weather panel
- [x] App launcher
- [x] Notification system
- [x] Music visualizer
- [x] Wallpaper selector (local + Wallhaven)
- [x] OSD (brightness / volume)
- [x] Lock screen
- [x] Clipboard manager
- [x] Settings panel
- [x] Screenshot tool
- [x] Bluetooth support
- [x] AI assistant

---

## Credits

Big thanks to these awesome people:

| Person | Why |
|--------|-----|
| [end_4](https://github.com/end-4) | Inspiration and Quickshell patterns |
| [soramane](https://github.com/soramanew) | Design inspiration |
| [outfoxxed](https://outfoxxed.me/) | Creator of [Quickshell](https://quickshell.outfoxxed.me) |

---

<div align="center">
  <sub>made with ♥ and too many late nights</sub>
</div>
