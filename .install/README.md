# Installation Scripts

Organized installation scripts for the dotfiles.

## Structure

```
.install/
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

### Full installation (interactive)

```bash
./install.sh
```

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
