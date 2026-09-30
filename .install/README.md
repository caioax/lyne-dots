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

Every question comes first (packages; graphics: the GPUs found and, for an
NVIDIA GPU, the driver and environment variables, preselected from them;
reboot), then a review screen. After the sudo password (asked once and kept alive) the
install runs without further questions, showing each step, a progress bar and
the latest output. Everything goes to `~/.cache/lyne/install-<date>.log`.
Files already where the dotfiles are linked are moved to
`~/.lyne-dots-backup/<date>/`.

### Unattended, with the answers in a file

```bash
cat > answers <<EOF
categories=core terminal utils fonts quickshell theming
gpu_order=igpu
reboot=no
EOF
./install.sh --answers answers
```

`nvidia=driver|env|none` (and `multilib=yes` for the 32-bit driver) can be
added; without it, the NVIDIA driver is installed when the GPU found has one.
`lyne gpu` lists the GPUs (`.data/lyne-cli/lib/gpus.sh`, reading sysfs and
pci.ids only).

### GPU order (more than one GPU)

`/dev/dri/card*` numbers change between boots, so each GPU gets a link by PCI
address in `/etc/udev/rules.d/90-lyne-gpus.rules` (`/dev/dri/intel-igpu`,
`nvidia-dgpu`...). The order Hyprland uses them in (`AQ_DRM_DEVICES`: the
first renders, GPUs left out aren't used) is kept in state.json
(`gpus.order`) and written to `~/.config/hypr/local/gpus.lua`, which only
sets the GPUs present when Hyprland starts. The installer asks for it on
hybrid machines; `lyne gpu order igpu|dgpu|auto|only-igpu|only-dgpu` changes
it (next login) and `lyne gpu links` rewrites the rules.

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
