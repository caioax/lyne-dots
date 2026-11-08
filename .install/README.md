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
│   ├── apps.sh         # Dolphin, Zen Browser, Spotify, Chromium (WhatsApp)
│   ├── utils.sh        # Clipboard, audio, bluetooth
│   ├── fonts.sh        # Nerd Fonts, icons
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

New installs start from `bootstrap.sh` at the repo root (`curl ... | bash`, see
the main README): it clones into `~/.lyne-dots`, moves `main` back to the
newest release tag (still tracking `origin/main`, so `lyne update` works on
either channel) and runs that release's `install.sh`, passing its arguments
along (`| bash -s -- --dry-run`).

Every question comes first (packages; graphics: the GPUs found and, for an
NVIDIA GPU, the driver and environment variables, preselected from them;
the login screen, only where SDDM is the display manager; reboot), then a
review screen. After the sudo password (asked once and kept alive) the
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

`nvidia=driver|env|none` (and `multilib=yes` for the 32-bit driver) can be
added; without it, the NVIDIA driver is installed when the GPU found has one.
`gpu_order=igpu|dgpu|auto` sets the GPU order (automatic without it).
`lyne gpu` lists the GPUs (`.data/lyne-cli/lib/gpus.sh`, reading sysfs and
pci.ids only). `sddm=no` skips the login screen (it is only installed where
SDDM is the display manager anyway).

### Login screen (lyne-sddm)

Where SDDM is the display manager (`/etc/systemd/system/display-manager.service`
points at `sddm.service`), the installer offers
[lyne-sddm](https://github.com/caioax/lyne-sddm), a login screen in the lock
screen's style that follows the theme. With another display manager it isn't
asked: switching display managers is left to you. The step runs
`lyne sddm install` (`.data/lyne-cli/lib/sddm.sh`): it clones the repo into
`~/.cache/lyne/lyne-sddm`, builds and installs `lyne-sddm-git` with
`makepkg -si` (from GitHub, as the AUR was down), and runs `lyne-sddm`, which
creates `/var/lib/lyne-sddm` and selects the theme. SDDM is never restarted;
it shows on the next login, and the shell syncs it on its first start. A failed
build only warns. Existing installs get a one-time hint from a migration;
`lyne sddm install` installs it, or updates it when run again.

The update channel picks the version: on stable, lyne-sddm's newest release
tag (built through `LYNE_SDDM_REF=<tag>`, the clone itself stays on main), on
latest its main branch. `lyne update` compares the installed package's
`pkgver` hash with the repo (`git ls-remote`, nothing is built to check) and,
in a terminal, asks before rebuilding; without one it only says how. A build
from latest is never replaced by an older stable release. `lyne update status
--fetch` shows it too.

### GPU order (more than one GPU)

`/dev/dri/card*` numbers change between boots, so each GPU gets a link by PCI
address in `/etc/udev/rules.d/90-lyne-gpus.rules` (`/dev/dri/intel-igpu`,
`nvidia-dgpu`...). The order Hyprland uses them in (`AQ_DRM_DEVICES`: the
first renders, GPUs left out aren't used) is kept in state.json
(`gpus.order`) and written to `~/.config/hypr/local/gpus.lua`, which only
sets the GPUs present when Hyprland starts. The installer leaves it on
automatic (the GPU with the built-in screen renders): on a laptop the
dedicated GPU first leaves it without a desktop away from its external
monitor. Settings › Graphics or `lyne gpu order igpu|dgpu|auto|only-igpu|only-dgpu`
change it (next login) and `lyne gpu links` rewrites the rules.

On hybrid machines `gpus.lua` also:
- puts the first GPU with a monitor plugged in first when the one chosen has
  none at login (the dedicated GPU away from the external monitor);
- sets the NVIDIA variables (`LIBVA_DRIVER_NAME`, `__GLX_VENDOR_LIBRARY_NAME`,
  `NVD_BACKEND`) only when NVIDIA renders; otherwise apps run on the
  integrated GPU and `prime-run <app>` starts one on NVIDIA;
- with the dedicated GPU first, turns off `quirks:skip_non_kms_dmabuf_formats`
  (on by default since Hyprland 0.57): with the screens on the other GPU, apps
  are offered only formats they can't draw with.

### NVIDIA driver

`.data/lyne-cli/lib/nvidia.sh` picks the driver for the GPU: `nvidia-open-dkms`
for Turing and newer, `nvidia-580xx-dkms` from the AUR for Maxwell to Volta,
nouveau for older cards. It installs the headers of every kernel,
`libva-nvidia-driver`, `nvidia-prime` on hybrid machines and, with multilib,
the lib32 utils; it writes `/etc/mkinitcpio.conf.d/lyne-nvidia.conf` (no `kms`
hook, the integrated GPU's module early, the NVIDIA ones not: that would break
hibernation) and rebuilds the initramfs. `lyne nvidia` shows the state and
what's off; `lyne nvidia install` (or `./install.sh --packages nvidia`)
installs or fixes the driver on an existing system.

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

Links again the packages linked before (state.json `.system.stow`, or the
ones found linked on older installs) plus `hyprland`, `quickshell` and
`local`. `lyne link <package>` links one more, `lyne unlink <package>` takes
one out (its old files come back from the backup).

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
| core       | Hyprland, UWSM, awww, portal, polkit agent, Kitty (ESSENTIAL) |
| terminal   | Zsh, Tmux, Fastfetch (and the Kitty config)    |
| editor     | Neovim + development tools                     |
| apps       | Dolphin, Zen Browser, Spotify, Chromium, mpv   |
| utils      | Clipboard, audio, bluetooth, brightnessctl     |
| fonts      | Nerd Fonts, Noto fonts and emoji               |
| quickshell | QuickShell bar/shell + Qt6                     |
| theming    | Qt5ct, Qt6ct, nwg-look, Bibata cursor, Tela icons |
| nvidia     | NVIDIA drivers (install only if needed)        |

## Templates and Data

On first install, templates from `.data/` are copied to generate machine-specific configuration files. Wallpapers from `.data/wallpapers/` are copied to `~/.local/wallpapers/`.

Configuration templates are in `.data/hyprland/templates/`:

- `monitors.lua` - Automatic settings for every monitor (Settings › Hyprland › Monitors rewrites it)
- `extra_environment.lua` - Local environment variables
- `extra_environment_nvidia.lua` - NVIDIA variables

Keybinds, apps started at login and keyboard layouts are set in Settings
(written to `local/settings.lua`). Any other `local/*.lua` you write by hand
is loaded too.

NVIDIA UWSM templates are in `.data/hyprland/uwsm/`:

- `global_hardware.sh` - Global Wayland variables
- `hyprland_hardware.sh` - Hyprland-specific settings

## Stow Directories

The `stow.sh` script links the packages of the categories chosen
(`stow_packages`); the installer keeps the list in state.json
(`.system.stow`). What's already at a target goes to
`~/.lyne-dots-backup/<date>/` first.

| Directory  | Target                                   | Linked with      |
| ---------- | ---------------------------------------- | ---------------- |
| hyprland   | ~/.config/hypr, ~/.config/uwsm           | always           |
| quickshell | ~/.config/quickshell                     | always           |
| local      | ~/.local/scripts, themes, wallpapers, bin/lyne | always     |
| kitty      | ~/.config/kitty                          | terminal         |
| zsh        | ~/.zshrc, ~/.p10k.zsh                    | terminal         |
| tmux       | ~/.tmux.conf                             | terminal         |
| fastfetch  | ~/.config/fastfetch                      | terminal         |
| nvim       | ~/.config/nvim, ~/.clang-format          | editor           |
| theming    | ~/.config/gtk-3.0, gtk-4.0, qt5ct, qt6ct | theming          |
| kde        | ~/.config/kdeglobals                     | theming          |

`kdeglobals`, `qt6ct.conf`, `qt5ct.conf` and the GTK `settings.ini` are
each machine's own (the icon theme, the default terminal, qt6ct's and KDE's
settings write there): they're out of git, and `stow.sh` makes a missing one
from `.data/config-defaults/` before linking (also `lyne update` and
migration 046). A new default reaches existing installs through a migration.
