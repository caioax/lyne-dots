# lyne update - Pull latest changes, sync state and run migrations

# shellcheck disable=SC2317 # run-migrations.sh ends in a return, so the rest looks unreachable
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: lyne update [status [--fetch] [--json]]"
    echo ""
    echo "Pull latest dotfiles changes, sync state.json with defaults,"
    echo "and run any pending migrations."
    echo ""
    echo "  status   Branch, commit, uncommitted changes and how far behind"
    echo "           the upstream branch it is (--fetch fetches first)"
    return 0
fi

source "$DOTS_DIR/.data/lyne-cli/lib/managed-files.sh"

if [[ "${1:-}" == "status" ]]; then
    shift
    local fetch=false json=false arg
    for arg in "$@"; do
        case "$arg" in
        --fetch) fetch=true ;;
        --json) json=true ;;
        *)
            echo "lyne update status: unknown option '$arg'"
            return 1
            ;;
        esac
    done
    local branch commit date dirty fetched=false behind
    branch="$(git -C "$DOTS_DIR" rev-parse --abbrev-ref HEAD)" || return 1
    commit="$(git -C "$DOTS_DIR" log -1 --format=%h)"
    date="$(git -C "$DOTS_DIR" log -1 --format=%cd --date=short)"
    dirty="$(git -C "$DOTS_DIR" status --porcelain --untracked-files=no -- . "${MANAGED_EXCLUDES[@]}" | wc -l)"
    [[ "$fetch" == true ]] && timeout 15 git -C "$DOTS_DIR" fetch --quiet 2>/dev/null && fetched=true
    # -1: no upstream branch
    behind="$(git -C "$DOTS_DIR" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo -1)"
    if [[ "$json" == true ]]; then
        jq -n --arg branch "$branch" --arg commit "$commit" --arg date "$date" \
            --argjson dirty "$dirty" --argjson fetched "$fetched" --argjson behind "$behind" \
            '{branch: $branch, commit: $commit, date: $date, dirty: $dirty, fetched: $fetched, behind: $behind}'
    else
        echo "$branch @ $commit ($date)"
        echo "Uncommitted changes: $dirty"
        if ((behind < 0)); then
            echo "No upstream branch"
        else
            echo "Behind upstream: $behind$([[ "$fetched" == true ]] || echo " (not fetched)")"
        fi
    fi
    return 0
fi

# Desktop notification with the lyne-dots icon: the update runs in a terminal
# that is often behind other windows
_lyne_notify() {
    command -v notify-send &>/dev/null || return 0
    notify-send -a "Lyne" -i lyne-dots "$@"
}

# The managed files (lazy-lock.json, kdeglobals...) aren't the user's work:
# put aside so they don't count as changes, and back after the pull
if ! managed_save; then
    managed_restore HEAD
    echo "lyne update: couldn't set the managed files aside, nothing was changed"
    return 1
fi
local old_head
old_head="$(git -C "$DOTS_DIR" rev-parse HEAD)"

# Uncommitted changes: stashed, discarded or the update cancelled
local stash_name=""
local changes
changes="$(git -C "$DOTS_DIR" status --porcelain --untracked-files=no)"
if [[ -n "$changes" ]]; then
    echo -e "\e[1;33m:: Uncommitted changes in $DOTS_DIR:\e[0m"
    echo "$changes"
    local choice=s
    # Without a terminal to ask in, they're stashed
    [[ -t 0 ]] && read -rp "[S]tash them (git stash pop brings them back), [d]iscard them or [c]ancel? " choice
    case "${choice,,}" in
    "" | s)
        stash_name="lyne-update-$(date +%F-%H%M)"
        if ! git -C "$DOTS_DIR" stash push -m "$stash_name"; then
            managed_restore HEAD
            echo "lyne update: git stash failed, nothing was changed"
            return 1
        fi
        echo "   Stashed as $stash_name"
        ;;
    d)
        git -C "$DOTS_DIR" reset --hard
        ;;
    *)
        managed_restore HEAD
        echo "lyne update: cancelled"
        return 1
        ;;
    esac
fi

echo -e "\e[1;34m:: Pulling latest changes...\e[0m"
if ! git -C "$DOTS_DIR" pull; then
    managed_restore HEAD
    echo "lyne update: git pull failed"
    [[ -n "$stash_name" ]] && echo "Your changes are in git stash \"$stash_name\": git -C $DOTS_DIR stash pop brings them back"
    _lyne_notify -u critical "Lyne update failed" "git pull failed, see the terminal for details"
    return 1
fi

managed_restore "$old_head"

# Plugins stay where they are when the lock changes: restore moves them to the
# versions pinned in the repo
if managed_changed "nvim/.config/nvim/lazy-lock.json" "$old_head" && command -v nvim &>/dev/null; then
    echo -e "\e[1;34m:: Restoring Neovim plugins to the pinned versions...\e[0m"
    # A few lines per plugin and task: only kept in a log
    local lazy_log="$HOME/.local/share/lyne/lazy-restore.log"
    mkdir -p "$(dirname "$lazy_log")"
    timeout 300 nvim --headless "+Lazy! restore" +qa &>"$lazy_log" ||
        echo "lyne update: the plugins weren't restored ($lazy_log), :Lazy restore in Neovim does it"
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
local summary
summary="$(git -C "$DOTS_DIR" log -1 --format='%h · %s')"
if [[ -n "$stash_name" ]]; then
    echo "Your changes are in git stash \"$stash_name\": git -C $DOTS_DIR stash pop brings them back"
    summary+=$'\n'"Your changes are stashed as $stash_name"
fi
_lyne_notify "Lyne is up to date" "$summary"
