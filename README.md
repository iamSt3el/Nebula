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

### One-line install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/iamSt3el/Nebula/master/install.sh)
```

That's it. The script:

1. Installs an AUR helper (`yay`) if you don't have one
2. Installs all required pacman and AUR packages
3. Clones Nebula to `~/.config/quickshell` (or updates it if already there)
4. Sets up the Python venv and installs required packages
5. Builds the WfRecorder screen-recording plugin
6. Adds `QML_IMPORT_PATH` to your shell profile (bash / zsh / fish)
7. Optionally adds the autostart line to your `hyprland.conf`

> [!NOTE]
> Requires Arch Linux (uses `pacman`). Start a Hyprland session before running
> if you want the autostart step to detect your `hyprland.conf`.

---

### Dependencies

#### System packages

| Package | Purpose |
|---------|---------|
| [Quickshell](https://quickshell.outfoxxed.me) (`quickshell-git`) | Shell framework |
| `hyprland` | Wayland compositor |
| `pipewire` + `wireplumber` | Audio backend |
| `networkmanager` (`nmcli`) | Network management |
| `bluez` + `bluez-utils` | Bluetooth support |
| `upower` | Battery info |
| [awww](https://github.com/danyspin97/awww) (`awww-git`) | Wallpaper setter with transitions |
| `grim` + `grimblast` | Screenshot capture |
| `wf-recorder` | Screen recording |
| `swappy` | Screenshot annotation |
| `wl-clipboard` (`wl-copy` / `wl-paste`) | Clipboard operations |
| `cliphist` | Clipboard history |
| `cava` | Audio visualizer |
| `brightnessctl` | Screen brightness |
| `matugen` (`matugen-bin`) | Music color themes |
| `curl` | Weather data |
| `python3` | Color engine + manga servers |

> `ddcutil` is optional — external monitor brightness via DDC/CI.
> `hyprlock` / `hypridle` are optional — lock screen and idle management.
> `ollama` is optional — local AI assistant.

#### Python packages

Install into the project venv (the installer handles this automatically):

```bash
python3 -m venv ~/.config/quickshell/scripts/.venv
~/.config/quickshell/scripts/.venv/bin/pip install materialyoucolor requests Pillow
```

#### Fonts

| Font | AUR package |
|------|-------------|
| [Material Symbols Rounded](https://fonts.google.com/icons) | `ttf-material-symbols-variable-git` |
| [Rubik](https://fonts.google.com/specimen/Rubik) | `ttf-rubik` |

### Setup

```bash
# Build and install the WfRecorder plugin
bash ~/.config/quickshell/plugins/WfRecorder/build.sh

# Make Qt find the plugin
export QML_IMPORT_PATH="$HOME/.local/lib/qt6/qml:$QML_IMPORT_PATH"

# Launch
quickshell -p ~/.config/quickshell
```

> [!NOTE]
> Add the `QML_IMPORT_PATH` export to your shell profile (`.bashrc`, `.zshrc`, or equivalent) so it persists across sessions.

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
| [end_4](https://github.com/end-4) | Inspiration, Quickshell patterns, and [rounded-polygon-qmljs](https://github.com/end-4/rounded-polygon-qmljs) (bundled in `modules/MatrialShapes`) |
| [soramane](https://github.com/soramanew) | Design inspiration |
| [outfoxxed](https://outfoxxed.me/) | Creator of [Quickshell](https://quickshell.outfoxxed.me) |

---

<div align="center">
  <sub>made with ♥ and too many late nights</sub>
</div>
