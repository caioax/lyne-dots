# lyne release - Tag and publish a release (for the maintainer)

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: lyne release [patch|minor|major|vX.Y.Z] [--dry-run]"
    echo ""
    echo "Tag main's tip as the next release, push the tag and publish it on"
    echo "GitHub. Users on the Stable channel update to it."
    echo ""
    echo "  patch    fixes only (v1.2.3 -> v1.2.4)"
    echo "  minor    new things (v1.2.3 -> v1.3.0)"
    echo "  major    breaks something or needs the user to act (v1.2.3 -> v2.0.0)"
    echo "Without one, it asks. The first release is v1.0.0."
    echo ""
    echo "The notes are written in \$EDITOR, from a list of the commits since"
    echo "the last release. No notes: users don't get a What's new."
    echo ""
    echo "  --dry-run  every check and the notes, but nothing is created"
    return 0
fi

source "$DOTS_DIR/.data/lyne-cli/lib/managed-files.sh"
source "$DOTS_DIR/.data/lyne-cli/lib/channel.sh"

local dry=false bump="" arg
for arg in "$@"; do
    case "$arg" in
    --dry-run) dry=true ;;
    patch | minor | major | v*) bump="$arg" ;;
    *)
        echo "lyne release: unknown option '$arg' (lyne release --help)"
        return 1
        ;;
    esac
done

# A check that fails stops the release; in a dry run, only the ones that would
# make a wrong release do
_release_check() {
    local fatal="$1" message="$2"
    if [[ "$dry" == true && "$fatal" != always ]]; then
        echo -e "\e[1;33m   ! $message (a real release stops here)\e[0m"
        return 0
    fi
    echo "lyne release: $message"
    return 1
}

local git=(git -C "$DOTS_DIR")

echo -e "\e[1;34m:: Checking...\e[0m"
local branch
branch="$("${git[@]}" rev-parse --abbrev-ref HEAD)" || return 1
if [[ "$branch" != "$CHANNEL_BRANCH" ]]; then
    _release_check dry "on $branch: releases are tagged on $CHANNEL_BRANCH (merge into it first)" || return 1
fi
if [[ -n "$("${git[@]}" status --porcelain --untracked-files=no -- . "${MANAGED_EXCLUDES[@]}")" ]]; then
    _release_check dry "uncommitted changes: a release is a commit as it is on GitHub" || return 1
fi
if ! "${git[@]}" fetch --tags --quiet; then
    echo "lyne release: git fetch failed"
    return 1
fi
local upstream
upstream="$("${git[@]}" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
if [[ -z "$upstream" ]]; then
    _release_check dry "$branch has no upstream branch" || return 1
elif [[ "$("${git[@]}" rev-parse HEAD)" != "$("${git[@]}" rev-parse "$upstream")" ]]; then
    _release_check dry "$branch isn't the same as $upstream: push (or pull) first, the tag goes on what users get" || return 1
fi
local tagged
tagged="$("${git[@]}" tag --points-at HEAD | grep -E -m1 "$CHANNEL_TAG_RE")"
if [[ -n "$tagged" ]]; then
    _release_check always "this commit is already $tagged" || return 1
fi
if [[ "$dry" == false ]]; then
    if ! command -v gh &>/dev/null; then
        echo "lyne release: gh (github-cli) publishes the release, and it isn't installed"
        return 1
    fi
    if ! gh auth status &>/dev/null; then
        echo "lyne release: gh isn't logged in (gh auth login)"
        return 1
    fi
fi

# The version
local last next
last="$(channel_last_release HEAD)"
if [[ -z "$last" ]]; then
    next="v1.0.0"
    [[ "$bump" == v* ]] && next="$bump"
else
    local major minor patch
    IFS=. read -r major minor patch <<<"${last#v}"
    if [[ -z "$bump" ]]; then
        echo "Last release: $last"
        read -rp "[f]ixes only (v$major.$minor.$((patch + 1))), [n]ew things (v$major.$((minor + 1)).0) or [b]reaking (v$((major + 1)).0.0)? " bump
        case "${bump,,}" in
        f) bump="patch" ;;
        n) bump="minor" ;;
        b) bump="major" ;;
        *)
            echo "lyne release: cancelled"
            return 1
            ;;
        esac
    fi
    case "$bump" in
    patch) next="v$major.$minor.$((patch + 1))" ;;
    minor) next="v$major.$((minor + 1)).0" ;;
    major) next="v$((major + 1)).0.0" ;;
    *) next="$bump" ;;
    esac
fi
if [[ ! "$next" =~ $CHANNEL_TAG_RE ]]; then
    echo "lyne release: '$next' isn't a version like v1.2.3"
    return 1
fi
if "${git[@]}" rev-parse -q --verify "refs/tags/$next" >/dev/null; then
    echo "lyne release: $next already exists"
    return 1
fi
if [[ -n "$last" && "$(printf '%s\n' "$last" "$next" | sort -V | tail -1)" != "$next" ]]; then
    echo "lyne release: $next isn't newer than $last"
    return 1
fi

# The notes, written above the scissors line; the commits below help
local scissors="# ------------------------ >8 ------------------------"
local range="HEAD" count shown=80
[[ -n "$last" ]] && range="$last..HEAD"
count="$("${git[@]}" rev-list --count --no-merges "$range")"
local notes
notes="$(mktemp --suffix=.md)" || return 1
{
    echo ""
    echo "$scissors"
    echo "# Notes for $next go above this line, in Markdown. Users see them in"
    echo "# the What's new window and on GitHub. Nothing above the line: a"
    echo "# release without notes (a fix), and no What's new. Everything from"
    echo "# the line down is removed."
    echo "#"
    echo "# Commits since ${last:-the start} ($count), first clause, by scope:"
    ((count > shown)) && echo "# (the newest $shown)"
    "${git[@]}" log --no-merges --format='%s' -n "$shown" "$range" | awk '
        {
            scope = "other"; text = $0
            if (match($0, /^[a-z]*\([^)]+\): */)) {
                head = substr($0, 1, RLENGTH)
                text = substr($0, RLENGTH + 1)
                sub(/^[a-z]*\(/, "", head); sub(/\): *$/, "", head)
                scope = head
            }
            # The first clause: up to ": ", "; " or " ("
            cut = length(text) + 1
            seps[1] = ": "; seps[2] = "; "; seps[3] = " ("
            for (i = 1; i <= 3; i++) { p = index(text, seps[i]); if (p > 1 && p < cut) cut = p }
            text = substr(text, 1, cut - 1)
            if (length(text) > 100) text = substr(text, 1, 99) "…"
            if (!(scope in lines)) order[++scopes] = scope
            lines[scope] = lines[scope] "\n- " text
            total[scope]++
        }
        END {
            for (i = 1; i <= scopes; i++) printf "\n%s (%d)%s\n", order[i], total[order[i]], lines[order[i]]
        }'
} >"$notes"

local editor="${VISUAL:-${EDITOR:-nvim}}"
# shellcheck disable=SC2086 # the editor may come with its arguments
if ! $editor "$notes"; then
    rm -f "$notes"
    echo "lyne release: the editor failed, nothing was created"
    return 1
fi
# Above the scissors, without blank lines at the ends
local text
text="$(sed "/^$(printf '%s' "$scissors" | sed 's/[]\/$*.^[]/\\&/g')\$/,\$d" "$notes" |
    awk 'NF { found = 1 } found' | tac | awk 'NF { found = 1 } found' | tac)"
printf '%s' "$text" >"$notes"

echo ""
echo -e "\e[1;34m:: $next\e[0m at $("${git[@]}" log -1 --format='%h · %s' | cut -c1-80)"
if [[ -n "$text" ]]; then
    printf '   %s\n' "${text//$'\n'/$'\n'   }"
else
    echo "   (no notes: users get no What's new)"
fi

if [[ "$dry" == true ]]; then
    rm -f "$notes"
    echo ""
    echo "Dry run: nothing was created"
    return 0
fi

local answer=""
read -rp "Tag $next, push it and publish the release? [y/N] " answer
if [[ "${answer,,}" != y ]]; then
    rm -f "$notes"
    echo "lyne release: cancelled"
    return 1
fi

if ! "${git[@]}" tag -a "$next" -F "$notes" --cleanup=verbatim; then
    rm -f "$notes"
    echo "lyne release: git tag failed"
    return 1
fi
if ! "${git[@]}" push origin "refs/tags/$next"; then
    "${git[@]}" tag -d "$next" >/dev/null
    rm -f "$notes"
    echo "lyne release: pushing the tag failed, it was removed here"
    return 1
fi
# The notes from the file, the same text as the tag (--notes-from-tag takes
# the commit message when the tag has none)
if ! (cd "$DOTS_DIR" && gh release create "$next" --verify-tag --title "$next" --notes-file "$notes"); then
    echo "lyne release: the tag $next is on GitHub, but the release wasn't published. Again with:"
    echo "  cd $DOTS_DIR && gh release create $next --verify-tag --title $next --notes-file <(git tag -l --format='%(contents)' $next)"
    rm -f "$notes"
    return 1
fi
rm -f "$notes"
echo -e "\e[1;32m✔ $next released\e[0m"
