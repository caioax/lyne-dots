# 📦 Lyne Dots

> Arch Linux dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/), featuring a Hyprland (Wayland) desktop environment with a custom QuickShell bar and a unified theme system that applies across the entire setup.

---

## 📸 Screenshots

### Tokyo Night

![Tokyo Night](./.data/assets/tokyonight.png)

### Catppuccin Mocha

![Catppuccin Mocha](./.data/assets/catppuccin-mocha.png)

### Dracula

![Dracula](./.data/assets/dracula.png)

### Gruvbox Dark

![Gruvbox Dark](./.data/assets/gruvbox-dark.png)

### Nord

![Nord](./.data/assets/nord.png)

### Rose Pine

![Rose Pine](./.data/assets/rosepine.png)

## ✨ Features

- 🪟 **Hyprland** - Tiling Wayland compositor with modular configuration
- 🖥️ **QuickShell** - Custom QML-based status bar, launcher, notifications, quick settings, and power menu
- 🎨 **Dynamic Theming** - 11 themes (6 dark + 5 light variants) applied live across the entire system, plus a **Material You** auto mode that generates colors from your wallpaper
- 🖼️ **Wallpaper Picker** - Built-in wallpaper manager with search, favorites, and per-theme wallpaper folders
- 📸 **Screenshot Tool** - Multi-monitor region/fullscreen capture with annotation overlay
- ✏️ **Neovim** - Lua-based configuration with LSP, Telescope, Smart Splits, and lazy.nvim
- 📟 **Tmux** - Terminal multiplexer with seamless Neovim navigation (Smart Splits)
- 🐱 **Kitty** - GPU-accelerated terminal with dynamic theme switching
- ⚡ **Zsh** - Oh-My-Zsh with autosuggestions, syntax highlighting, vi-mode, and Powerlevel10k
- 🔧 **Lyne CLI** - Built-in command-line tool for managing the dotfiles

### 🎨 Theme System

Switching themes from the Quick Settings panel or CLI applies colors instantly to:

| Component                                 | What changes                                |
| ----------------------------------------- | ------------------------------------------- |
| QuickShell (bar, launcher, notifications) | All UI colors                               |
| Kitty                                     | Terminal colors, cursor, tabs, borders      |
| Neovim                                    | Colorscheme (sent to all running instances) |
| Hyprland                                  | Active/inactive border colors, shadow       |
| GTK / Qt                                  | Application theme colors                    |
| Wallpaper                                 | Theme-linked wallpaper applied via awww     |

No restarts required.

**Available presets:**

| Dark             | Light            |
| ---------------- | ---------------- |
| Tokyo Night      | Tokyo Night Day  |
| Catppuccin Mocha | Catppuccin Latte |
| Dracula          | —                |
| Gruvbox Dark     | Gruvbox Light    |
| Nord             | Nord Light       |
| Rose Pine        | Rose Pine Dawn   |

**Material You mode** generates a color palette from your current wallpaper using [matugen](https://github.com/InioX/matugen), supporting both dark and light schemes. Enable it from Quick Settings or with `lyne theme auto`.

---

## 📦 Installation

### Requirements

- Arch Linux
- Git
- Internet connection

### Steps

```bash
git clone https://github.com/caioax/lyne-dots.git ~/.lyne-dots
cd ~/.lyne-dots
./install.sh
```

The installer is interactive and lets you pick which package categories to install. After finishing, it will prompt you to reboot.

| Category     | Packages                           |
| ------------ | ---------------------------------- |
| `core`       | Hyprland, UWSM, portal             |
| `terminal`   | Kitty, Zsh, Tmux, Fastfetch        |
| `editor`     | Neovim + development tools         |
| `apps`       | Dolphin, Zen Browser, Spotify, mpv |
| `utils`      | Clipboard, playerctl, audio, etc   |
| `fonts`      | Nerd Fonts, cursors, icons         |
| `quickshell` | QuickShell bar/shell               |
| `theming`    | Qt/GTK theming                     |
| `nvidia`     | NVIDIA drivers (only if needed)    |

### Advanced Options

```bash
./install.sh --stow-only       # Only create symlinks
./install.sh --setup-only      # Only run Hyprland setup
./install.sh --packages core   # Install a single category
```

See [.install/README.md](.install/README.md) for more details.

---

## 🔧 Lyne CLI

Lyne Dots includes a built-in CLI tool called `lyne` for managing the dotfiles. It is loaded automatically via `.zshrc`.

### Usage

```
lyne <command> [args...]
```

### Commands

| Command   | Description                                         |
| --------- | --------------------------------------------------- |
| `theme`   | Manage themes (set, list, auto, scheme)             |
| `state`   | Manage `state.json` (edit, sync, rebuild)           |
| `migrate` | Manage migrations (run, list, done)                 |
| `update`  | Pull latest changes, sync state, and run migrations |
| `git`     | Run git commands in the dotfiles repo               |
| `reload`  | Reload QuickShell                                   |
| `help`    | Show available commands                             |

Run `lyne <command> --help` for details and subcommands.

### Examples

```bash
# Show current theme info
lyne theme

# List all available themes (dark and light)
lyne theme list

# Switch to a specific theme preset
lyne theme set catppuccin-mocha

# Switch to Material You auto mode (colors from wallpaper)
lyne theme auto

# Toggle between dark and light scheme
lyne theme scheme light

# Pull the latest changes and apply migrations
lyne update

# Check the git status of the dotfiles
lyne git status

# Edit the QuickShell state configuration
lyne state

# Sync state.json after a manual defaults.json update
lyne state sync

# Check which migrations are pending
lyne migrate list

# Show help for a specific command
lyne state --help
```

---

## ⌨️ Keybindings

### Apps

| Keybind          | Action                 |
| ---------------- | ---------------------- |
| `Super + Return` | Terminal (Kitty)       |
| `Super + D`      | File Manager (Dolphin) |
| `Super + Z`      | Browser (Zen Browser)  |
| `Super + Space`  | App Launcher           |

### Windows

| Keybind                   | Action                          |
| ------------------------- | ------------------------------- |
| `Super + Q`               | Kill window                     |
| `Super + F`               | Fullscreen                      |
| `Super + Shift + F`       | Fullscreen (pinned)             |
| `Super + Shift + Space`   | Toggle floating                 |
| `Super + Tab`             | Toggle split                    |
| `Super + P`               | Pseudo tile                     |
| `Super + H J K L`         | Move focus (left/down/up/right) |
| `Super + Shift + H J K L` | Move window                     |
| `Super + Alt + H J K L`   | Resize window                   |

### Workspaces

| Keybind                        | Action                               |
| ------------------------------ | ------------------------------------ |
| `Super + 1-0`                  | Switch to workspace 1-10             |
| `Super + Shift + 1-0`          | Move window to workspace 1-10        |
| `Super + Ctrl + H / L`         | Previous / Next workspace            |
| `Super + Ctrl + Shift + H / L` | Move window to prev / next workspace |
| `Super + W`                    | Toggle WhatsApp workspace            |
| `Super + M`                    | Toggle Spotify workspace             |
| `Super + S`                    | Toggle Magic workspace               |

### System

| Keybind             | Action            |
| ------------------- | ----------------- |
| `Super + B`         | Wallpaper Picker  |
| `Super + /`         | Keybinds Help     |
| `Super + V`         | Clipboard History |
| `Super + End`       | Power Menu        |
| `Print`             | Screenshot        |
| `Super + = / -`     | Zoom in / out     |
| `Super + Shift + R` | Reload QuickShell |

### Media

| Keybind           | Action                         |
| ----------------- | ------------------------------ |
| `Volume Keys`     | Volume up / down / mute        |
| `Brightness Keys` | Brightness up / down           |
| `Media Keys`      | Play / Pause / Next / Previous |

---

## 📁 Structure

Each top-level directory is a [GNU Stow](https://www.gnu.org/software/stow/) package that gets symlinked into `$HOME`.

| Directory     | Description                                                                          |
| ------------- | ------------------------------------------------------------------------------------ |
| `hyprland/`   | Hyprland compositor config (appearance, keybinds, rules)                             |
| `quickshell/` | QML shell: bar, launcher, notifications, quick settings                              |
| `nvim/`       | Neovim config with lazy.nvim plugin manager                                          |
| `tmux/`       | Tmux config with TPM and Smart Splits integration                                    |
| `kitty/`      | Kitty terminal config with dynamic themes                                            |
| `zsh/`        | Zsh config with Oh-My-Zsh and Powerlevel10k                                          |
| `local/`      | Custom scripts, wallpapers (`~/.local/wallpapers/`), and themes (`~/.local/themes/`) |
| `fastfetch/`  | System info display config                                                           |
| `theming/`    | GTK3/4 and Qt5/6 theme settings                                                      |
| `kde/`        | KDE Plasma global settings (colors, icons, fonts)                                    |

### Other Directories

| Directory         | Description                                       |
| ----------------- | ------------------------------------------------- |
| `.install/`       | Installation scripts and package lists            |
| `.data/`          | Templates, default themes, and default wallpapers |
| `.data/lyne-cli/` | CLI commands, libraries, and migrations           |

---

## 🛠️ Tech Stack

| Component       | Tool            |
| --------------- | --------------- |
| Compositor      | Hyprland        |
| Session Manager | UWSM            |
| Desktop Shell   | QuickShell      |
| Terminal        | Kitty           |
| Shell           | Zsh + Oh-My-Zsh |
| Multiplexer     | Tmux            |
| Editor          | Neovim          |
| Wallpaper       | awww            |
| Auto Theming    | matugen         |
| File Manager    | Dolphin         |
| Browser         | Zen Browser     |
| AUR Helper      | yay             |
| Dotfile Manager | GNU Stow        |

---

## ⚙️ Customization

Machine-specific configs are kept in `~/.config/hypr/local/` and are not tracked by git. The install script generates these from templates in `.data/hyprland/templates/` on first run:

- `monitors.conf` - Monitor layout
- `workspaces.conf` - Workspace mapping
- `extra_environment.conf` - Local environment variables
- `autostart.conf` - Local autostart programs
- `extra_keybinds.conf` - Local keybinds

### Wallpapers

Wallpapers live in `~/.local/wallpapers/` (git-ignored, defaults copied on install) and are managed through the QuickShell wallpaper picker (`Super + B`). Features include:

- **Search** by filename
- **Favorites** with persistent state
- **Theme wallpapers** organized in `~/.local/wallpapers/themes/{theme-name}/`
- Each theme can have multiple wallpapers; the active one is set from the picker and applied automatically on theme switch

### Adding Themes

Themes are JSON files in `~/.local/themes/` (git-ignored, defaults copied from `.data/themes/` on install). Each theme defines colors for the palette, terminal, Hyprland, Neovim, GTK/Qt, and a wallpaper path. Light themes include a `"variant": "light"` field and a `"darkPair"` field linking them to their dark counterpart. To create a new theme, copy an existing one and modify the values.

---

## 🙏 Credits

- Screenshot implementation inspired by [HyprQuickFrame](https://github.com/Ronin-CK/HyprQuickFrame)
