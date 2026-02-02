# lyne update - Pull latest changes, sync state and run migrations

echo ":: Resetting local changes..."
git -C "$DOTS_DIR" reset --hard

echo ":: Pulling latest changes..."
git -C "$DOTS_DIR" pull

if [[ $? -ne 0 ]]; then
    echo "lyne update: git pull failed"
    return 1
fi

echo ":: Syncing state.json..."
source "$DOTS_DIR/.data/lyne-cli/lib/sync-state.sh"

echo ":: Running migrations..."
source "$DOTS_DIR/.data/lyne-cli/lib/run-migrations.sh"
