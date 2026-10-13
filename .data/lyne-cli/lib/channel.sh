# channel.sh - Where lyne update goes: the update channel on main
#
# On main, the channel picks the target:
#   stable  the newest release tag (vMAJOR.MINOR.PATCH) on origin's main
#   latest  the tip of origin's main
# Updates only fast-forward, so a switch to stable never goes back: when HEAD
# is past the last release, it stays until the next one. Any other branch (a
# fork, the dev branch) follows its upstream as `git pull` would.
#
# Usage: source this file (expects $DOTS_DIR to be set)

# shellcheck disable=SC2034 # the CH_* variables are read by the caller

local CHANNEL_BRANCH="main"
local CHANNEL_TAG_RE='^v[0-9]+\.[0-9]+\.[0-9]+$'
local CH_BRANCH="" CH_FOLLOWS="" CH_UPSTREAM="" CH_LAST_RELEASE="" CH_TARGET="" CH_TARGET_NAME="" CH_TARGET_COMMIT="" CH_BEHIND=0

# The channel: $1 when given, else update.channel from state.json, else stable
channel_get() {
    local channel="${1:-}"
    if [[ -z "$channel" ]]; then
        channel="$(jq -r '.update.channel // empty' "$(lyne_state_file)" 2>/dev/null)"
    fi
    case "${channel:-stable}" in
    stable | latest) echo "${channel:-stable}" ;;
    *)
        echo "lyne update: unknown channel '$channel' (stable or latest)" >&2
        return 1
        ;;
    esac
}

# Newest release tag reachable from $1
channel_last_release() {
    git -C "$DOTS_DIR" tag --merged "$1" --list 'v*' --sort=-v:refname 2>/dev/null |
        grep -E -m1 "$CHANNEL_TAG_RE"
}

# Fills the CH_* variables for the channel $1:
#   CH_BRANCH        current branch ("HEAD" when detached)
#   CH_FOLLOWS       channel (on main) or branch
#   CH_UPSTREAM      the upstream ref, empty without one
#   CH_LAST_RELEASE  newest release on the upstream, empty without any
#   CH_TARGET        the commit-ish to fast-forward to, empty when there's
#                    none (no upstream, stable without releases)
#   CH_TARGET_NAME   what to call it: the tag, or the upstream branch
#   CH_TARGET_COMMIT its short commit hash
#   CH_BEHIND        commits from HEAD to the target, 0 when HEAD has it
channel_resolve() {
    local channel="$1"
    CH_BRANCH="$(git -C "$DOTS_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    CH_UPSTREAM="$(git -C "$DOTS_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
    CH_LAST_RELEASE=""
    CH_TARGET=""
    CH_TARGET_NAME=""
    CH_TARGET_COMMIT=""
    CH_BEHIND=0
    [[ "$CH_BRANCH" == "$CHANNEL_BRANCH" ]] && CH_FOLLOWS=channel || CH_FOLLOWS=branch
    [[ -n "$CH_UPSTREAM" ]] || return 0
    CH_LAST_RELEASE="$(channel_last_release "$CH_UPSTREAM")"
    if [[ "$CH_FOLLOWS" == channel && "$channel" == stable ]]; then
        CH_TARGET="$CH_LAST_RELEASE"
        CH_TARGET_NAME="$CH_LAST_RELEASE"
    else
        CH_TARGET="$CH_UPSTREAM"
        CH_TARGET_NAME="$CH_UPSTREAM"
    fi
    [[ -n "$CH_TARGET" ]] || return 0
    CH_TARGET_COMMIT="$(git -C "$DOTS_DIR" rev-parse --short "$CH_TARGET^{commit}" 2>/dev/null)"
    CH_BEHIND="$(git -C "$DOTS_DIR" rev-list --count "HEAD..$CH_TARGET" 2>/dev/null || echo 0)"
}

# The version of HEAD: v1.2.0, v1.2.0+3 (3 commits past it), or empty
# before the first release
channel_version() {
    local release count
    release="$(channel_last_release HEAD)"
    [[ -n "$release" ]] || return 0
    count="$(git -C "$DOTS_DIR" rev-list --count "$release..HEAD")"
    if ((count > 0)); then
        echo "$release+$count"
    else
        echo "$release"
    fi
}
