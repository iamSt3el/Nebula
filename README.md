<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/logo/nebula-dark.svg">
  <img src="assets/logo/nebula-light.svg" alt="Nebula logo" width="96">
</picture>

# Nebula

A Material You desktop shell for Hyprland, built with [Quickshell](https://quickshell.outfoxxed.me).

[![Stars](https://img.shields.io/github/stars/iamSt3el/Nebula?style=flat-square&color=9ed49d&labelColor=1a1c19)](https://github.com/iamSt3el/Nebula/stargazers)
[![License](https://img.shields.io/badge/license-GPL%20v3-9ed49d?style=flat-square&labelColor=1a1c19)](LICENSE)
[![Tour](https://img.shields.io/badge/watch-the%20tour-9ed49d?style=flat-square&logo=youtube&logoColor=white&labelColor=1a1c19)](https://youtu.be/bYuwrP-WTCs)
[![Website](https://img.shields.io/badge/website-iamst3el.github.io%2FNebula-9ed49d?style=flat-square&labelColor=1a1c19)](https://iamst3el.github.io/Nebula/)

**[Website](https://iamst3el.github.io/Nebula/)** · [Install](#install) · [Command line](#command-line) · [Theming apps](#theming-other-apps)

<br>

<img src="assets/showcase/desktop.jpg" alt="Nebula on Hyprland: the top bar and desktop widgets for a clock, system load, the moon, the weather and the music player, over a green willow wallpaper" width="100%">

</div>

## What's inside

- **Colours from your wallpaper.** A Material You palette for the shell, and for your other apps if you want it.
- **A bar and dock you edit in place.** Any screen edge, drag items around, undo.
- **Dashboard and desktop widgets** laid out on grids you build yourself.
- **Launcher** for apps, maths (`=`), shell commands (`>`), emoji (`:`) and open windows (`w`).
- **Lock screen** with seven animated layouts, and an optional greetd greeter.
- **Everyday tools:** notifications, clipboard history, screenshots and recording, a wallpaper browser with Wallhaven search, and your phone over KDE Connect: a Phone panel for files, links and clipboard, plus bar items for its battery, notifications and calls.

## Install

Arch Linux only.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/iamSt3el/Nebula/master/install.sh)
```

The installer pulls the packages, builds the plugins, sets up Python, and compiles the
`nebula` command and installs it to `/usr/local/bin`. It then copies Nebula's Hyprland
config into `~/.config/hypr`, offering to back up that folder first:

- `hyprland.lua` loads everything below
- `lua/` holds the basics: monitors, settings, animations, window rules and keybinds
- `nebula/` holds what the shell needs: its shortcuts, layer rules, environment and
  `nebula start`

It also sets up kitty (`~/.config/kitty/kitty.conf`) and the Nebula greeter, a fastfetch
header in your palette that opens each new terminal, again offering a backup first.

> [!IMPORTANT]
> Nebula needs **Hyprland 0.56 or newer with a Lua config** (`~/.config/hypr/hyprland.lua`).
> The classic `hyprland.conf` format is not supported: the shell sends Hyprland its
> commands in Lua, which a `.conf` setup rejects. The installer's `hyprland.lua` is
> built from Hyprland's own defaults, so a `.conf` user starts from a working Lua config.

Then log in again and run `nebula setup` to pick a wallpaper, your colours and which
apps follow them. Running the installer again copies these files again, so keep your
own changes in a backup or a file of your own.

## Command line

The shell does its background work through one command, and you can use it too:

```bash
nebula start                          # or stop, restart
nebula setup                          # wallpaper, colours and apps, step by step
nebula wallpaper set ~/wallpaper/forest.png
nebula scheme set --mode light        # or --variant vibrant
nebula apps                           # which apps follow the palette
nebula doctor                         # anything missing?
```

`nebula help` lists everything else.

## Theming other apps

The palette is always written to `~/.cache/quickshell/colors.json`. Nebula can also
write it into kitty, tmux, Starship, btop, Hyprland, GTK, Qt, Papirus folders, Firefox and Zen
(through Pywalfox), Obsidian, Waybar and nwg-dock, using matugen-style templates in
`~/.config/matugen/templates/`. Pick the apps in `nebula setup` or with
`nebula apps enable|disable <id>`. If a file is one you wrote yourself, Nebula keeps
it as `<file>.bak` before replacing it the first time.

## Credits

[end_4](https://github.com/end-4) for inspiration, Quickshell patterns and
[rounded-polygon-qmljs](https://github.com/end-4/rounded-polygon-qmljs) ·
[soramane](https://github.com/soramanew) for design inspiration ·
[outfoxxed](https://outfoxxed.me/) for [Quickshell](https://quickshell.outfoxxed.me)

## License

[GNU GPL v3.0](LICENSE) · © 2026 iamSt3el

The material shape geometry in `plugins/Nebula/shapes.cpp` is a C++ port of
rounded-polygon-qmljs by end_4, used under its original
[Apache License 2.0](modules/MatrialShapes/LICENSE).
