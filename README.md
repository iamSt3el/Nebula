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

### Bar
The top bar is the hub for everything. It shows active workspaces, a system tray, clock, network status, battery indicator, and quick-access buttons for weather, notifications, dashboard, bluetooth, and wifi. All bar widgets open their respective panels inline.

### Panels & Overlays
| Component | Description |
|-----------|-------------|
| **Weather panel** | Current conditions, hourly and daily forecast, UV index, pressure, humidity, wind speed, and visibility |
| **App launcher** | Fuzzy search across all installed applications, keyboard-driven |
| **Notification center** | Grouped notifications with dismiss, clear all, and action button support |
| **Music player** | Album art, playback controls, seek bar, and track info from any MPRIS-compatible player |
| **Music visualizer** | Real-time CAVA-powered frequency bars rendered behind windows |
| **Clipboard manager** | Full clipboard history with image preview support, powered by cliphist |
| **Wallpaper selector** | Browse local folders or search Wallhaven online; animated transitions via awww |
| **Tools widget** | Quick-access panel for common actions and utilities |
| **Settings panel** | Full configuration UI: theme, fonts, weather, AI, manga reader, Bluetooth, display, and more |
| **Shutdown window** | Power menu with shutdown, reboot, suspend, logout, and lock options |
| **Dock** | Application dock with smooth hover animations |

### System
| Component | Description |
|-----------|-------------|
| **Material You theming** | Colors extracted from your wallpaper using a Python script with `materialyoucolor`; dark and light mode support |
| **OSD** | Smooth brightness and volume overlay that appears on hardware key press |
| **Lock screen** | Blurred wallpaper background with clock, date, and profile avatar |
| **Greeter (login)** | greetd-integrated login screen with a digit-block clock, password input, and power buttons |
| **Screenshot tool** | Full screen, active window, or region capture via grimblast |
| **Screen recording** | Region or full-screen recording via wf-recorder, with a status pill while active |

### Widgets screen
A dedicated full-screen widget overlay with:
- Analog clock
- Bold date widget
- System monitor (CPU, memory, disk)
- Compact system monitor
- Battery widget
- Pomodoro timer
- Weather summary and forecast widgets

### Manga reader
A built-in manga reader with:
- Browse and search from **WeebCentral** and **Comix.to**
- Hot, latest, manhwa, manga, and manhua category filters
- Favorites list with new-chapter badges
- Offline chapter downloads with circular progress indicators
- Read history tracking

### AI assistant
Chat interface powered by Google Gemini, configurable from the Settings panel.

---

## Keybindings

### Quickshell globals (Hyprland → Shell)

| Shortcut | Action |
|----------|--------|
| `Super + L` | Lock screen |
| `Super Shift + S` | Shutdown / power menu |
| `Super Ctrl + Enter` | App launcher |
| `Super + S` | Tools widget |
| `Super + V` | Clipboard manager |
| `Super + W` | Wallpaper selector |
| `Super Ctrl + S` | Settings panel |
| `Super + A` | Manga reader |

> These all use `hyprctl dispatch global quickshell:<name>` under the hood.  
> Additional globals available via IPC: `dashboard`, `notification`, `weather`, `wifi`, `bluetooth`, `brightnessIncrease`, `brightnessDecrease`.

### Greeter preview (dev / testing)

| Command | Action |
|---------|--------|
| `hyprctl dispatch global quickshell:greeterpreview` | Toggle the greeter preview overlay (for testing without rebooting) |
| `Esc` | Close the greeter preview |

### Lock screen triggers

| Command | Action |
|---------|--------|
| `loginctl lock-session` | Lock (used by hypridle on idle timeout) |
| `hyprctl dispatch global quickshell:lock` | Lock immediately |

### Window management

| Shortcut | Action |
|----------|--------|
| `Super + Q` | Close active window |
| `Super + F` | Toggle fullscreen |
| `Super + T` | Toggle floating |
| `Super + J` | Toggle split direction |
| `Super + G` | Toggle window group |
| `Super + ←/→/↑/↓` | Move focus |
| `Super Shift + ←/→/↑/↓` | Resize window |
| `Super Alt + ←/→/↑/↓` | Swap tiled windows |
| `Super + 1–0` | Switch to workspace 1–10 |
| `Super Shift + 1–0` | Move window to workspace 1–10 |
| `Super + Tab` | Next workspace |
| `Super Shift + Tab` | Previous workspace |
| `Super Ctrl + ↓` | Open next empty workspace |

### Applications

| Shortcut | Action |
|----------|--------|
| `Super + Enter` | Terminal |
| `Super + B` | Browser |
| `Super + E` | File manager |
| `Super Ctrl + E` | Emoji picker |
| `Super Ctrl + C` | Calculator |
| `Super + Print` | Screenshot |

### Media & hardware keys

| Key | Action |
|-----|--------|
| `XF86MonBrightnessUp/Down` | Brightness ±10% |
| `XF86AudioRaiseVolume/LowerVolume` | Volume ±5% |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioPlay/Pause/Next/Prev` | Media playback |
| `XF86AudioMicMute` | Toggle microphone |

---

## Installation

### Dependencies

| Package | Purpose |
|---------|---------|
| [Quickshell](https://quickshell.outfoxxed.me) | Shell framework |
| [awww](https://github.com/danyspin97/awww) | Wallpaper setter with transitions |
| `python-materialyoucolor` | Material You color extraction from wallpaper |
| `cava` | Audio visualizer (music visualizer feature) |
| `cliphist` + `wl-copy` | Clipboard history |
| `grimblast` | Screenshot capture |
| `wf-recorder` | Screen recording |
| `playerctl` | MPRIS media player control |
| `brightnessctl` | Brightness control |
| `nmcli` (NetworkManager) | Network management |
| `bluez` / `bluetoothctl` | Bluetooth support |
| `pipewire` | Audio backend |

> `ddcutil` is optional — used for external monitor brightness control via DDC/CI.  
> `greetd` is optional — required only if you want Nebula as your login screen greeter.

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

Settings are stored at `~/.cache/quickshell/settings.json` and can be edited through the built-in **Settings panel** (`Super Ctrl + S`). Key options:

| Section | Options |
|---------|---------|
| **Theme** | Wallpaper directory, color scheme (dark/light), algorithm, transition type |
| **General** | Profile picture, display font, dock visibility, music visualizer on/off |
| **Weather** | Location (city name or lat,lon), units (metric/imperial), refresh interval |
| **AI** | Google Gemini API key and model selection |
| **Wallhaven** | API key for online wallpaper search |
| **Manga** | Default source, download directory |

---

## Greeter setup (optional)

To use Nebula as your login greeter with `greetd`, point greetd at Quickshell:

```toml
# /etc/greetd/config.toml
[default_session]
command = "quickshell -p /home/<user>/.config/quickshell"
```

The greeter screen is separate from the lock screen — it shows a digit-block clock, user avatar, password field, and power buttons. To preview it without rebooting, use:

```bash
hyprctl dispatch global quickshell:greeterpreview
```

Press `Esc` to close the preview.

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
