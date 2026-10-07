# lyne update - Pull latest changes, sync state and run migrations

# shellcheck disable=SC2317 # run-migrations.sh ends in a return, so the rest looks unreachable
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: lyne update"
    echo ""
    echo "Pull latest dotfiles changes, sync state.json with defaults,"
    echo "and run any pending migrations."
    return 0
fi

# Desktop notification with the lyne-dots icon: the update runs in a terminal
# that is often behind other windows
_lyne_notify() {
    command -v notify-send &>/dev/null || return 0
    notify-send -a "Lyne" -i lyne-dots "$@"
}

# The plugin versions Lazy writes (:Lazy update, new plugins) aren't local
# work: they don't count as changes and are put back after the pull
local lazy_lock="nvim/.config/nvim/lazy-lock.json"
local lazy_saved=""
_lyne_restore_lazy_lock() {
    [[ -n "$lazy_saved" ]] || return 0
    cp "$lazy_saved" "$DOTS_DIR/$lazy_lock" && rm -f "$lazy_saved"
    lazy_saved=""
}

# Uncommitted changes: stashed, discarded or the update cancelled
local stash_name=""
local changes
changes="$(git -C "$DOTS_DIR" status --porcelain --untracked-files=no -- . ":(exclude)$lazy_lock")"
if [[ -n "$changes" ]]; then
    echo -e "\e[1;33m:: Uncommitted changes in $DOTS_DIR:\e[0m"
    echo "$changes"
    local choice=s
    # Without a terminal to ask in, they're stashed
    [[ -t 0 ]] && read -rp "[S]tash them (git stash pop brings them back), [d]iscard them or [c]ancel? " choice
    case "${choice,,}" in
    "" | s)
        stash_name="lyne-update-$(date +%F-%H%M)"
        if ! git -C "$DOTS_DIR" stash push -m "$stash_name" -- . ":(exclude)$lazy_lock"; then
            echo "lyne update: git stash failed, nothing was changed"
            return 1
        fi
        echo "   Stashed as $stash_name"
        ;;
    d)
        git -C "$DOTS_DIR" reset --hard
        ;;
    *)
        echo "lyne update: cancelled"
        return 1
        ;;
    esac
fi

if ! git -C "$DOTS_DIR" diff --quiet -- "$lazy_lock"; then
    lazy_saved="$(mktemp)" || return 1
    cp "$DOTS_DIR/$lazy_lock" "$lazy_saved"
    git -C "$DOTS_DIR" checkout -- "$lazy_lock"
fi

echo -e "\e[1;34m:: Pulling latest changes...\e[0m"
if ! git -C "$DOTS_DIR" pull; then
    _lyne_restore_lazy_lock
    echo "lyne update: git pull failed"
    _lyne_notify -u critical "Lyne update failed" "git pull failed, see the terminal for details"
    return 1
fi

_lyne_restore_lazy_lock

echo -e "\e[1;34m:: Syncing state.json...\e[0m"
source "$DOTS_DIR/.data/lyne-cli/lib/sync-state.sh"

echo -e "\e[1;34m:: Checking migrations...\e[0m"
local migrations_ok=true
source "$DOTS_DIR/.data/lyne-cli/lib/run-migrations.sh" || migrations_ok=false

echo -e "\e[1;34m:: Reloading Quickshell...\e[0m"
source "$DOTS_DIR/.data/lyne-cli/commands/reload.sh"

# Ensure stow symlinks are up to date (lyne CLI, etc)
cd "$DOTS_DIR" && stow -R local 2>/dev/null
source "$DOTS_DIR/.data/lyne-cli/lib/install-icons.sh"

# Quickshell is the notification server and was just restarted: wait for it
for _ in {1..20}; do
    busctl --user status org.freedesktop.Notifications &>/dev/null && break
    sleep 0.25
done

if [[ "$migrations_ok" = false ]]; then
    _lyne_notify -u critical "Lyne update incomplete" "A migration failed, see the terminal for details"
    return 1
fi

# Final Success Message
echo ""
echo -e "\e[1;32m✔ Lyne is up to date!\e[0m"
local summary
summary="$(git -C "$DOTS_DIR" log -1 --format='%h · %s')"
if [[ -n "$stash_name" ]]; then
    echo "Your changes are in git stash \"$stash_name\": git -C $DOTS_DIR stash pop brings them back"
    summary+=$'\n'"Your changes are stashed as $stash_name"
fi
_lyne_notify "Lyne is up to date" "$summary"
