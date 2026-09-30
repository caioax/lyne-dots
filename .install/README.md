# Installation Scripts

Organized installation scripts for the dotfiles.

## Structure

```
.install/
├── lib/                # Installer building blocks (plain bash)
│   ├── log.sh          # log_info/log_warn/... (plain text in the log file)
│   ├── ui.sh           # Full-screen drawing, keys, ASCII set for the console
│   ├── ask.sh          # Questionnaire: every question before installing
│   └── run.sh          # Unattended steps: progress, log, sudo keepalive, dry run
├── packages/           # Package lists by category
│   ├── core.sh         # Hyprland, UWSM, portal
│   ├── terminal.sh     # Kitty, Zsh, Tmux
│   ├── editor.sh       # Neovim + dev tools
│   ├── apps.sh         # Dolphin, Zen Browser, Spotify, ZapZap
│   ├── utils.sh        # Clipboard, audio, bluetooth
│   ├── fonts.sh        # Nerd Fonts, cursors, icons
│   ├── quickshell.sh   # QuickShell
│   ├── theming.sh      # Qt/GTK theming
│   └── nvidia.sh       # NVIDIA drivers (optional)
└── setup/              # Configuration scripts
    ├── stow.sh         # Creates symlinks with GNU Stow
    └── hyprland.sh     # Configures local Hyprland files
```

## Usage

### Full installation

```bash
./install.sh
```

Every question comes first (packages; graphics: the GPUs found and whether
to add the NVIDIA environment, preselected from them; reboot), then a review
screen. After the sudo password (asked once and kept alive) the
install runs without further questions, showing each step, a progress bar and
the latest output. Everything goes to `~/.cache/lyne/install-<date>.log`.
Files already where the dotfiles are linked are moved to
`~/.lyne-dots-backup/<date>/`.

### Unattended, with the answers in a file

```bash
cat > answers <<EOF
categories=core terminal utils fonts quickshell theming
reboot=no
EOF
./install.sh --answers answers
```

Without `nvidia_env`, it follows the GPUs found. `lyne gpu` lists them
(`.data/lyne-cli/lib/gpus.sh`, reading sysfs and pci.ids only).

### Dry run

```bash
./install.sh --dry-run
```

Changes nothing: HOME is a throwaway folder and sudo, `pacman -S`, yay, stow,
systemctl, chsh, reboot... are stand-ins that only log what they would do.
`LYNE_DRY_HOME=dir` reuses a folder, `LYNE_DRY_FRESH=1` acts as if no
package were installed, `LYNE_DRY_FAIL="git ping"` makes those commands fail.

### Create symlinks only

```bash
./install.sh --stow-only
```

### Configure Hyprland only

```bash
./install.sh --setup-only
```

### Install a specific category

```bash
./install.sh --packages core
./install.sh --packages terminal
```

## Package Categories

| Category   | Description                                    |
| ---------- | ---------------------------------------------- |
| core       | Hyprland, UWSM, swww, portal (ESSENTIAL)      |
| terminal   | Kitty, Zsh, Tmux, Fastfetch                    |
| editor     | Neovim + development tools                     |
| apps       | Dolphin, Zen Browser, Spotify, ZapZap, mpv     |
| utils      | Clipboard, audio, bluetooth, brightnessctl     |
| fonts      | Nerd Fonts, Bibata cursor, Tela icons          |
| quickshell | QuickShell bar/shell + Qt6                     |
| theming    | Qt5ct, Qt6ct, Kvantum, nwg-look                |
| nvidia     | NVIDIA drivers (install only if needed)        |

## Templates and Data

On first install, templates from `.data/` are copied to generate machine-specific configuration files. Wallpapers from `.data/wallpapers/` are copied to `~/.local/wallpapers/`.

Configuration templates are in `.data/hyprland/templates/`:

- `monitors.conf` - Generic monitor configuration
- `extra_environment.conf` - Local environment variables
- `extra_environment_nvidia.conf` - NVIDIA variables
- `autostart.conf` - Local autostart
- `extra_keybinds.conf` - Local keybinds

NVIDIA UWSM templates are in `.data/hyprland/uwsm/`:

- `global_hardware.sh` - Global Wayland variables
- `hyprland_hardware.sh` - Hyprland-specific settings

## Stow Directories

The `stow.sh` script creates symlinks for:

| Directory  | Target                |
| ---------- | --------------------- |
| hyprland   | ~/.config/hypr        |
| quickshell | ~/.config/quickshell  |
| kitty      | ~/.config/kitty       |
| nvim       | ~/.config/nvim        |
| zsh        | ~/.zshrc, ~/.p10k.zsh |
| tmux       | ~/.tmux.conf          |
| local      | ~/.local/scripts      |
| fastfetch  | ~/.config/fastfetch   |
| theming    | ~/.config/gtk-3.0, gtk-4.0, qt5ct, qt6ct |
| kde        | ~/.config/kdeglobals  |
