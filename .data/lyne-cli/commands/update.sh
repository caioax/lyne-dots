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

echo -e "\e[1;34m:: Aligning core files with repository...\e[0m"
git -C "$DOTS_DIR" reset --hard

echo -e "\e[1;34m:: Pulling latest changes...\e[0m"
if ! git -C "$DOTS_DIR" pull; then
    echo "lyne update: git pull failed"
    _lyne_notify -u critical "Lyne update failed" "git pull failed, see the terminal for details"
    return 1
fi

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
_lyne_notify "Lyne is up to date" "$(git -C "$DOTS_DIR" log -1 --format='%h · %s')"
