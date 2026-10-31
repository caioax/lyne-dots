#!/bin/bash
# =============================================================================
# Stow Setup - Symlink Dotfiles
# =============================================================================
# Uses GNU Stow to create dotfile symlinks
# =============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$DOTFILES_DIR/.install/lib/log.sh"
# lyne_state_set (the packages linked are kept in state.json)
declare -F lyne_state_set >/dev/null || source "$DOTFILES_DIR/.data/lyne-cli/lib/state.sh"
# config_defaults_seed (the config files kept out of git)
source "$DOTFILES_DIR/.data/lyne-cli/lib/config-defaults.sh"

# =============================================================================
# Packages to stow
# =============================================================================
# Every package, in the order they're linked
STOW_DIRS=(
    "hyprland"      # Hyprland config
    "quickshell"    # QuickShell bar
    "kitty"         # Terminal
    "nvim"          # Editor
    "zsh"           # Shell
    "tmux"          # Multiplexer
    "local"         # Local scripts
    "fastfetch"     # System info
    "kde"           # KDE globals (terminal, fonts, icons)
    "theming"       # Qt5/Qt6/GTK theme configuration
)

# Linked on every install: the shell itself and the lyne CLI
STOW_ALWAYS=(hyprland quickshell local)

# The packages that come with an installer category (none for the others)
stow_category_packages() {
    case "$1" in
    terminal) echo "kitty zsh tmux fastfetch" ;;
    editor) echo "nvim" ;;
    theming) echo "theming kde" ;;
    esac
}

# stow_ordered PACKAGE...: those packages once each, in STOW_DIRS order (one
# per line); unknown names are left out
stow_ordered() {
    local dir
    for dir in "${STOW_DIRS[@]}"; do
        if [[ " $* " == *" $dir "* ]]; then
            echo "$dir"
        fi
    done
}

# stow_packages CATEGORY...: the packages to link for those categories
stow_packages() {
    local -a wanted=("${STOW_ALWAYS[@]}") more
    local category
    for category in "$@"; do
        read -ra more <<<"$(stow_category_packages "$category")"
        wanted+=("${more[@]}")
    done
    stow_ordered "${wanted[@]}"
}

# =============================================================================
# Packages linked
# =============================================================================
# The installer keeps them in state.json (.system.stow), so lyne update, the
# migrations and lyne link leave the others alone

# The packages HOME reaches through links into the dotfiles today: one of
# their files is the repo's (one per line)
stow_linked_packages() {
    local dir file
    for dir in "${STOW_DIRS[@]}"; do
        [[ -d "$DOTFILES_DIR/$dir" ]] || continue
        while IFS= read -r -d '' file; do
            if [[ "$(realpath -m "$HOME/${file#"$DOTFILES_DIR/$dir/"}")" == "$(realpath -m "$file")" ]]; then
                echo "$dir"
                break
            fi
        done < <(find "$DOTFILES_DIR/$dir/" -type f -print0)
    done
}

# The packages recorded in state.json; an install from before the record
# gets the ones linked today (stow_linked_packages)
stow_recorded_packages() {
    local list
    list="$(jq -r '.system.stow | if type == "array" then .[] else "-" end' "$(lyne_state_file)" 2>/dev/null)" ||
        list="-"
    if [[ "$list" == "-" ]]; then
        stow_linked_packages
    elif [[ -n "$list" ]]; then
        printf '%s\n' "$list"
    fi
}

# stow_package_exists PACKAGE: in the repo, or made by config_defaults_seed
# (kde only holds kdeglobals, kept out of git: a fresh clone has no kde/)
stow_package_exists() {
    [[ -d "$DOTFILES_DIR/$1" || -d "$DOTFILES_DIR/.data/config-defaults/$1" ]]
}

# stow_is_linked PACKAGE
stow_is_linked() {
    stow_recorded_packages | grep -qxF "$1"
}

# stow_record PACKAGE...: keeps them as the packages linked
stow_record() {
    lyne_state_set '.system.stow = $ARGS.positional' --args "$@"
}

# What --stow-only links again: the packages recorded, and always the shell's
stow_default_packages() {
    local -a recorded
    mapfile -t recorded < <(stow_recorded_packages)
    stow_ordered "${STOW_ALWAYS[@]}" "${recorded[@]}"
}

# =============================================================================
# Check if stow is installed
# =============================================================================
check_stow() {
    if ! command -v stow &>/dev/null; then
        log_error "GNU Stow is not installed!"
        log_info "Install with: sudo pacman -S stow"
        return 1
    fi
    return 0
}

# =============================================================================
# Create required directories
# =============================================================================
create_dirs() {
    log_info "Creating required directories..."
    mkdir -p "$HOME/.config"
    mkdir -p "$HOME/.local/scripts"
    mkdir -p "$HOME/.local/bin"
}

# =============================================================================
# Get stow targets for each directory
# =============================================================================
get_stow_targets() {
    local dir=$1
    local targets=()

    case "$dir" in
        "hyprland")
            targets+=("$HOME/.config/hypr" "$HOME/.config/uwsm")
            ;;
        "zsh")
            targets+=("$HOME/.zshrc" "$HOME/.p10k.zsh")
            ;;
        "nvim")
            targets+=("$HOME/.config/nvim" "$HOME/.clang-format")
            ;;
        "tmux")
            targets+=("$HOME/.tmux.conf")
            ;;
        "local")
            targets+=("$HOME/.local/scripts" "$HOME/.local/wallpapers" "$HOME/.local/themes")
            # ~/.local/bin is a folder of its own (create_dirs): its files
            local file
            for file in "$DOTFILES_DIR/local/.local/bin"/*; do
                [[ -e "$file" ]] && targets+=("$HOME/.local/bin/$(basename "$file")")
            done
            ;;
        "kde")
            targets+=("$HOME/.config/kdeglobals")
            ;;
        "theming")
            targets+=("$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/qt5ct" "$HOME/.config/qt6ct")
            ;;
        *)
            targets+=("$HOME/.config/${dir}")
            ;;
    esac

    echo "${targets[@]}"
}

# =============================================================================
# Existing targets
# =============================================================================
# Links into the dotfiles are ours (an earlier install) and empty folders
# hold nothing: both are just replaced. Anything else is the user's and is
# moved to the backup folder instead
is_own_link() {
    [[ -L "$1" ]] || return 1
    local dest
    dest="$(realpath -m "$1")"
    [[ "$dest" == "$DOTFILES_DIR"/* ]]
}

is_empty_dir() {
    [[ -d "$1" && ! -L "$1" && -z "$(ls -A "$1")" ]]
}

# stow_existing_targets PACKAGE...: the targets that would be moved to the
# backup (one per line)
stow_existing_targets() {
    local dir target targets
    for dir in "$@"; do
        read -ra targets <<<"$(get_stow_targets "$dir")"
        for target in "${targets[@]}"; do
            if [[ -e "$target" || -L "$target" ]] && ! is_own_link "$target" && ! is_empty_dir "$target"; then
                echo "$target"
            fi
        done
    done
}

# backup_existing_targets PACKAGE...: moves the user's files out of the way
# (keeping their path under HOME in the backup folder) and drops our old links
backup_existing_targets() {
    log_info "Checking existing targets..."

    local BACKUP_DIR="${LYNE_BACKUP_DIR:-$HOME/.lyne-dots-backup/$(date +%Y%m%d-%H%M%S)}"
    local dir target targets moved=0
    for dir in "$@"; do
        read -ra targets <<<"$(get_stow_targets "$dir")"
        for target in "${targets[@]}"; do
            [[ -e "$target" || -L "$target" ]] || continue
            if is_own_link "$target"; then
                rm "$target"
                continue
            fi
            if is_empty_dir "$target"; then
                rmdir "$target"
                continue
            fi
            local dest="$BACKUP_DIR/${target#"$HOME"/}"
            mkdir -p "$(dirname "$dest")"
            if mv "$target" "$dest"; then
                log_step "  Moved to the backup: ${target/#$HOME/\~}"
                moved=$((moved + 1))
            else
                log_error "Could not move $target to $dest"
                return 1
            fi
        done
    done

    if ((moved > 0)); then
        log_info "Existing files backed up in ${BACKUP_DIR/#$HOME/\~}"
    else
        log_info "No existing targets found. Ready for stow!"
    fi
}

# =============================================================================
# Execute stow
# =============================================================================
# execute_stow PACKAGE...
execute_stow() {
    log_info "Running stow to create symlinks..."

    # The config files each machine keeps for itself (out of git): from the
    # repo's defaults when missing, so the links have them to reach
    local path
    if [[ -n "${LYNE_DRY_RUN:-}" ]]; then
        for path in "${CONFIG_DEFAULT_FILES[@]}"; do
            [[ -e "$DOTFILES_DIR/$path" || -L "$DOTFILES_DIR/$path" ]] ||
                echo "[dry-run] create $path from .data/config-defaults"
        done
    else
        while IFS= read -r path; do
            log_step "  Created ${path#created } from its default"
        done < <(config_defaults_seed "$DOTFILES_DIR")
    fi

    local dir failed=0
    for dir in "$@"; do
        if stow_package_exists "$dir"; then
            log_step "  Stowing: $dir"
            if ! stow -d "$DOTFILES_DIR" -t "$HOME" -R "$dir" 2>&1; then
                log_error "Failed to stow $dir (check for conflicts and try again)"
                failed=1
            fi
        else
            log_warn "  Directory not found: $dir"
        fi
    done

    ((failed)) && return 1
    log_info "Symlinks created successfully!"
}

# =============================================================================
# Linking and unlinking later (lyne link, lyne unlink)
# =============================================================================
# stow_package_group PACKAGE: "always", or the installer category it comes with
stow_package_group() {
    local category
    if [[ " ${STOW_ALWAYS[*]} " == *" $1 "* ]]; then
        echo always
        return
    fi
    for category in terminal editor theming; do
        if [[ " $(stow_category_packages "$category") " == *" $1 "* ]]; then
            echo "$category"
            return
        fi
    done
}

# stow_link PACKAGE...: what's in the way goes to the backup, then they're
# linked and recorded
stow_link() {
    check_stow || return 1
    create_dirs
    backup_existing_targets "$@" || return 1
    execute_stow "$@" || return 1
    local -a recorded linked
    mapfile -t recorded < <(stow_recorded_packages)
    mapfile -t linked < <(stow_ordered "${recorded[@]}" "$@")
    stow_record "${linked[@]}"
}

# stow_backup_of PATH: the newest backup of ~/PATH, if any
stow_backup_of() {
    local dir
    while IFS= read -r dir; do
        if [[ -e "$dir/$1" || -L "$dir/$1" ]]; then
            echo "$dir/$1"
            return
        fi
    done < <(find "$HOME/.lyne-dots-backup" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r)
}

# stow_unlink PACKAGE...: their links go, the newest backup of each target
# comes back, and they're no longer recorded
stow_unlink() {
    check_stow || return 1
    local dir target targets backup
    for dir in "$@"; do
        log_step "  Unlinking: $dir"
        if ! stow -d "$DOTFILES_DIR" -t "$HOME" -D "$dir" 2>&1; then
            log_error "Failed to unlink $dir"
            return 1
        fi
        read -ra targets <<<"$(get_stow_targets "$dir")"
        for target in "${targets[@]}"; do
            # A folder stow made for the links is left empty
            is_empty_dir "$target" && rmdir "$target"
            [[ -e "$target" || -L "$target" ]] && continue
            backup="$(stow_backup_of "${target#"$HOME"/}")"
            [[ -n "$backup" ]] || continue
            mkdir -p "$(dirname "$target")"
            mv "$backup" "$target" &&
                log_step "  Restored ${target/#$HOME/\~} from ${backup/#$HOME/\~}"
        done
    done
    local -a recorded keep=()
    mapfile -t recorded < <(stow_recorded_packages)
    for dir in "${recorded[@]}"; do
        [[ " $* " == *" $dir "* ]] || keep+=("$dir")
    done
    stow_record "${keep[@]}"
}

# =============================================================================
# Main (for direct execution)
# =============================================================================
# run_stow_main PACKAGE...: backs up what's in the way and links them
run_stow_main() {
    echo ""
    echo "=================================================="
    echo "       Stow Setup - Symlink Dotfiles"
    echo "=================================================="
    echo ""

    if ! check_stow; then
        return 1
    fi

    create_dirs

    backup_existing_targets "$@" || return 1
    execute_stow "$@" || return 1

    echo ""
    log_info "Stow completed successfully!"
    echo ""
}

# Run if called directly: the packages given, or the ones linked before
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if (($#)); then
        run_stow_main "$@"
    else
        mapfile -t STOW_LIST < <(stow_default_packages)
        run_stow_main "${STOW_LIST[@]}"
    fi
fi
