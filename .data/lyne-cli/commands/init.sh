# lyne init - First-time setup for new installations
#
# Marks all existing migrations as done (they are only relevant
# for users upgrading from older versions) and syncs state.json.

local MIGRATIONS_DIR="$DOTS_DIR/.data/lyne-cli/migrations"
local DONE_FILE="$HOME/.local/share/lyne/migrations-done"

mkdir -p "$(dirname "$DONE_FILE")"
touch "$DONE_FILE"

# Mark all current migrations as already executed
local count=0
for migration in "$MIGRATIONS_DIR"/*.sh(N); do
    local name="$(basename "$migration")"
    if ! grep -qxF "$name" "$DONE_FILE" 2>/dev/null; then
        echo "$name" >> "$DONE_FILE"
        ((count++))
    fi
done

echo "lyne init: marked $count migrations as done"

# Sync state.json from defaults
echo ":: Syncing state.json..."
source "$DOTS_DIR/.data/lyne-cli/lib/sync-state.sh"
