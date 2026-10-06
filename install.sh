#!/usr/bin/env bash
# Nebula Shell — standalone installer
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/iamSt3el/Nebula/master/install.sh)
#        bash install.sh [--force] [--skip-sysupdate]
#
# Installs the Nebula shell, and puts its Hyprland shortcuts, layer rules and
# autostart in ~/.config/hypr/nebula/, loaded from hyprland.lua (backed up first).

# ── colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

RULE='──────────────────────────────────────────────────────────────'

STEP_N=0
TOTAL_STEPS=19
WARNINGS=()
START_TS=$SECONDS

ok()     { echo -e "   ${GREEN}✓${RESET} $*"; }
warn()   { echo -e "   ${YELLOW}▲${RESET} $*"; WARNINGS+=("$*"); }
info()   { echo -e "   ${DIM}· $*${RESET}"; }
step()   {
  STEP_N=$((STEP_N + 1))
  printf "\n${BOLD}${MAGENTA}%02d${RESET}${DIM}/%02d${RESET}  ${BOLD}%s${RESET}\n" \
    "$STEP_N" "$TOTAL_STEPS" "$*"
  echo -e "${DIM}${RULE}${RESET}"
}
banner() { echo -e "${BOLD}${CYAN}$*${RESET}"; }
die()    { echo -e "\n  ${RED}${BOLD}✗ FATAL${RESET}  ${RED}$*${RESET}\n" >&2; exit 1; }
has()    { command -v "$1" &>/dev/null; }

# ── XDG dirs ───────────────────────────────────────────────────────────────────
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# ── constants ─────────────────────────────────────────────────────────────────
REPO_URL="https://github.com/iamSt3el/Nebula.git"
INSTALL_DIR="$XDG_CONFIG_HOME/quickshell"
VENV_DIR="$XDG_STATE_HOME/quickshell/.venv"
PLUGIN_DIR="$INSTALL_DIR/plugins/WfRecorder"
NEBULA_PLUGIN_DIR="$INSTALL_DIR/plugins/Nebula"
LAUNCHER_DIR="$INSTALL_DIR/cli/launcher"

# ── option defaults ───────────────────────────────────────────────────────────
ask=true
SKIP_SYSUPDATE=false

# ── parse flags ───────────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    -f|--force)           ask=false ;;
    -s|--skip-sysupdate)  SKIP_SYSUPDATE=true ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "  -f, --force            Skip all confirmations"
      echo "  -s, --skip-sysupdate   Skip pacman -Syu"
      echo "  -h, --help             Show this help"
      exit 0 ;;
  esac
done

$SKIP_SYSUPDATE && TOTAL_STEPS=$((TOTAL_STEPS - 1))

# ── interactive wrapper (mirrors dots-hyprland's v()) ─────────────────────────
# Shows the command, optionally waits for confirmation, and handles failures.
v() {
  local execute=true
  if $ask; then
    echo -e "   ${DIM}${RULE}${RESET}"
    echo -e "   ${BOLD}run${RESET}  ${GREEN}$*${RESET}"
    while true; do
      echo -e "   ${DIM}[y] run    [s] skip    [e] exit    [!] run all without asking${RESET}"
      read -rp "   ❯ " p
      case $p in
        y|Y|"")  break ;;
        s|S)     execute=false; break ;;
        e|E)     die "Aborted by user." ;;
        "!")     ask=false; break ;;
        *)       echo -e "   ${DIM}enter y / s / e / !${RESET}" ;;
      esac
    done
  else
    echo -e "   ${DIM}❯ $*${RESET}"
  fi
  if $execute; then
    x "$@"
  else
    warn "Skipped: $*"
  fi
}

# ── error-handling executor (mirrors dots-hyprland's x()) ─────────────────────
x() {
  local status=0
  "$@" || status=$?
  while [[ $status -ne 0 ]]; do
    echo -e "   ${RED}✗ failed${RESET}  ${YELLOW}$*${RESET}"
    echo -e "   ${DIM}[r] retry    [i] ignore    [e] exit${RESET}"
    read -rp "   ❯ " p
    case $p in
      r|R|"") "$@" && status=0 || status=$? ;;
      i|I)    warn "Ignoring failure: $*"; return 0 ;;
      e|E)    die "Aborted." ;;
    esac
  done
}

# ── guard: no sudo / root ─────────────────────────────────────────────────────
[[ "$(whoami)" == "root" ]] && die "Run as your normal user, NOT as root or with sudo."

# ── banner ────────────────────────────────────────────────────────────────────
clear
banner "
  ███╗   ██╗███████╗██████╗ ██╗   ██╗██╗      █████╗
  ████╗  ██║██╔════╝██╔══██╗██║   ██║██║     ██╔══██╗
  ██╔██╗ ██║█████╗  ██████╔╝██║   ██║██║     ███████║
  ██║╚██╗██║██╔══╝  ██╔══██╗██║   ██║██║     ██╔══██║
  ██║ ╚████║███████╗██████╔╝╚██████╔╝███████╗██║  ██║
  ╚═╝  ╚═══╝╚══════╝╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝
"
echo -e "  ${DIM}a dreamy desktop shell for Hyprland, built with Quickshell${RESET}"
echo ""
echo -e "  ${DIM}repo${RESET}    ${CYAN}${REPO_URL}${RESET}"
echo -e "  ${DIM}target${RESET}  ${CYAN}${INSTALL_DIR}${RESET}"
echo -e "  ${DIM}venv${RESET}    ${CYAN}${VENV_DIR}${RESET}"
echo ""
echo -e "  ${DIM}Shortcuts, layer rules and autostart go in ~/.config/hypr/nebula/; hyprland.lua${RESET}"
echo -e "  ${DIM}gets a few require lines, after a backup. Nothing else in your config changes.${RESET}"
echo ""

# ── sanity: must be Arch ──────────────────────────────────────────────────────
has pacman || die "pacman not found — this installer is for Arch Linux only."

HYPR_DIR="$XDG_CONFIG_HOME/hypr"
if [[ -f "$HYPR_DIR/hyprland.conf" && ! -f "$HYPR_DIR/hyprland.lua" ]]; then
  info "Found hyprland.conf but no hyprland.lua — the installer will offer a starter Lua config."
fi

# ── offer backup ──────────────────────────────────────────────────────────────
step "Backup (optional)"
bk=n
if $ask; then
  echo -e "  Back up ${CYAN}~/.config${RESET} before we start? [y/N]"
  read -rp "   ❯ " bk
fi
case $bk in
  y|Y)
    BACKUP_DIR="$HOME/nebula-backup-$(date +%Y%m%d-%H%M%S)"
    info "Backing up to $BACKUP_DIR ..."
    has rsync || sudo pacman -S --needed --noconfirm rsync
    rsync -a --info=progress2 "$XDG_CONFIG_HOME/" "$BACKUP_DIR/config/"
    ok "Backup complete"
    ;;
  *) info "Skipping backup" ;;
esac

# ── base tools ────────────────────────────────────────────────────────────────
step "Base tools"
has git || v sudo pacman -S --needed --noconfirm git
has rsync || v sudo pacman -S --needed --noconfirm rsync
ok "git, rsync"

if ! has hyprland; then
  warn "Hyprland not found. You should have a running Hyprland session before launching Nebula."
fi

# ── system update ─────────────────────────────────────────────────────────────
if ! $SKIP_SYSUPDATE; then
  step "System update"
  v sudo pacman -Syu
fi

# ── AUR helper ────────────────────────────────────────────────────────────────
step "AUR helper"
AUR_HELPER=""
for h in yay paru; do has "$h" && { AUR_HELPER="$h"; break; }; done

if [[ -z "$AUR_HELPER" ]]; then
  warn "No AUR helper found — installing yay-bin..."
  v sudo pacman -S --needed --noconfirm base-devel
  tmpdir=$(mktemp -d)
  v git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
  (cd "$tmpdir/yay-bin" && x makepkg -si --noconfirm)
  rm -rf "$tmpdir"
  AUR_HELPER="yay"
fi
ok "AUR helper: $AUR_HELPER"

# ── clone / update repo ───────────────────────────────────────────────────────
step "Nebula source"
if [[ -d "$INSTALL_DIR/.git" ]]; then
  warn "$INSTALL_DIR already exists."
  upd=n
  if $ask; then
    echo -e "  Update to latest? [y/N]"
    read -rp "   ❯ " upd
  fi
  if [[ "${upd,,}" == "y" ]]; then
    v git -C "$INSTALL_DIR" fetch
    if git -C "$INSTALL_DIR" merge --ff-only "@{u}"; then
      ok "Updated to $(git -C "$INSTALL_DIR" rev-parse --short HEAD)"
    else
      warn "Local changes in $INSTALL_DIR block the update."
      rst=n
      if $ask; then
        echo -e "  Back up the folder and reset it to the latest version? [y/N]"
        read -rp "   ❯ " rst
      fi
      if [[ "${rst,,}" == "y" ]]; then
        RESET_BAK="${INSTALL_DIR}.bak.$(date +%s)"
        cp -a "$INSTALL_DIR" "$RESET_BAK"
        ok "Backed up to $RESET_BAK"
        v git -C "$INSTALL_DIR" reset --hard "@{u}"
      else
        die "Commit, stash or remove your changes in $INSTALL_DIR and re-run."
      fi
    fi
  else
    ok "Keeping existing install"
  fi
else
  if [[ -d "$INSTALL_DIR" ]]; then
    warn "$INSTALL_DIR exists but is not a git repo."
    rep=n
    if $ask; then
      echo -e "  Back it up and replace? [y/N]"
      read -rp "   ❯ " rep
    fi
    [[ "${rep,,}" == "y" ]] || die "Move or delete $INSTALL_DIR and re-run."
    mv "$INSTALL_DIR" "${INSTALL_DIR}.bak.$(date +%s)"
    ok "Backed up"
  fi
  v git clone "$REPO_URL" "$INSTALL_DIR"
fi

# ── pacman packages ───────────────────────────────────────────────────────────
step "Pacman packages"
PACMAN_PKGS=(
  hyprland hypridle hyprpicker
  pipewire pipewire-pulse wireplumber libpipewire libpulse
  networkmanager bluez bluez-utils upower
  python grim slurp wf-recorder swappy wl-clipboard wtype ffmpeg ffmpegthumbnailer
  cava brightnessctl playerctl curl unzip jq xdg-utils libnotify qrencode sound-theme-freedesktop
  imagemagick kdeconnect sshfs mpv tesseract tesseract-data-eng gperftools
  qt6-base qt6-declarative qt6-wayland qt6-svg qt6-multimedia
  libqalculate
  noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-fira-sans ttf-fira-code ttf-jetbrains-mono
  gcc cmake extra-cmake-modules
)
pacman -Qq quickshell-git &>/dev/null || PACMAN_PKGS+=(quickshell)
PACMAN_PKGS_OPT=(ddcutil papirus-icon-theme yt-dlp)
v sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS_OPT[@]}" \
  || warn "Optional packages failed (ddcutil, papirus-icon-theme, yt-dlp)"

# ── uv (fast Python package manager) ─────────────────────────────────────────
step "uv (Python toolchain)"
if ! has uv; then
  info "Installing uv (direct binary download — avoids installer script hang)..."
  _UV_ARCH="$(uname -m)-unknown-linux-gnu"
  _UV_TMP="/tmp/uv-${_UV_ARCH}.tar.gz"
  mkdir -p "$HOME/.local/bin"
  curl -LsSf \
    "https://github.com/astral-sh/uv/releases/latest/download/uv-${_UV_ARCH}.tar.gz" \
    -o "$_UV_TMP"
  tar -xzf "$_UV_TMP" -C /tmp/
  install -m755 "/tmp/uv-${_UV_ARCH}/uv"  "$HOME/.local/bin/uv"
  install -m755 "/tmp/uv-${_UV_ARCH}/uvx" "$HOME/.local/bin/uvx"
  rm -rf "$_UV_TMP" "/tmp/uv-${_UV_ARCH}"
  export PATH="$HOME/.local/bin:$PATH"
fi
ok "uv: $(uv --version 2>/dev/null || echo 'installed')"

# ── AUR packages ──────────────────────────────────────────────────────────────
step "AUR packages"
AUR_PKGS=(
  grimblast-git cliphist
  matugen-bin
  ttf-material-symbols-variable-git
)
AUR_PKGS_OPT=(gowall)

if $ask; then
  for pkg in "${AUR_PKGS[@]}"; do v "$AUR_HELPER" -S --needed "$pkg"; done
else
  v "$AUR_HELPER" -S --needed --noconfirm "${AUR_PKGS[@]}"
fi

info "Installing optional packages (gowall for palette recolouring)..."
if $ask; then
  for pkg in "${AUR_PKGS_OPT[@]}"; do v "$AUR_HELPER" -S --needed "$pkg" || true; done
else
  "$AUR_HELPER" -S --needed --noconfirm "${AUR_PKGS_OPT[@]}" || warn "Optional AUR package failed (gowall)"
fi

# Rubik (UI) and Titan One (display) straight from the Google Fonts repo;
# the ttf-rubik AUR package is broken
step "Fonts"
FONTS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
GF="https://raw.githubusercontent.com/google/fonts/main"
mkdir -p "$FONTS_DIR"

fetch_font() {
  local name="$1" dir="$2"; shift 2
  if fc-list | grep -qi "$name"; then
    ok "$name already installed"
    return
  fi
  local pair
  for pair in "$@"; do
    curl -L --fail -s "$GF/$dir/${pair%%|*}" -o "$FONTS_DIR/${pair##*|}" \
      || { warn "$name download failed"; return; }
  done
  ok "$name installed"
}

fetch_font "Rubik"             ofl/rubik              "Rubik%5Bwght%5D.ttf|Rubik[wght].ttf" "Rubik-Italic%5Bwght%5D.ttf|Rubik-Italic[wght].ttf"
fetch_font "Titan One"         ofl/titanone           "TitanOne-Regular.ttf|TitanOne-Regular.ttf"
fetch_font "Just Another Hand" apache/justanotherhand "JustAnotherHand-Regular.ttf|JustAnotherHand-Regular.ttf"
fc-cache -f "$FONTS_DIR" >/dev/null

# ── Python venv via uv ────────────────────────────────────────────────────────
step "Python environment"
mkdir -p "$(dirname "$VENV_DIR")"
v uv venv --prompt nebula "$VENV_DIR" -p 3.12
v uv pip install materialyoucolor Pillow --python "$VENV_DIR/bin/python"
ok "Python venv ready at $VENV_DIR"

# ── WfRecorder plugin ─────────────────────────────────────────────────────────
step "WfRecorder plugin"
if [[ -f "$PLUGIN_DIR/build.sh" ]]; then
  v sudo pacman -S --needed --noconfirm cmake extra-cmake-modules
  v bash "$PLUGIN_DIR/build.sh"
  ok "Plugin built"
else
  warn "No build.sh at $PLUGIN_DIR — skipping (screen recording may not work)"
fi

# ── Nebula plugin (stats, sparklines, material shapes) ────────────────────────
step "Nebula plugin"
if [[ -f "$NEBULA_PLUGIN_DIR/build.sh" ]]; then
  v bash "$NEBULA_PLUGIN_DIR/build.sh"
  ok "Plugin built"
else
  warn "No build.sh at $NEBULA_PLUGIN_DIR — stats, sparklines and shapes need it"
fi

# ── nebula command ────────────────────────────────────────────────────────────
step "nebula command"
NEBULA_BIN="/usr/local/bin/nebula"
NEBULA_CMD="nebula"
if [[ -f "$LAUNCHER_DIR/build.sh" ]]; then
  v bash "$LAUNCHER_DIR/build.sh"
  [[ -x "$LAUNCHER_DIR/build/nebula" ]] && v sudo install -Dm755 "$LAUNCHER_DIR/build/nebula" "$NEBULA_BIN"
fi
if [[ -x "$NEBULA_BIN" ]] && cmp -s "$LAUNCHER_DIR/build/nebula" "$NEBULA_BIN"; then
  [[ -L "$HOME/.local/bin/nebula" ]] && rm -f "$HOME/.local/bin/nebula"
  ok "nebula installed to $NEBULA_BIN (run \`nebula help\`)"
else
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$INSTALL_DIR/bin/nebula" "$HOME/.local/bin/nebula"
  NEBULA_CMD="~/.local/bin/nebula"
  warn "nebula was not installed to $NEBULA_BIN — linked ~/.local/bin/nebula instead"
fi

# ── wallpaper directory ───────────────────────────────────────────────────────
step "Wallpaper directory"
WALLPAPER_DIR="$HOME/wallpaper"
[[ -d "$WALLPAPER_DIR" ]] || { mkdir -p "$WALLPAPER_DIR"; ok "Created $WALLPAPER_DIR"; }
if [[ -z "$(ls -A "$WALLPAPER_DIR" 2>/dev/null)" ]]; then
  cp "$INSTALL_DIR/assets/wallpapers/nebula-default.jpg" "$WALLPAPER_DIR/" && ok "Added a starter wallpaper"
fi
ok "Wallpapers → $WALLPAPER_DIR"

# ── services ──────────────────────────────────────────────────────────────────
step "Systemd services"
for svc in pipewire wireplumber; do
  systemctl --user enable --now "$svc" 2>/dev/null && ok "$svc (user)" || warn "Could not enable $svc"
done
for svc in NetworkManager bluetooth upower; do
  sudo systemctl enable --now "$svc" 2>/dev/null && ok "$svc (system)" || warn "Could not enable $svc"
done

# ── user groups ───────────────────────────────────────────────────────────────
step "User groups"
v sudo usermod -aG video,input "$(whoami)"

# ── NEBULA_VENV env var + QML_IMPORT_PATH ─────────────────────────────────────
step "Shell environment"

ENV_BLOCK="
# Nebula shell
export NEBULA_VENV=\"$VENV_DIR\"
export QML_IMPORT_PATH=\"\$HOME/.local/lib/qt6/qml:\${QML_IMPORT_PATH:-}\"
"

patch_profile() {
  local file="$1"
  [[ -f "$file" ]] || return
  if grep -q "NEBULA_VENV" "$file"; then
    ok "Already patched: $file"
  else
    echo "$ENV_BLOCK" >> "$file"
    ok "Patched: $file"
  fi
}

patch_profile "$HOME/.bashrc"
patch_profile "$HOME/.zshrc"
patch_profile "$HOME/.profile"

FISH_CONF="$XDG_CONFIG_HOME/fish/config.fish"
if [[ -f "$FISH_CONF" ]] && ! grep -q "NEBULA_VENV" "$FISH_CONF"; then
  {
    echo ""
    echo "# Nebula shell"
    echo "set -gx NEBULA_VENV \"$VENV_DIR\""
    echo "set -gx QML_IMPORT_PATH \"\$HOME/.local/lib/qt6/qml\" \$QML_IMPORT_PATH"
  } >> "$FISH_CONF"
  ok "Patched: $FISH_CONF"
fi

# ── colour templates ──────────────────────────────────────────────────────────
# Nebula renders app colours itself (`nebula apps`) from these templates;
# matugen is only used for the album-art palette.
step "Colour templates"
MATUGEN_DIR="$XDG_CONFIG_HOME/matugen"
TPL_SRC="$INSTALL_DIR/config/matugen"
mkdir -p "$MATUGEN_DIR/templates"
rsync -a --update "$TPL_SRC/templates/" "$MATUGEN_DIR/templates/"
if [[ -f "$MATUGEN_DIR/music_config.toml" ]]; then
  ok "music_config.toml already present"
else
  cp "$TPL_SRC/music_config.toml" "$MATUGEN_DIR/music_config.toml"
  ok "Created $MATUGEN_DIR/music_config.toml"
fi
ok "Templates in $MATUGEN_DIR/templates"

# ── Hyprland config ───────────────────────────────────────────────────────────
step "Hyprland config"
HYPR_NEBULA="$HYPR_DIR/nebula"
HYPR_LUA="$HYPR_DIR/hyprland.lua"
mkdir -p "$HYPR_NEBULA"
for f in "$INSTALL_DIR/config/hypr/nebula/"*.lua; do
  [[ "$(basename "$f")" == "keybinds.lua" && -f "$HYPR_NEBULA/keybinds.lua" ]] && continue
  cp "$f" "$HYPR_NEBULA/"
done
[[ "$NEBULA_CMD" != "nebula" ]] && sed -i "s|\"nebula start\"|\"$NEBULA_CMD start\"|" "$HYPR_NEBULA/autostart.lua"
ok "Shortcuts, layer rules, environment and autostart → $HYPR_NEBULA"

hypr_has() { grep -rqsE --include='*.lua' --exclude-dir=nebula "$1" "$HYPR_DIR"; }
nebula_require() {
  if hypr_has "$2"; then
    echo "-- require(\"nebula.$1\")"
    info "Left nebula.$1 commented out: your config already has it" >&2
  else
    echo "require(\"nebula.$1\")"
  fi
}

if [[ ! -f "$HYPR_LUA" ]]; then
  mk=y
  if $ask; then
    echo -e "  No ${CYAN}hyprland.lua${RESET} yet. Create one from Hyprland's defaults with Nebula added? [Y/n]"
    [[ -f "$HYPR_DIR/hyprland.conf" ]] && echo -e "  ${DIM}hyprland.conf stays on disk, but Hyprland uses hyprland.lua once it exists.${RESET}"
    read -rp "   ❯ " mk
  fi
  if [[ "${mk,,}" != "n" ]]; then
    cp "$INSTALL_DIR/config/hypr/hyprland.lua" "$HYPR_LUA"
    mkdir -p "$HYPR_DIR/lua"
    cp -n "$INSTALL_DIR/config/hypr/lua/"*.lua "$HYPR_DIR/lua/"
    ok "Created $HYPR_LUA and $HYPR_DIR/lua/ (starter config with Nebula)"
  else
    warn "No $HYPR_LUA — Nebula needs a Lua config that loads require(\"nebula.<name>\") from $HYPR_NEBULA."
  fi
elif grep -qE '^[^-]*require\("nebula\.' "$HYPR_LUA"; then
  ok "hyprland.lua already loads Nebula"
else
  hk=y
  if $ask; then
    echo -e "  Load Nebula's shortcuts, layer rules and autostart from ${CYAN}hyprland.lua${RESET}? [Y/n]"
    read -rp "   ❯ " hk
  fi
  if [[ "${hk,,}" != "n" ]]; then
    HYPR_BAK="$HYPR_LUA.bak.$(date +%s)"
    cp "$HYPR_LUA" "$HYPR_BAK"
    {
      echo ""
      nebula_require environment 'NEBULA_VENV'
      nebula_require autostart 'exec_cmd\("([^"]*[ ;&/])?(nebula start|quickshell|qs)( |")'
      nebula_require keybinds 'hl\.dsp\.global\("quickshell:'
      nebula_require rules 'namespace *= *"quickshell:'
    } >> "$HYPR_LUA"
    ok "hyprland.lua now loads Nebula (backup: $HYPR_BAK)"
  else
    info "Skipped — add require(\"nebula.<name>\") lines to hyprland.lua yourself"
  fi
fi

# ── done ──────────────────────────────────────────────────────────────────────
ELAPSED=$((SECONDS - START_TS))

echo ""
echo -e "${GREEN}${BOLD}  ✓  Nebula installed${RESET}  ${DIM}in $((ELAPSED / 60))m $((ELAPSED % 60))s${RESET}"
echo -e "${DIM}  ${RULE}${RESET}"
echo ""
echo -e "  ${BOLD}launch${RESET}      ${CYAN}nebula start${RESET}"
echo -e "  ${BOLD}wallpapers${RESET}  ${CYAN}~/wallpaper/${RESET}"
echo -e "  ${BOLD}set up${RESET}      ${CYAN}nebula setup${RESET}  ${DIM}(once the shell is running)${RESET}"
echo ""
echo -e "  ${DIM}Reload your shell (or log out and back in) to pick up NEBULA_VENV${RESET}"
echo -e "  ${DIM}and QML_IMPORT_PATH.${RESET}"
echo ""
echo -e "${DIM}  ${RULE}${RESET}"
echo -e "  ${BOLD}Hyprland${RESET}    ${CYAN}$HYPR_DIR/nebula/${RESET}  ${DIM}(shortcuts, layer rules, autostart)${RESET}"
echo -e "  ${DIM}Log out and back in to start Nebula with Hyprland. Edit keybinds.lua there to change keys.${RESET}"
echo ""
echo -e "  ${YELLOW}Nebula needs Hyprland 0.56+ with a Lua config.${RESET} ${DIM}hyprland.conf is not supported.${RESET}"
echo ""

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo -e "${DIM}  ${RULE}${RESET}"
  echo -e "  ${YELLOW}${BOLD}${#WARNINGS[@]} warning(s) during install${RESET}"
  echo ""
  for w in "${WARNINGS[@]}"; do
    echo -e "   ${YELLOW}▲${RESET} ${DIM}${w}${RESET}"
  done
  echo ""
fi
