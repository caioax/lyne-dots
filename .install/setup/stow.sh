#!/bin/bash
# =============================================================================
# Stow Setup - Symlink Dotfiles
# =============================================================================
# Uses GNU Stow to create dotfile symlinks
# =============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$DOTFILES_DIR/.install/lib/log.sh"

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

# stow_packages CATEGORY...: the packages to link for those categories, in
# STOW_DIRS order (one per line)
stow_packages() {
    local -a wanted=("${STOW_ALWAYS[@]}")
    local category dir
    for category in "$@"; do
        read -ra dir <<<"$(stow_category_packages "$category")"
        wanted+=("${dir[@]}")
    done
    for dir in "${STOW_DIRS[@]}"; do
        if [[ " ${wanted[*]} " == *" $dir "* ]]; then
            echo "$dir"
        fi
    done
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

    local dir failed=0
    for dir in "$@"; do
        if [[ -d "$DOTFILES_DIR/$dir" ]]; then
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

# Run if called directly: the packages given, or every one
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if (($#)); then
        run_stow_main "$@"
    else
        run_stow_main "${STOW_DIRS[@]}"
    fi
fi
