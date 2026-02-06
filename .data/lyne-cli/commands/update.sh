# lyne update - Pull latest changes, sync state and run migrations

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: lyne update"
    echo ""
    echo "Pull latest dotfiles changes, sync state.json with defaults,"
    echo "and run any pending migrations."
    return 0
fi

echo -e "\e[1;34m:: Aligning core files with repository...\e[0m"
git -C "$DOTS_DIR" reset --hard

echo -e "\e[1;34m:: Pulling latest changes...\e[0m"
git -C "$DOTS_DIR" pull

if [[ $? -ne 0 ]]; then
    echo "lyne update: git pull failed"
    return 1
fi

echo -e "\e[1;34m:: Syncing state.json...\e[0m"
source "$DOTS_DIR/.data/lyne-cli/lib/sync-state.sh"

echo -e "\e[1;34m:: Checking migrations...\e[0m"
source "$DOTS_DIR/.data/lyne-cli/lib/run-migrations.sh"

echo -e "\e[1;34m:: Reloading Quickshell...\e[0m"
source "$DOTS_DIR/.data/lyne-cli/commands/reload.sh"

# Final Success Message
echo ""
echo -e "\e[1;32m✔ Lyne is up to date!\e[0m"
