<!-- Images and videos live on the orphan `media` branch (readme/), so cloning
     main stays light. Keybindings: regenerate with
     `lua .data/readme/keybinds.lua README.md`. -->

<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/logo-dark.svg">
  <img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/logo-light.svg" alt="lyne-dots" width="150">
</picture>

# lyne-dots

**A Hyprland desktop for Arch Linux, with a Quickshell shell you set up from its own Settings app.**<br>
One theme follows the bar, terminal, editor, GTK/Qt apps, Hyprland and Zen Browser.

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)](https://archlinux.org) [![Hyprland](https://img.shields.io/badge/Hyprland-0.56-58E1FF?style=flat-square&logo=hyprland&logoColor=white)](https://hypr.land) [![Quickshell](https://img.shields.io/badge/Quickshell-QML-7aa2f7?style=flat-square)](https://quickshell.org) [![License](https://img.shields.io/github/license/caioax/lyne-dots?style=flat-square&color=bb9af7)](LICENSE) [![Last commit](https://img.shields.io/github/last-commit/caioax/lyne-dots?style=flat-square&color=9ece6a)](https://github.com/caioax/lyne-dots/commits) [![Ko-fi](https://img.shields.io/badge/Ko--fi-support-f7768e?style=flat-square&logo=ko-fi&logoColor=white)](https://ko-fi.com/caioax)

</div>

https://github.com/user-attachments/assets/63b3c7d6-250e-4c3f-8eb5-343068b08e5a

<div align="center">

```bash
git clone https://github.com/caioax/lyne-dots.git ~/.lyne-dots && ~/.lyne-dots/install.sh
```

[Highlights](#highlights) · [Gallery](#gallery) · [Themes](#themes) · [Install](#install) · [Update](#update) · [Reference](#reference) · [Credits](#credits)

</div>

## Highlights

<table>
<tr>
<td width="33%" valign="top">

**A Settings app for everything**<br>
27 pages: appearance, bar, launcher, dashboard, lock screen, monitors, GPUs, workspaces, keybinds, autostart. Searchable, applied live, no config files to edit.

</td>
<td width="33%" valign="top">

**Themes that reach every app**<br>
11 presets plus Material You from the wallpaper. Switching fades the shell and Hyprland's borders and recolors kitty, Neovim, GTK/Qt and Zen Browser.

</td>
<td width="33%" valign="top">

**Make your own theme**<br>
Start from a color, a wallpaper or another theme; an OKLCH picker and a live preview do the rest. Wallpapers in the theme's colors are rendered for it.

</td>
</tr>
<tr>
<td valign="top">

**A shell with templates**<br>
Bar, launcher, Quick Settings, OSD, lock screen and power menu each come in several styles, previewed in Settings before you pick one.

</td>
<td valign="top">

**Monitors and workspaces**<br>
Drag monitors on a map with a keep-or-revert timer, give each monitor its own workspaces, choose which GPU renders on hybrid laptops.

</td>
<td valign="top">

**A guided installer and a CLI**<br>
Every question first, then an unattended install with a progress bar. `lyne update` pulls, syncs your settings and runs migrations.

</td>
</tr>
</table>

## Gallery

<table>
<tr>
<td width="50%"><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/desktop.webp" alt="Desktop"></td>
<td width="50%"><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/launcher.webp" alt="Launcher"></td>
</tr>
<tr>
<td align="center"><sub>Desktop: kitty, Neovim and fastfetch in Tokyo Night</sub></td>
<td align="center"><sub>Launcher: apps, actions (<code>&gt;</code>) and a calculator (<code>=</code>)</sub></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/dashboard.webp" alt="Dashboard overview"></td>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/dashboard-media.webp" alt="Dashboard media"></td>
</tr>
<tr>
<td align="center"><sub>Dashboard: clock, weather, calendar with holidays, resources, player</sub></td>
<td align="center"><sub>Media tab: cava ring, synced lyrics, a dancing GIF</sub></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/dashboard-system.webp" alt="Dashboard system"></td>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/dashboard-weather.webp" alt="Dashboard weather"></td>
</tr>
<tr>
<td align="center"><sub>System tab: CPU, GPU, memory, storage and network</sub></td>
<td align="center"><sub>Weather tab: next 24 hours and 7 days (Open-Meteo)</sub></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/quick-settings.webp" alt="Quick Settings"></td>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/notifications.webp" alt="Notifications"></td>
</tr>
<tr>
<td align="center"><sub>Quick Settings: toggles, audio and notification history</sub></td>
<td align="center"><sub>Notifications with actions and inline replies</sub></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/clipboard.webp" alt="Clipboard"></td>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/screenshot.webp" alt="Screenshot tool"></td>
</tr>
<tr>
<td align="center"><sub>Clipboard history with image thumbnails and color swatches</sub></td>
<td align="center"><sub>Screenshots: region, window or screen; edit, copy text (OCR)</sub></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/color-picker.webp" alt="Color picker"></td>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/lock.webp" alt="Lock screen"></td>
</tr>
<tr>
<td align="center"><sub>Color picker with a magnifier and hex / rgb / hsl</sub></td>
<td align="center"><sub>Lock screen with the player and power buttons</sub></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/power.webp" alt="Power menu"></td>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/settings-osd.webp" alt="OSD settings"></td>
</tr>
<tr>
<td align="center"><sub>Power menu with a key for each action</sub></td>
<td align="center"><sub>OSD styles, previewed in Settings</sub></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/settings-theme.webp" alt="Theme settings"></td>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/settings-creator.webp" alt="Theme creator"></td>
</tr>
<tr>
<td align="center"><sub>Settings › Theme: presets, Material You, light or dark</sub></td>
<td align="center"><sub>Theme creator with an OKLCH picker and a live preview</sub></td>
</tr>
<tr>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/settings-bar.webp" alt="Bar settings"></td>
<td><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/settings-wallpaper.webp" alt="Wallpaper settings"></td>
</tr>
<tr>
<td align="center"><sub>Bar templates: docked, docked corners, floating, islands</sub></td>
<td align="center"><sub>Wallpaper library with favorites and per-theme wallpapers</sub></td>
</tr>
</table>

## Themes

Switch from Settings › Theme, the Quick Settings palette button or `lyne theme set <name>`. Each theme brings its own generated wallpaper.

<table>
<tr>
<td align="center"><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/themes/tokyonight.webp" alt="Tokyo Night"><br><sub>Tokyo Night</sub></td>
<td align="center"><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/themes/catppuccin-mocha.webp" alt="Catppuccin Mocha"><br><sub>Catppuccin Mocha</sub></td>
<td align="center"><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/themes/dracula.webp" alt="Dracula"><br><sub>Dracula</sub></td>
<td align="center"><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/themes/gruvbox.webp" alt="Gruvbox Dark"><br><sub>Gruvbox Dark</sub></td>
</tr>
<tr>
<td align="center"><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/themes/nord.webp" alt="Nord"><br><sub>Nord</sub></td>
<td align="center"><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/themes/rose-pine.webp" alt="Rose Pine"><br><sub>Rose Pine</sub></td>
<td align="center"><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/themes/tokyonight-light.webp" alt="Tokyo Night Day"><br><sub>Tokyo Night Day</sub></td>
<td align="center"><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/themes/catppuccin-latte.webp" alt="Catppuccin Latte"><br><sub>Catppuccin Latte</sub></td>
</tr>
<tr>
<td align="center"><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/themes/gruvbox-light.webp" alt="Gruvbox Light"><br><sub>Gruvbox Light</sub></td>
<td align="center"><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/themes/nord-light.webp" alt="Nord Light"><br><sub>Nord Light</sub></td>
<td align="center"><img src="https://raw.githubusercontent.com/caioax/lyne-dots/media/readme/themes/rose-pine-dawn.webp" alt="Rose Pine Dawn"><br><sub>Rose Pine Dawn</sub></td>
<td align="center" valign="middle"><b>+ Material You</b><br><sub>colors from your wallpaper<br>(<code>lyne theme auto</code>)</sub></td>
</tr>
</table>

A theme sets the colors of:

| Target | What changes |
| --- | --- |
| Quickshell | Every panel, with a color fade on switches |
| Hyprland | Active and inactive borders, shadow (faded too) |
| kitty | Terminal palette, cursor, tabs |
| Neovim | The `lyne` colorscheme, sent to running instances |
| GTK / Qt / KDE apps | Colors and light or dark variant |
| Zen Browser | Toolbars, tabs and menus (`lyne zen enable`) |
| Wallpaper | The theme's wallpaper (optional) |

## Install

**Requirements:** Arch Linux (or a close derivative) with `git`, a user with `sudo`, and an internet connection.

```bash
git clone https://github.com/caioax/lyne-dots.git ~/.lyne-dots
cd ~/.lyne-dots
./install.sh
```

The installer asks everything first:

1. **Packages:** pick categories (core, terminal, editor, apps, utils, fonts, quickshell, theming).
2. **Graphics:** the GPUs it found; for NVIDIA, the driver (open or 580xx, optionally 32-bit) and its environment; on hybrid laptops, which GPU renders.
3. **Reboot** when done, then a review screen.

After the sudo password (asked once, kept alive), it installs without further questions, with a progress bar and the latest output. Files already in place go to `~/.lyne-dots-backup/<date>/`; the full log is in `~/.cache/lyne/install-<date>.log`.

<details>
<summary><b>Installer options</b></summary>

| Option | What it does |
| --- | --- |
| `--dry-run` | Change nothing: a throwaway HOME and stand-ins for sudo, pacman, yay... |
| `--answers FILE` | Unattended: answers as `id=value` lines (`categories=`, `nvidia=`, `gpu_order=`, `reboot=`) |
| `--packages NAME` | Install one category (`--packages nvidia` installs or fixes the driver) |
| `--stow-only` | Only link the dotfiles with GNU Stow |
| `--setup-only` | Only create the local Hyprland files |

More in [.install/README.md](.install/README.md).

</details>

## Update

```bash
lyne update
```

Pulls the repository, adds new settings to your `state.json` without touching the ones you changed, runs pending migrations (new packages, moved files) and reloads Quickshell. Settings › System › About shows when an update is available and runs it for you.

> [!NOTE]
> `lyne update` runs `git reset --hard` in `~/.lyne-dots`. Keep personal changes in `~/.config/hypr/local/` or in Settings, which are not tracked.

## Reference

<details>
<summary><b>lyne CLI</b></summary>

`lyne` is installed to `~/.local/bin`. Run `lyne <command> --help` for subcommands.

| Command | Description |
| --- | --- |
| `lyne theme` | Show the theme; `list`, `set <name>`, `auto` (Material You), `scheme dark\|light` |
| `lyne update` | Pull, sync `state.json`, run migrations, reload Quickshell |
| `lyne reload` | Restart Quickshell |
| `lyne state` | Edit `state.json`; `sync`, `rebuild` |
| `lyne migrate` | `list`, `run`, `done` for migrations |
| `lyne monitors` | Monitor rules from Settings; revert a trial or reset them |
| `lyne workspaces` | Each monitor's workspace blocks |
| `lyne keyboard` | Layouts, options and per-keyboard layouts |
| `lyne autostart` | What starts at login |
| `lyne gpu` | GPUs found; `order`, `links` |
| `lyne nvidia` | NVIDIA driver status; `install` installs or fixes it |
| `lyne zen` | Zen Browser profiles that follow the theme |
| `lyne git` | Run git in the dotfiles repository |

</details>

<details>
<summary><b>Keybindings</b></summary>

Every bind below can be changed or turned off in Settings › Hyprland › Keybinds, where you can also add your own. <kbd>Super</kbd> + left / right drag moves / resizes windows.

<!-- keybinds:start -->

**Apps**

| Keys | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>Enter</kbd> | Terminal |
| <kbd>Super</kbd> + <kbd>D</kbd> | File manager |
| <kbd>Super</kbd> + <kbd>Z</kbd> | Browser |

**Windows**

| Keys | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Close window |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>Space</kbd> | Toggle floating |
| <kbd>Super</kbd> + <kbd>F</kbd> | Fullscreen |
| <kbd>Super</kbd> + <kbd>Tab</kbd> | Split / swap with main / column width |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>Tab</kbd> | Previous column width (scrolling) |
| <kbd>Super</kbd> + <kbd>,</kbd> | Swap column left (scrolling) |
| <kbd>Super</kbd> + <kbd>.</kbd> | Swap column right (scrolling) |
| <kbd>Super</kbd> + <kbd>[</kbd> | Join / leave previous column (scrolling) |
| <kbd>Super</kbd> + <kbd>]</kbd> | Join / leave next column (scrolling) |
| <kbd>Super</kbd> + <kbd>C</kbd> | Center column (scrolling) |
| <kbd>Super</kbd> + <kbd>R</kbd> | Fit visible columns (scrolling) |
| <kbd>Super</kbd> + <kbd>H / L / K / J</kbd> | Focus left / right / up / down |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>H / L / K / J</kbd> | Move window left / right / up / down |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>H</kbd> | Shrink width |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>L</kbd> | Grow width |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>K</kbd> | Shrink height |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>J</kbd> | Grow height |

**Workspaces**

| Keys | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>1–0</kbd> | Go to workspace 1–10 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>1–0</kbd> | Move window to workspace 1–10 |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>L</kbd> | Next workspace |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>H</kbd> | Previous workspace |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>L</kbd> | Move window to next workspace |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>H</kbd> | Move window to previous workspace |

**Media**

| Keys | Action |
| --- | --- |
| <kbd>Volume Up</kbd> | Volume up |
| <kbd>Volume Down</kbd> | Volume down |
| <kbd>Mute</kbd> | Mute |
| <kbd>Mic Mute</kbd> | Mute microphone |
| <kbd>Brightness Up</kbd> | Brightness up |
| <kbd>Brightness Down</kbd> | Brightness down |
| <kbd>Next</kbd> | Next track |
| <kbd>Pause</kbd> or <kbd>Play</kbd> | Play / pause |
| <kbd>Previous</kbd> | Previous track |

**Shell**

| Keys | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>=</kbd> | Zoom in |
| <kbd>Super</kbd> + <kbd>-</kbd> | Zoom out |
| <kbd>Super (tap)</kbd> | App launcher |
| <kbd>Super</kbd> + <kbd>V</kbd> | Clipboard history |
| <kbd>Print</kbd> | Screenshot |
| <kbd>Super</kbd> + <kbd>End</kbd> | Power menu |
| <kbd>Super</kbd> + <kbd>Esc</kbd> | Lock screen |
| <kbd>Super</kbd> + <kbd>I</kbd> | Settings |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>R</kbd> | Reload Quickshell |

**Keyboard**

| Keys | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>Space</kbd> | Next keyboard layout |

**Special workspaces**

| Keys | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>W</kbd> | Toggle WhatsApp |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Move window to WhatsApp |
| <kbd>Super</kbd> + <kbd>M</kbd> | Toggle Music |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>M</kbd> | Move window to Music |

<!-- keybinds:end -->

</details>

<details>
<summary><b>Repository layout</b></summary>

Each top-level folder is a [GNU Stow](https://www.gnu.org/software/stow/) package linked into `$HOME`.

| Folder | Contents |
| --- | --- |
| `quickshell/` | The shell: bar, launcher, dashboard, notifications, OSD, lock, power, screenshots, Settings |
| `hyprland/` | Hyprland config in Lua (`conf/`), plus `local/` for per-machine files |
| `kitty/`, `zsh/`, `tmux/`, `nvim/` | Terminal, shell (Oh My Zsh + Powerlevel10k), multiplexer, editor |
| `theming/`, `kde/` | GTK 3/4, Qt 5/6 and KDE color settings |
| `fastfetch/` | System info |
| `local/` | Scripts, the `lyne` command, themes and wallpapers (`~/.local/`) |
| `.install/` | Installer libraries, package lists and setup |
| `.data/` | Default themes, wallpapers and their generator, state defaults, CLI commands and migrations |

</details>

<details>
<summary><b>Customization</b></summary>

- **Settings first.** Almost everything is in Settings (<kbd>Super</kbd> + <kbd>I</kbd>). Its values live in `~/.config/quickshell/state.json`; `lyne state` opens it.
- **Machine-specific Hyprland files** live in `~/.config/hypr/local/` (not tracked). Settings writes `settings.lua`, `monitors.lua` and `gpus.lua` there; any other `.lua` file you add is loaded too.
- **Themes** are JSON files in `~/.local/themes/`. Create one in Settings › Theme › New theme, or copy a file from `.data/themes/`.
- **Wallpapers** live in `~/.local/wallpapers/`, with each theme's in `themes/<theme>/`. `.data/wallpapers/generator/generate.py --theme-file <json>` renders the lake, waves and contour wallpapers for any palette.

</details>

## Credits

- [Caelestia shell](https://github.com/caelestia-dots/shell): inspiration for many of the shell's panels and its Settings
- [HyprQuickFrame](https://github.com/Ronin-CK/HyprQuickFrame): the screenshot tool's starting point
- [Quickshell](https://quickshell.org), [Hyprland](https://hypr.land), [matugen](https://github.com/InioX/matugen), [awww](https://codeberg.org/LGFae/awww), [cliphist](https://github.com/sentriz/cliphist), [cava](https://github.com/karlstav/cava), [tesseract](https://github.com/tesseract-ocr/tesseract)
- Weather from [Open-Meteo](https://open-meteo.com); lyrics from [LRCLIB](https://lrclib.net) and NetEase

## Support

If lyne-dots is useful to you, you can support it on [GitHub Sponsors](https://github.com/sponsors/caioax) or [Ko-fi](https://ko-fi.com/caioax).

## License

[GPL-3.0](LICENSE)
