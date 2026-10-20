# lyne unlink - Unlink dotfiles packages, bringing back the files they replaced

source "$DOTS_DIR/.install/setup/stow.sh"

case "${1:-}" in
    ""|-h|--help)
        echo "Usage: lyne unlink <package>..."
        echo ""
        echo "Removes the links of these packages from your HOME (lyne link status"
        echo "lists them) and puts back the newest copy of each file from the backup"
        echo "folder (~/.lyne-dots-backup/). hyprland, quickshell and local stay: the"
        echo "shell needs them."
        [[ -n "${1:-}" ]] || return 1
        ;;
    *)
        local dir
        local -a linked
        mapfile -t linked < <(stow_recorded_packages)
        for dir in "$@"; do
            if [[ " ${STOW_DIRS[*]} " != *" $dir "* ]]; then
                echo "lyne unlink: unknown package '$dir' (lyne link status lists them)"
                return 1
            fi
            if [[ "$(stow_package_group "$dir")" == always ]]; then
                echo "lyne unlink: $dir is always linked (the shell needs it)"
                return 1
            fi
            if [[ " ${linked[*]} " != *" $dir "* ]]; then
                echo "lyne unlink: $dir isn't linked"
                return 1
            fi
        done
        stow_unlink "$@"
        ;;
esac
