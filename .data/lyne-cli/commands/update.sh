# lyne update - Update to the channel's version, sync state and run migrations

# shellcheck disable=SC2317 # run-migrations.sh ends in a return, so the rest looks unreachable
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: lyne update [--channel stable|latest]"
    echo "       lyne update status [--fetch] [--json] [--channel stable|latest]"
    echo "       lyne update channel [stable|latest]"
    echo "       lyne update notes [--json] [--since COMMIT]"
    echo ""
    echo "Update the dotfiles, sync state.json with defaults, and run any"
    echo "pending migrations. On main, the channel picks the version:"
    echo "  stable   the newest release (default)"
    echo "  latest   every change as soon as it's on main"
    echo "Other branches follow their upstream. --channel overrides the"
    echo "channel saved in Settings › About for one run."
    echo ""
    echo "  status   Version, uncommitted changes and what an update would"
    echo "           bring (--fetch fetches first)"
    echo "  channel  Show or set the channel"
    echo "  notes    Release notes: the current release's, or every release"
    echo "           since COMMIT (what an update from there brought)"
    return 0
fi

source "$DOTS_DIR/.data/lyne-cli/lib/managed-files.sh"
source "$DOTS_DIR/.data/lyne-cli/lib/channel.sh"

local subcmd=""
[[ "${1:-}" == status || "${1:-}" == channel || "${1:-}" == notes ]] && subcmd="$1" && shift

if [[ "$subcmd" == notes ]]; then
    local json=false since="" release
    while (($#)); do
        case "$1" in
        --json) json=true ;;
        --since)
            since="$(git -C "$DOTS_DIR" rev-parse -q --verify "${2:-}^{commit}")" || {
                echo "lyne update notes: unknown commit '${2:-}'"
                return 1
            }
            shift
            ;;
        *)
            echo "lyne update notes: unknown option '$1'"
            return 1
            ;;
        esac
        shift
    done
    # Without --since: the release HEAD is at or past, alone
    if [[ -z "$since" ]]; then
        release="$(channel_last_release HEAD)"
        [[ -n "$release" ]] && since="$(git -C "$DOTS_DIR" rev-parse -q --verify "$release^{commit}^" 2>/dev/null)"
    fi
    local notes
    notes="$(channel_notes_json "$since")"
    if [[ -z "$release" && -z "$since" ]]; then
        notes="[]"
    fi
    if [[ "$json" == true ]]; then
        echo "$notes"
    else
        jq -r 'if length == 0 then "No release notes" else .[] | "\(.version) (\(.date))\n\(if .notes == "" then "(no notes)" else .notes end)\n" end' <<<"$notes"
    fi
    return 0
fi

if [[ "$subcmd" == channel ]]; then
    if [[ -z "${1:-}" ]]; then
        channel_get
        return
    fi
    channel_get "$1" >/dev/null || return 1
    lyne_state_set '.update.channel = $c' --arg c "$1" || {
        echo "lyne update channel: couldn't write $(lyne_state_file)"
        return 1
    }
    echo "Channel: $1"
    return 0
fi

local fetch=false json=false channel_arg="" arg
while (($#)); do
    arg="$1"
    shift
    case "$arg" in
    --fetch) fetch=true ;;
    --json) json=true ;;
    --channel)
        channel_arg="${1:-}"
        shift
        ;;
    *)
        echo "lyne update: unknown option '$arg' (lyne update --help)"
        return 1
        ;;
    esac
done
if [[ "$subcmd" != status ]] && [[ "$fetch" == true || "$json" == true ]]; then
    echo "lyne update: --fetch and --json are for lyne update status"
    return 1
fi
local channel
channel="$(channel_get "$channel_arg")" || return 1

if [[ "$subcmd" == status ]]; then
    local commit date dirty fetched=false version
    commit="$(git -C "$DOTS_DIR" log -1 --format=%h)" || return 1
    date="$(git -C "$DOTS_DIR" log -1 --format=%cd --date=short)"
    dirty="$(git -C "$DOTS_DIR" status --porcelain --untracked-files=no -- . "${MANAGED_EXCLUDES[@]}" | wc -l)"
    [[ "$fetch" == true ]] && timeout 15 git -C "$DOTS_DIR" fetch --tags --quiet 2>/dev/null && fetched=true
    channel_resolve "$channel"
    version="$(channel_version)"
    if [[ "$json" == true ]]; then
        jq -n --arg branch "$CH_BRANCH" --arg follows "$CH_FOLLOWS" --arg channel "$channel" \
            --arg commit "$commit" --arg date "$date" --arg version "$version" \
            --arg upstream "$CH_UPSTREAM" --arg lastRelease "$CH_LAST_RELEASE" --arg target "$CH_TARGET_NAME" --arg targetCommit "$CH_TARGET_COMMIT" \
            --argjson dirty "$dirty" --argjson fetched "$fetched" --argjson behind "$CH_BEHIND" \
            '{branch: $branch, follows: $follows, channel: $channel, commit: $commit, date: $date,
              version: $version, upstream: $upstream, lastRelease: $lastRelease, target: $target, targetCommit: $targetCommit,
              dirty: $dirty, fetched: $fetched, behind: $behind}'
        return 0
    fi
    echo "${version:-no release} · $CH_BRANCH @ $commit ($date)"
    if [[ "$CH_FOLLOWS" == channel ]]; then
        echo "Channel: $channel"
    else
        echo "Follows: ${CH_UPSTREAM:-nothing (no upstream branch)}"
    fi
    echo "Uncommitted changes: $dirty"
    local note=""
    [[ "$fetch" == true && "$fetched" == false ]] && note=" (couldn't fetch)"
    [[ "$fetch" == false ]] && note=" (not fetched)"
    if [[ -z "$CH_TARGET" ]]; then
        [[ -n "$CH_UPSTREAM" ]] && echo "No release yet$note"
    elif ((CH_BEHIND > 0)); then
        echo "Update: $CH_TARGET_NAME, $CH_BEHIND commits$note"
    else
        echo "Up to date$note"
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

# Fails like a pull would: the managed files and the user's changes are put back
_lyne_update_failed() {
    managed_restore HEAD
    echo "lyne update: $1"
    [[ -n "$stash_name" ]] && echo "Your changes are in git stash \"$stash_name\": git -C $DOTS_DIR stash pop brings them back"
    _lyne_notify -u critical "Lyne update failed" "$1, see the terminal for details"
}

echo -e "\e[1;34m:: Fetching...\e[0m"
if ! git -C "$DOTS_DIR" fetch --tags; then
    _lyne_update_failed "git fetch failed"
    return 1
fi
channel_resolve "$channel"
if [[ -z "$CH_UPSTREAM" ]]; then
    _lyne_update_failed "$CH_BRANCH has no upstream branch to update from"
    return 1
fi
if [[ "$CH_FOLLOWS" == channel ]]; then
    echo "   Channel: $channel"
else
    echo "   On $CH_BRANCH: following $CH_UPSTREAM"
fi
if [[ -z "$CH_TARGET" ]]; then
    echo "   No release yet: staying at $(git -C "$DOTS_DIR" log -1 --format=%h)"
elif ((CH_BEHIND == 0)); then
    # Past the last release (it was on latest): stable moves on with the next
    if [[ "$CH_FOLLOWS" == channel && "$channel" == stable && "$(channel_version)" == *+* ]]; then
        echo "   Newer than the last release ($CH_LAST_RELEASE): staying here until the next one"
    else
        echo "   Already at $CH_TARGET_NAME"
    fi
else
    echo -e "\e[1;34m:: Updating to $CH_TARGET_NAME...\e[0m"
    if [[ "$CH_FOLLOWS" == branch ]]; then
        # A branch of one's own may have local commits: git pull, with the
        # user's pull settings (merge or rebase)
        if ! git -C "$DOTS_DIR" pull; then
            _lyne_update_failed "git pull failed"
            return 1
        fi
    elif ! git -C "$DOTS_DIR" merge --ff-only "$CH_TARGET"; then
        _lyne_update_failed "couldn't update to $CH_TARGET_NAME"
        echo "$CH_BRANCH has commits of its own: lyne update only fast-forwards it"
        return 1
    fi
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
local version
version="$(channel_version)"
summary="$(git -C "$DOTS_DIR" log -1 --format='%h · %s')"
[[ -n "$version" ]] && summary="$version · $summary"
if [[ -n "$stash_name" ]]; then
    echo "Your changes are in git stash \"$stash_name\": git -C $DOTS_DIR stash pop brings them back"
    summary+=$'\n'"Your changes are stashed as $stash_name"
fi

# Releases this update brought that have notes: the notification opens them
# in the What's new window. It waits for the click apart from the terminal,
# which may close first
local with_notes
with_notes="$(channel_notes_json "$old_head" | jq -r '[.[] | select(.notes != "") | .version] | join(", ")')"
if [[ -n "$with_notes" ]] && command -v notify-send &>/dev/null; then
    echo "What's new in $with_notes: the notification opens it (or lyne update notes)"
    setsid -f bash -c 'reply="$(timeout 1h notify-send -a Lyne -i lyne-dots -A default="What'"'"'s new" -A whatsnew="What'"'"'s new" "$1" "$2")"
        [[ -n "$reply" ]] && qs ipc call whatsnew open "$3"' _ "Lyne is up to date" "$summary" "$old_head" &>/dev/null
else
    _lyne_notify "Lyne is up to date" "$summary"
fi
