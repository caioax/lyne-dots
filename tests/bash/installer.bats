#!/usr/bin/env bats
# install.sh --dry-run: the whole install, unattended (--answers), with the
# installer's own stand-ins (a throwaway HOME, sudo/pacman/yay/stow/systemctl
# only logged) and a fake sysfs, so the result doesn't depend on this machine

load helpers

setup() {
    lyne_setup
    SYS="$BATS_TEST_TMPDIR/sys"
    DRY="$BATS_TEST_TMPDIR/dry"
    export LYNE_SYSFS="$SYS" LYNE_PCI_IDS="$FIXTURES/pci.ids" LYNE_MODULES_DIR="$BATS_TEST_TMPDIR/modules"
    export LYNE_DRY_HOME="$DRY" LYNE_DRY_FRESH=1 LYNE_DRY_DELAY=0
    export LYNE_PP_POWER_SUPPLY="$BATS_TEST_TMPDIR/power_supply" LYNE_PP_BUS_NAMES="" LYNE_PP_COMMANDS=""
    mkdir -p "$LYNE_MODULES_DIR/6.17.1-arch1-1" "$LYNE_PP_POWER_SUPPLY"
    echo linux >"$LYNE_MODULES_DIR/6.17.1-arch1-1/pkgbase"
    # This machine's pacman.conf and mkinitcpio files stay out of it
    local etc="$BATS_TEST_TMPDIR/etc"
    mkdir -p "$etc/mkinitcpio.d"
    printf '[core]\nInclude = /etc/pacman.d/mirrorlist\n\n#[multilib]\n#Include = /etc/pacman.d/mirrorlist\n' >"$etc/pacman.conf"
    printf 'MODULES=()\nHOOKS=(base udev kms block)\n' >"$etc/mkinitcpio.conf"
    export LYNE_PACMAN_CONF="$etc/pacman.conf" LYNE_MKINITCPIO_CONF="$etc/mkinitcpio.conf"
    export LYNE_MKINITCPIO_DIR="$etc/mkinitcpio.conf.d" LYNE_MKINITCPIO_PRESETS="$etc/mkinitcpio.d"
    # The cursor theme the theming step applies, whether or not this machine
    # has it
    export LYNE_ICON_DIRS="$BATS_TEST_TMPDIR/icons"
    mkdir -p "$LYNE_ICON_DIRS/Bibata-Modern-Classic/cursors"
    : >"$LYNE_ICON_DIRS/Bibata-Modern-Classic/cursors/left_ptr"
    # Likewise the icon theme (the dry run's git clone installs nothing)
    local tela
    for tela in Tela-blue Tela-blue-dark Tela-blue-light; do
        mkdir -p "$LYNE_ICON_DIRS/$tela"
        printf '[Icon Theme]\nName=%s\nDirectories=48/apps\n' "$tela" >"$LYNE_ICON_DIRS/$tela/index.theme"
    done
    ANSWERS="$BATS_TEST_TMPDIR/answers"
    # shellcheck disable=SC2034 # read by repo_unchanged
    REPO_STATUS="$(git -C "$REPO" status --porcelain)"
}

teardown() { repo_unchanged; }

hybrid() {
    fx_gpu "$SYS" 0000:01:00.0 10de:1f9d driver=nvidia card=card0 outputs="HDMI-A-1:connected"
    fx_gpu "$SYS" 0000:00:02.0 8086:3e9b driver=i915 card=card1 outputs="eDP-1:connected"
}

answers() { printf '%s\n' "$@" >"$ANSWERS"; }
install() { "$REPO/install.sh" --dry-run "$@"; }
log() { cat "$DRY"/.cache/lyne/install-*.log; }

@test "hybrid laptop: every step, packages by category, NVIDIA driver, GPU order" {
    hybrid
    answers "categories=core terminal utils quickshell theming" "gpu_order=igpu" "reboot=no"
    run install --answers "$ANSWERS"
    assert_success
    refute_output --partial "[fail]"
    # "·" on a UTF-8 terminal, "-" in the ASCII fallback (no locale, the console)
    assert_line --regexp '^\[ok\] Packages (·|-) quickshell$'
    assert_line "[ok] NVIDIA driver"
    assert_line "[ok] GPU links and order"
    assert_line "[ok] Lyne CLI"
    run log
    assert_line --partial "[dry-run] yay -S --needed --noconfirm quickshell-git"
    assert_line "[dry-run] sudo pacman -S --needed --noconfirm linux-headers nvidia-open-dkms nvidia-utils libva-nvidia-driver nvidia-prime"
    assert_line --partial "[dry-run] sudo mkinitcpio -P"
    assert_line --partial "[dry-run] stow -d $REPO -t $DRY -R quickshell"
    # The default cursor: its package with theming, applied like Settings does
    assert_line "[dry-run] yay -S --needed --noconfirm bibata-cursor-theme"
    # Plain qt5ct from the repos (qt5ct-kde's KF5 deps no longer build)
    assert_line --regexp '^\[dry-run\] sudo pacman -S --needed --noconfirm .* qt5ct '
    refute_line --partial "qt5ct-kde"
    assert_line "[dry-run] gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Classic"
    assert_line "[dry-run] gsettings set org.gnome.desktop.interface cursor-size 24"
    grep -qx "Inherits=Bibata-Modern-Classic" "$DRY/.icons/default/index.theme"
    # Tela with theming, fonts not asked for (cloned, its deps with the
    # theming packages), its dark version applied like Settings does
    assert_line --regexp '^\[dry-run\] git clone --depth=1 https://github.com/vinceliuice/Tela-icon-theme.git '
    assert_line --regexp '^\[dry-run\] sudo pacman -S --needed --noconfirm .*matugen.*gtk-update-icon-cache'
    assert_line "[dry-run] gsettings set org.gnome.desktop.interface icon-theme Tela-blue-dark"
    # Not asked for
    refute_line --regexp 'Packages (·|-) editor'
    refute_line --regexp 'Packages (·|-) fonts'
    # The first login opens the welcome screen; settings from the answers
    local state="$DRY/.config/quickshell/state.json"
    assert_equal "$(jq -c '[.welcome.pending, .system.aurHelper, .gpus.order]' "$state")" '[true,"yay",["0000:00:02.0","0000:01:00.0"]]'
    grep -q '"/dev/dri/intel-igpu",' "$DRY/.config/hypr/local/gpus.lua"
    # Theme wallpapers only in their theme's folder, none in the library root
    assert [ -f "$DRY/.local/wallpapers/themes/tokyonight/lyne-tokyonight-contour.jpg" ]
    refute compgen -G "$DRY/.local/wallpapers/*.jpg"
}

@test "only the categories chosen are linked, and the state remembers them" {
    hybrid
    mkdir -p "$DRY"
    echo mine >"$DRY/.zshrc"
    mkdir -p "$DRY/.config/nvim" "$DRY/.config/gtk-3.0"
    echo mine >"$DRY/.config/nvim/init.lua"
    echo mine >"$DRY/.config/gtk-3.0/settings.ini"
    answers "categories=core quickshell" "nvidia=none" "reboot=no"
    run install --answers "$ANSWERS"
    assert_success
    run log
    assert_line --partial "[dry-run] stow -d $REPO -t $DRY -R hyprland"
    assert_line --partial "[dry-run] stow -d $REPO -t $DRY -R quickshell"
    assert_line --partial "[dry-run] stow -d $REPO -t $DRY -R local"
    local pkg
    for pkg in kitty nvim zsh tmux fastfetch kde theming; do
        refute_line --partial "-R $pkg"
    done
    # The user's files of the packages not linked stay where they are
    [ -f "$DRY/.zshrc" ] && [ -f "$DRY/.config/nvim/init.lua" ] && [ -f "$DRY/.config/gtk-3.0/settings.ini" ]
    [ ! -d "$DRY/.lyne-dots-backup" ]
    assert_equal "$(jq -c .system.stow "$DRY/.config/quickshell/state.json")" '["hyprland","quickshell","local"]'
    # No editor, no QML language server file
    [ ! -e "$DRY/.config/quickshell/.qmlls.ini" ]
    # The review (in the log with --answers) said so
    run log
    assert_line "review Links: hyprland, quickshell, local"
    assert_line "review Backup: nothing to move"
}

@test "every category: every package linked, the user's files to the backup" {
    hybrid
    mkdir -p "$DRY"
    echo mine >"$DRY/.zshrc"
    answers "categories=core terminal editor apps utils fonts quickshell theming" "nvidia=none" "reboot=no"
    run install --answers "$ANSWERS"
    assert_success
    run log
    local pkg
    for pkg in hyprland quickshell kitty nvim zsh tmux local fastfetch kde theming; do
        assert_line --partial "[dry-run] stow -d $REPO -t $DRY -R $pkg"
    done
    [ ! -e "$DRY/.zshrc" ]
    run log
    assert_line "review Links: hyprland, quickshell, kitty, nvim, zsh, tmux, local, fastfetch, kde, theming"
    assert_line "review Backup: ~/.zshrc"
    assert_line --regexp '^  to ~/\.lyne-dots-backup/[0-9]{8}-[0-9]{6}$'
    run find "$DRY/.lyne-dots-backup" -name .zshrc
    assert_output --partial ".zshrc"
    assert_equal "$(jq -c .system.stow "$DRY/.config/quickshell/state.json")" \
        '["hyprland","quickshell","kitty","nvim","zsh","tmux","local","fastfetch","kde","theming"]'
    # Neovim's qmlls: the empty file Quickshell fills
    [ -f "$DRY/.config/quickshell/.qmlls.ini" ] && [ ! -s "$DRY/.config/quickshell/.qmlls.ini" ]
}

@test "--stow-only links again the packages recorded, plus the shell's" {
    # A state.json of its own: the dry run's stow links nothing, and a real
    # link would reach the repo's
    export LYNE_STATE_FILE="$BATS_TEST_TMPDIR/state.json"
    echo '{"system": {"stow": ["nvim"]}}' >"$LYNE_STATE_FILE"
    run install --stow-only
    assert_success
    local pkg
    for pkg in hyprland quickshell nvim local; do
        assert_line --partial "[dry-run] stow -d $REPO -t $DRY -R $pkg"
    done
    for pkg in kitty zsh tmux fastfetch kde theming; do
        refute_line --partial "-R $pkg"
    done
    assert_equal "$(jq -c .system.stow "$LYNE_STATE_FILE")" '["hyprland","quickshell","nvim","local"]'
}

@test "multilib asked for: enabled with a full sync, lib32 driver" {
    hybrid
    answers "categories=core" "nvidia=driver" "multilib=yes" "reboot=no"
    run install --answers "$ANSWERS"
    assert_success
    run log
    assert_line --partial "[dry-run] sudo pacman -Syu --noconfirm"
    assert_line --partial "lib32-nvidia-utils"
    refute_line --partial "pacman -Sy --noconfirm"
}

@test "no NVIDIA GPU: no driver step, no GPU order on one GPU" {
    fx_gpu "$SYS" 0000:03:00.0 1002:73ff driver=amdgpu card=card0 outputs="DP-1:connected"
    answers "categories=core" "reboot=no"
    run install --answers "$ANSWERS"
    assert_success
    refute_line --partial "NVIDIA driver"
    run log
    refute_line --partial "nvidia-open-dkms"
    refute_line --partial "90-lyne-gpus.rules"
}

@test "a failing package stops the install: summary, exit 1, never a reboot" {
    hybrid
    answers "categories=core terminal" "nvidia=none" "reboot=yes"
    LYNE_DRY_FAIL=pacman run install --answers "$ANSWERS"
    assert_failure
    assert_output --partial "[fail]"
    assert_output --partial "didn't run. Run ./install.sh again to finish."
    refute_output --partial "Rebooting"
    refute_output --partial "Enjoy your new setup"
    run log
    assert_line --partial "made to fail"
}

@test "a failing AUR build leaves the category's other AUR packages installed, and names it" {
    answers "categories=core theming" "nvidia=none" "reboot=no"
    LYNE_DRY_FAIL=yay:qt6ct-kde run install --answers "$ANSWERS"
    assert_success
    assert_line --regexp '^\[warn\] Packages (·|-) theming \(Not installed from the AUR: qt6ct-kde; the build output is in the log\)$'
    run log
    assert_line --partial "[dry-run] yay -S --needed --noconfirm qt6ct-kde (made to fail)"
    assert_line "[dry-run] yay -S --needed --noconfirm bibata-cursor-theme"
    assert_line "[dry-run] gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Classic"
}

@test "only missing packages are installed (an older install's qt5ct-kde stands for qt5ct)" {
    LYNE_DRY_FRESH="" LYNE_DRY_INSTALLED="qt5ct=1.9-2 matugen=4.0-1 qt6ct-kde=0.11-8" run install --packages theming
    assert_success
    assert_line --regexp '^\[dry-run\] sudo pacman -S --needed --noconfirm nwg-look breeze '
    refute_line --regexp 'pacman -S .*(qt5ct|matugen)( |$)'
    refute_line --partial "yay -S --needed --noconfirm qt6ct-kde"
    assert_line "[dry-run] yay -S --needed --noconfirm bibata-cursor-theme"
}

@test "--packages installs one category only" {
    hybrid
    run install --packages terminal
    assert_success
    assert_line --partial "[dry-run] sudo pacman -S --needed --noconfirm zsh tmux fastfetch"
    refute_line --partial "hyprland uwsm"
}

@test "bad flags and missing answers file fail before anything runs" {
    run "$REPO/install.sh" --nope
    assert_failure
    assert_output --partial "Unknown option: --nope"
    run "$REPO/install.sh" --dry-run --answers "$BATS_TEST_TMPDIR/none"
    assert_failure
    assert_output --partial "Answers file not found"
    refute [ -e "$DRY" ]
}

@test "the dry run never reaches the real sudo" {
    hybrid
    answers "categories=core" "reboot=no"
    run install --answers "$ANSWERS"
    assert_success
    # Every sudo call went through the dry-run stand-in (logged), none to ours
    run grep -c '^sudo ' "$STUB_LOG"
    assert_output 0
    run log
    assert_line --partial "[dry-run] sudo"
}

@test "the sudo keepalive leaves nothing running" {
    hybrid
    answers "categories=core" "reboot=no"
    RUN_SUDO_KEEPALIVE=4747 run install --answers "$ANSWERS"
    assert_success
    sleep 0.3
    run /usr/bin/pgrep -fx "sleep 4747"
    assert_failure
}

