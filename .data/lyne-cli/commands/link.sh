# lyne link - Link the dotfiles packages an install left out

source "$DOTS_DIR/.install/setup/stow.sh"

# What a package still needs after its link (its program, its plugin manager)
_link_hints() {
    local dir
    for dir in "$@"; do
        case "$dir" in
        kitty | zsh | tmux | fastfetch)
            command -v "$dir" &>/dev/null || echo "  $dir isn't installed: sudo pacman -S $dir"
            ;;
        nvim)
            command -v nvim &>/dev/null || echo "  Neovim isn't installed: sudo pacman -S neovim"
            ;;
        esac
        case "$dir" in
        zsh)
            [[ -d "$HOME/.oh-my-zsh" ]] ||
                echo "  ~/.zshrc needs Oh My Zsh and its plugins: ./install.sh with the terminal category sets them up"
            ;;
        tmux)
            [[ -d "$HOME/.tmux/plugins/tpm" ]] ||
                echo "  The tmux plugins need TPM: git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm, then prefix + I"
            ;;
        esac
    done
}

case "${1:-status}" in
    -h|--help)
        echo "Usage: lyne link [status|<package>...]"
        echo ""
        echo "Links dotfiles packages into your HOME with GNU Stow, like the installer"
        echo "does for the categories chosen. Files already at their place go to the"
        echo "backup folder first (~/.lyne-dots-backup/<date>/); lyne unlink brings"
        echo "them back."
        echo ""
        echo "  status        Each package, linked (●) or not (○), and its category (default)"
        echo "  <package>...  Link these: kitty, zsh, tmux, fastfetch (terminal), nvim"
        echo "                (editor), theming, kde (theming)"
        ;;
    status)
        local dir group targets
        local -a recorded
        mapfile -t recorded < <(stow_recorded_packages)
        for dir in "${STOW_DIRS[@]}"; do
            group="$(stow_package_group "$dir")"
            targets="$(get_stow_targets "$dir")"
            targets="${targets//$HOME/\~}"
            printf '  %s %-11s %-9s %s\n' \
                "$([[ " ${recorded[*]} " == *" $dir "* ]] && echo "●" || echo "○")" \
                "$dir" "$group" "${targets// /, }"
        done
        ;;
    *)
        local dir
        for dir in "$@"; do
            if [[ " ${STOW_DIRS[*]} " != *" $dir "* ]]; then
                echo "lyne link: unknown package '$dir' (lyne link status lists them)"
                return 1
            fi
        done
        stow_link "$@" || return 1
        _link_hints "$@"
        ;;
esac
