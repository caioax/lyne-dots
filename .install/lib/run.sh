#!/bin/bash
# =============================================================================
# run.sh - Unattended install steps: progress screen, log file, sudo, dry run
# =============================================================================
# Each step is a function run in the background with its output in the log
# file, while the screen shows the step list, a progress bar (steps weighted
# by how long they take, package steps moving with each package installed)
# and the step's last lines of output. Steps share values through
# step_export (they run in subshells). A failed step is marked and the rest
# go on, unless it's critical (checks, AUR helper).
# Usage: source ui.sh, then this file
# =============================================================================

STEP_FNS=() STEP_LABELS=() STEP_WEIGHTS=() STEP_TOTALS=() STEP_CRITICAL=()
STEP_STATUS=() STEP_NOTES=()
RUN_PID="" RUN_SUDO_PID="" RUN_SUDO_DIR="" RUN_SUDO_REQUEST="" RUN_PLAIN=${RUN_PLAIN:-0} RUN_ABORTED=0 RUN_CANCELLED=0 RUN_SECONDS=0
RUN_TAIL_LINES=6

# pacman prints one of these per package when its output isn't a terminal
# (yay and paru too, for the packages they build), after a "Packages (N)"
# line with the size of the transaction (dependencies included)
RUN_TICK_RE='^(installing|upgrading|reinstalling|downgrading) '
RUN_TRANSACTION_RE='^Packages \(([0-9]+)\)'

# step_add <function> <label> [weight] [packages] [critical]
#   weight   share of the progress bar (1 = a quick step)
#   packages how many packages it installs: the bar moves as each one is
#            installed
#   critical 1 = stop the install when it fails
step_add() {
    STEP_FNS+=("$1")
    STEP_LABELS+=("$2")
    STEP_WEIGHTS+=("${3:-1}")
    STEP_TOTALS+=("${4:-0}")
    STEP_CRITICAL+=("${5:-0}")
    STEP_STATUS+=(todo)
    STEP_NOTES+=("")
}

# Inside a step: makes a value available to the next steps
step_export() {
    printf '%s=%q\n' "$1" "$2" >>"$RUN_STATE"
}

# The log file (under ~/.cache/lyne) and the file steps share values in
run_log_init() {
    local stamp=$1
    local dir="${XDG_CACHE_HOME:-$HOME/.cache}/lyne"
    mkdir -p "$dir"
    LOG_FILE="$dir/install-$stamp.log"
    RUN_STATE="$dir/.install-$stamp.state"
    : >"$LOG_FILE"
    : >"$RUN_STATE"
}

# ---------------------------------------------------------------------------
# sudo: asked once before the install, kept alive while it runs
# ---------------------------------------------------------------------------
run_sudo_start() {
    sudo -v || return 1
    (
        while kill -0 "$$" 2>/dev/null; do
            sleep "${RUN_SUDO_KEEPALIVE:-50}"
            sudo -n -v 2>/dev/null
        done
    ) </dev/null >/dev/null 2>&1 &
    RUN_SUDO_PID=$!

    # The steps' sudo (theirs, makepkg's, yay's): never a prompt hidden
    # behind the progress screen. makepkg runs `sudo -k pacman ...`, which
    # ignores the cached password and asks again every time (twice for
    # `makepkg -si`): the -k goes, the password was just checked. When it
    # was forgotten anyway (a suspend, a very long build) it asks run_steps
    # to get it again in the foreground, and waits
    RUN_SUDO_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lyne-sudo.XXXXXX")" || return 1
    RUN_SUDO_REQUEST="$RUN_SUDO_DIR/request"
    cat >"$RUN_SUDO_DIR/sudo" <<'EOF'
#!/bin/bash
# sudo for the lyne-dots install steps (.install/lib/run.sh)
dir="$(dirname "$(realpath "$0")")"
real="$(PATH="${PATH//$dir:/}" command -v sudo)"
# -k (ignore the cached password) dropped when a command follows
args=() command=0
for a in "$@"; do
    if ((!command)) && [[ "$a" == -* ]]; then
        [[ "$a" == -k || "$a" == --reset-timestamp ]] && continue
    else
        command=1
    fi
    args+=("$a")
done
((command)) || args=("$@")
for _ in 1 2 3; do
    if "$real" -n true 2>/dev/null; then
        exec "$real" "${args[@]}"
    fi
    echo "[sudo] the password is needed again: asking for it" >&2
    rm -f "$dir/failed"
    touch "$dir/request"
    while [[ -e "$dir/request" ]]; do sleep 0.3; done
    [[ -e "$dir/failed" ]] && break
done
echo "sudo: no password, $* not run" >&2
exit 1
EOF
    chmod +x "$RUN_SUDO_DIR/sudo"
}

# A step's sudo asked for the password: out of the progress screen, ask for
# it where it can be seen, back in
_run_sudo_again() {
    local ok=0
    if ((!RUN_PLAIN)) && [[ -t 0 ]]; then
        ui_leave
        printf '\n%s\n' "The installation needs your sudo password again."
        sudo -v && ok=1
        ui_enter
        ui_keys_off
    fi
    ((ok)) || touch "$RUN_SUDO_DIR/failed"
    rm -f "$RUN_SUDO_REQUEST"
}

run_sudo_stop() {
    [[ -n "$RUN_SUDO_PID" ]] && kill "$RUN_SUDO_PID" 2>/dev/null
    RUN_SUDO_PID=""
    [[ -n "${RUN_SUDO_DIR:-}" ]] && rm -rf "$RUN_SUDO_DIR"
    RUN_SUDO_DIR=""
}

# ---------------------------------------------------------------------------
# Running the steps
# ---------------------------------------------------------------------------
_run_killtree() {
    local child
    for child in $(pgrep -P "$1" 2>/dev/null); do
        _run_killtree "$child"
    done
    kill -TERM "$1" 2>/dev/null
}

# Ctrl+C while installing: stops the running step (sudo passes the signal on
# to pacman) and skips the rest
run_cancel() {
    RUN_CANCELLED=1
    RUN_ABORTED=1
    [[ -n "$RUN_PID" ]] && _run_killtree "$RUN_PID"
}

# The step's output since it started, without escapes and carriage returns
_run_section() {
    tail -c +$(($1 + 1)) "$LOG_FILE" 2>/dev/null |
        tr '\r' '\n' |
        sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\x1b[()][A-Z0-9]//g'
}

run_steps() {
    local n=${#STEP_FNS[@]} i total_w=0 done_w=0 start=$SECONDS
    for ((i = 0; i < n; i++)); do total_w=$((total_w + STEP_WEIGHTS[i])); done
    ((total_w > 0)) || total_w=1

    for ((i = 0; i < n; i++)); do
        if ((RUN_ABORTED)); then
            STEP_STATUS[i]=skip
            continue
        fi
        STEP_STATUS[i]=run
        printf '\n===== %s (%s) =====\n' "${STEP_LABELS[i]}" "${STEP_FNS[i]}" >>"$LOG_FILE"
        local offset
        offset=$(stat -c %s "$LOG_FILE")

        (
            # shellcheck disable=SC1090
            source "$RUN_STATE"
            set -o pipefail
            # shellcheck disable=SC2030 # only the step's own subshell runs with the sudo wrapper
            [[ -n "$RUN_SUDO_DIR" ]] && PATH="$RUN_SUDO_DIR:$PATH"
            # "function arg..." (install_packages core)
            read -ra cmd <<<"${STEP_FNS[i]}"
            "${cmd[@]}"
        ) >>"$LOG_FILE" 2>&1 </dev/null &
        RUN_PID=$!

        local frame=0
        while kill -0 "$RUN_PID" 2>/dev/null; do
            [[ -n "$RUN_SUDO_REQUEST" && -e "$RUN_SUDO_REQUEST" ]] && _run_sudo_again
            ((RUN_PLAIN)) || _run_draw "$i" "$offset" "$frame" "$start" "$done_w" "$total_w"
            frame=$((frame + 1))
            sleep 0.15
        done
        wait "$RUN_PID"
        local rc=$?
        RUN_PID=""

        local section warning
        section="$(_run_section "$offset")"
        warning="$(grep -m1 -E '^\[WARN\]' <<<"$section" | sed -E 's/^\[WARN\] *//')"
        if ((RUN_CANCELLED)); then
            STEP_STATUS[i]=fail
            STEP_NOTES[i]="cancelled"
        elif ((rc != 0)); then
            STEP_STATUS[i]=fail
            # The step's own error message, or its last line
            STEP_NOTES[i]="$(grep -E '^\[ERROR\]' <<<"$section" | tail -n1 | sed -E 's/^\[ERROR\] *//')"
            [[ -n "${STEP_NOTES[i]}" ]] || STEP_NOTES[i]="$(grep -v '^[[:space:]]*$' <<<"$section" | tail -n1)"
            ((STEP_CRITICAL[i])) && RUN_ABORTED=1
        elif [[ -n "$warning" ]]; then
            STEP_STATUS[i]=warn
            STEP_NOTES[i]=$warning
        else
            STEP_STATUS[i]=ok
        fi
        printf '===== %s: %s (exit %d)\n' "${STEP_LABELS[i]}" "${STEP_STATUS[i]}" "$rc" >>"$LOG_FILE"
        ((RUN_PLAIN)) && printf '[%s] %s%s\n' "${STEP_STATUS[i]}" "${STEP_LABELS[i]}" "${STEP_NOTES[i]:+ (${STEP_NOTES[i]})}"
        done_w=$((done_w + STEP_WEIGHTS[i]))
    done

    # shellcheck disable=SC2034 # read by install.sh's summary
    RUN_SECONDS=$((SECONDS - start))
    ((RUN_PLAIN)) || _run_draw -1 0 0 "$start" "$total_w" "$total_w"
}

# 0 when every step finished without failing
run_ok() {
    local s
    for s in "${STEP_STATUS[@]}"; do
        [[ "$s" == fail || "$s" == skip ]] && return 1
    done
    return 0
}

_run_clock() {
    printf '%02d:%02d' $(($1 / 60)) $(($1 % 60))
}

_run_step_line() {
    local i=$1 frame=$2
    local label=${STEP_LABELS[i]} note=${STEP_NOTES[i]} mark style=""
    case ${STEP_STATUS[i]} in
    ok) mark="$C_OK$G_OK" ;;
    warn) mark="$C_WARN$G_WARN" ;;
    fail) mark="$C_FAIL$G_FAIL" ;;
    skip) mark="$C_DIM$G_SKIP" style=$C_DIM ;;
    run) mark="$C_SEL${G_SPIN[frame % ${#G_SPIN[@]}]}" style=$C_BOLD ;;
    *) mark=$G_TODO style=$C_DIM ;;
    esac
    local line="$mark$C_RESET $style$(ui_fit "$label" $((UI_WIDTH - 2)))$C_RESET"
    local rest=$((UI_WIDTH - 2 - ${#label} - 3))
    if [[ -n "$note" ]] && ((rest > 8)); then
        line+="  $C_DIM$(ui_fit "$note" "$rest")$C_RESET"
    fi
    ui_add "$line"
}

# cur = the running step (-1 when done)
_run_draw() {
    local cur=$1 offset=$2 frame=$3 start=$4 done_w=$5 total_w=$6
    local n=${#STEP_FNS[@]} i section="" frac=0

    ui_frame
    ui_banner
    local title="Installing"
    if ((cur < 0)); then
        title="Done"
        run_ok || title="Finished with problems"
        ((RUN_ABORTED)) && title="Stopped"
        ((RUN_CANCELLED)) && title="Cancelled"
    fi
    ui_title "$title" "$(_run_clock $((SECONDS - start)))"

    # Package steps move with each package; the bar never reaches the end of
    # a step before it's over
    if ((cur >= 0)); then
        section="$(_run_section "$offset")"
        if ((STEP_TOTALS[cur] > 0)); then
            # The estimate from the package lists, until pacman's own counts
            # (dependencies included) add up to more
            local ticks total=0 count
            ticks=$(grep -cE "$RUN_TICK_RE" <<<"$section")
            while read -r count; do
                total=$((total + count))
            done < <(sed -nE "s/$RUN_TRANSACTION_RE.*/\\1/p" <<<"$section")
            ((total < STEP_TOTALS[cur])) && total=${STEP_TOTALS[cur]}
            frac=$((ticks * 100 / total))
            ((frac > 95)) && frac=95
        fi
    fi
    local pct=$(((done_w * 100 + (cur >= 0 ? STEP_WEIGHTS[cur] * frac : 0)) / total_w))
    ((pct > 100)) && pct=100

    # Steps that fit: 13 lines go to the banner, bar, output and log. Short
    # terminals (the 80x25 console) give output lines up to keep 7 step rows
    local tail_n=$RUN_TAIL_LINES
    local room=$((UI_ROWS - 13 - tail_n))
    if ((room < 7)); then
        tail_n=$((tail_n - (7 - room)))
        ((tail_n < 2)) && tail_n=2
        room=$((UI_ROWS - 13 - tail_n))
        ((room < 3)) && room=3
    fi
    local first=0 last=$n
    if ((n > room)); then
        local focus=$cur
        ((focus < 0)) && focus=$((n - 1))
        first=$((focus - room / 3))
        ((first < 0)) && first=0
        ((first > n - room)) && first=$((n - room))
        last=$((first + room))
        # The first and last rows say how many steps are hidden
        ((first > 0)) && first=$((first + 1))
        ((last < n)) && last=$((last - 1))
    fi
    ((first > 0)) && ui_add "$C_DIM  $G_ELLIPSIS $first earlier$C_RESET"
    for ((i = first; i < last; i++)); do
        _run_step_line "$i" "$frame"
    done
    ((last < n)) && ui_add "$C_DIM  $G_ELLIPSIS $((n - last)) more$C_RESET"

    UI_LINES+=("")
    local bar_w=$((UI_WIDTH - 7))
    local filled=$((pct * bar_w / 100)) bar_on bar_off
    printf -v bar_on '%*s' "$filled" ""
    printf -v bar_off '%*s' $((bar_w - filled)) ""
    ui_add "$C_ACCENT${bar_on// /$G_FULL}$C_RESET$C_DIM${bar_off// /$G_EMPTY}$C_RESET $(printf '%4s' "$pct%")"

    UI_LINES+=("")
    if ((cur >= 0 && tail_n > 0)); then
        local line count=0
        while IFS= read -r line; do
            ui_add "$C_DIM$G_PIPE $(ui_fit "$line" $((UI_WIDTH - 2)))$C_RESET"
            count=$((count + 1))
        done < <(grep -vE '^[[:space:]]*$|^=====' <<<"$section" | tail -n "$tail_n")
        for ((; count < tail_n; count++)); do ui_add "$C_DIM$G_PIPE$C_RESET"; done
        UI_LINES+=("")
    fi
    ui_add "${C_DIM}log: $(ui_fit "${LOG_FILE/#$HOME/\~}" $((UI_WIDTH - 5)))$C_RESET"
    ui_flush
}

# ---------------------------------------------------------------------------
# Dry run: a throwaway HOME and stand-ins for everything that changes the
# system (sudo, pacman -S, yay, systemctl, stow...). Read-only commands
# (pacman -Q, systemctl list-unit-files) still ask the real system. Files the
# steps write land in the throwaway HOME, to be looked at afterwards.
# LYNE_DRY_HOME reuses one; LYNE_DRY_DELAY sets the time per fake package;
# LYNE_DRY_FRESH=1 acts as if no package were installed, LYNE_DRY_INSTALLED=
# "name=version ..." as if only those were; LYNE_DRY_FAIL="cmd
# ..." makes those stand-ins fail (tests of the failure paths).
# ---------------------------------------------------------------------------
run_dry_setup() {
    # Without its stand-ins a dry run would reach the real sudo: any problem
    # setting them up stops here
    _run_dry_fail() {
        log_error "Dry run: $1. Nothing was run."
        exit 1
    }
    if [[ -z "${LYNE_DRY_HOME:-}" ]]; then
        LYNE_DRY_HOME="$(mktemp -d "${TMPDIR:-/tmp}/lyne-install-dry.XXXXXX")" ||
            _run_dry_fail "could not create a throwaway HOME"
    fi
    mkdir -p "$LYNE_DRY_HOME" 2>/dev/null || _run_dry_fail "could not create $LYNE_DRY_HOME"
    LYNE_DRY_HOME="$(cd "$LYNE_DRY_HOME" && pwd)"
    [[ -n "$LYNE_DRY_HOME" && "$LYNE_DRY_HOME" != / && "$LYNE_DRY_HOME" != "$HOME" ]] ||
        _run_dry_fail "LYNE_DRY_HOME must be a folder of its own"
    local bin="$LYNE_DRY_HOME/.dry-run-bin"
    mkdir -p "$bin" || _run_dry_fail "could not create $bin"

    cat >"$bin/dry-stub" <<'EOF'
#!/bin/bash
# lyne installer dry run: stands in for a command that changes the system
name="$(basename "$0")"
bin="$(dirname "$(realpath "$0")")"
real() { PATH="${PATH//$bin:/}" command "$@"; }
delay="${LYNE_DRY_DELAY:-0.02}"

# LYNE_DRY_FRESH / LYNE_DRY_INSTALLED ("name=version ..."): a made-up
# package database instead of the real one (queries and -T read it)
fake_db() { [[ -n "${LYNE_DRY_FRESH:-}${LYNE_DRY_INSTALLED:-}" ]]; }
fake_version() {
    local entry
    for entry in ${LYNE_DRY_INSTALLED:-}; do
        [[ "${entry%%=*}" == "$1" ]] && { echo "${entry#*=}"; return 0; }
    done
    return 1
}
installed() {
    if fake_db; then fake_version "$1" >/dev/null; else real pacman -Qq "$1" &>/dev/null; fi
}

# pacman -Q/-Qq [names] and -Qs/-Qqs regex against the made-up database
fake_query() {
    local flags=$1 quiet=0 search=0 entry name rc=0
    shift
    [[ "$flags" == *q* ]] && quiet=1
    [[ "$flags" == *s* ]] && search=1
    if ((search)) || (($# == 0)); then
        rc=1
        for entry in ${LYNE_DRY_INSTALLED:-}; do
            name=${entry%%=*}
            if (($# == 0)) || [[ "$name" =~ $1 ]]; then
                ((quiet)) && echo "$name" || echo "$name ${entry#*=}"
                rc=0
            fi
        done
        return $rc
    fi
    for name in "$@"; do
        if entry="$(fake_version "$name")"; then
            ((quiet)) && echo "$name" || echo "$name $entry"
        else
            echo "error: package '$name' was not found" >&2
            rc=1
        fi
    done
    return $rc
}

if [[ " ${LYNE_DRY_FAIL:-} " == *" $name "* ]]; then
    echo "[dry-run] $name $* (made to fail)"
    echo "error: $name failed (LYNE_DRY_FAIL)" >&2
    exit 1
fi

# Fake package install: one "installing" line per missing package, like
# pacman prints without a terminal
fake_install() {
    local pkg missing=0
    for pkg in "$@"; do
        [[ "$pkg" == -* ]] || installed "$pkg" || missing=$((missing + 1))
    done
    ((missing)) && echo "Packages ($missing) $(printf '%s\n' "$@" | grep -v '^-' | tr '\n' ' ')"
    for pkg in "$@"; do
        [[ "$pkg" == -* ]] && continue
        if installed "$pkg"; then
            echo "warning: $pkg is up to date -- skipping"
        else
            sleep "$delay"
            echo "installing $pkg..."
        fi
    done
}

case "$name" in
sudo)
    all="$*"
    # LYNE_DRY_SUDO_TTL=<seconds>: a password cache that expires, asked on
    # the terminal like the real sudo (tests of the password asked again)
    if [[ -n "${LYNE_DRY_SUDO_TTL:-}" ]]; then
        ts="$HOME/.dry-sudo-ts" now="$(date +%s)" nonint=0 reset=0
        for a in "$@"; do
            [[ "$a" == -* ]] || break
            [[ "$a" == -n ]] && nonint=1
            [[ "$a" == -k ]] && reset=1
        done
        # -k with a command ignores the cache (makepkg does that)
        if ((reset)) || [[ ! -f "$ts" ]] || ((now - $(<"$ts") >= LYNE_DRY_SUDO_TTL)); then
            if ((nonint)); then
                echo "sudo: a password is required" >&2
                exit 1
            fi
            printf '[sudo] password for %s: ' "$USER" >/dev/tty
            IFS= read -rs _ </dev/tty
            printf '\n' >/dev/tty
            echo "[dry-run] password asked: $all" >>"$HOME/.dry-sudo-prompts"
        fi
        echo "$now" >"$ts"
    fi
    while [[ "${1:-}" == -* ]]; do shift; done
    # sudo tee FILE: what would be written goes to the log (on stderr: the
    # caller usually sends tee's output to /dev/null)
    if [[ "${1:-}" == tee ]]; then
        echo "[dry-run] sudo $all" >&2
        sed 's/^/[dry-run]   /' >&2
        exit 0
    fi
    echo "[dry-run] sudo $all"
    [[ $# -eq 0 ]] && exit 0
    # Only stand-ins run: sudo never runs a real command here
    if [[ -x "$bin/$1" && "$1" != dry-stub ]]; then
        exec "$bin/$1" "${@:2}"
    fi
    exit 0
    ;;
pacman)
    case "${1:-}" in
    -S*) echo "[dry-run] pacman $*"; fake_install "${@:2}" ;;
    -U* | -R* | -D*) echo "[dry-run] pacman $*" ;;
    -T)
        if fake_db; then
            rc=0
            for pkg in "${@:2}"; do installed "$pkg" || { echo "$pkg"; rc=127; }; done
            exit $rc
        fi
        exec -a pacman "$(PATH="${PATH//$bin:/}" command -v pacman)" "$@" ;;
    -Q*)
        if fake_db; then fake_query "$@"; exit $?; fi
        exec -a pacman "$(PATH="${PATH//$bin:/}" command -v pacman)" "$@" ;;
    *) exec -a pacman "$(PATH="${PATH//$bin:/}" command -v pacman)" "$@" ;;
    esac
    ;;
yay | paru)
    echo "[dry-run] $name $*"
    [[ "${1:-}" == -S* ]] && LYNE_DRY_DELAY="$(awk "BEGIN { print $delay * 5 }")" fake_install "${@:2}"
    ;;
git)
    if [[ "${1:-}" == clone ]]; then
        echo "[dry-run] git $*"
        dest="${!#}"
        mkdir -p "$dest"
        printf '#!/bin/bash\necho "[dry-run] %s/install.sh $*"\n' "$dest" >"$dest/install.sh"
        chmod +x "$dest/install.sh"
    else
        real git "$@"
    fi
    ;;
makepkg)
    echo "[dry-run] makepkg $*"
    # Like makepkg: deps (-s) and the install (-i) through `sudo -k pacman`
    [[ " $* " == *" -s"* || " $* " == *" -si "* ]] && sudo -k pacman -S --asdeps --noconfirm go
    [[ " $* " == *" -i"* || " $* " == *" -si "* ]] && sudo -k pacman -U --noconfirm ./fake.pkg.tar.zst
    exit 0
    ;;
systemctl)
    case "${1:-}" in
    list-unit-files | is-enabled | is-active | status | show | cat) real systemctl "$@" ;;
    *) echo "[dry-run] systemctl $*" ;;
    esac
    ;;
*)
    echo "[dry-run] $name $*"
    ;;
esac
exit 0
EOF
    chmod +x "$bin/dry-stub"
    local cmd
    for cmd in sudo pacman yay paru makepkg git systemctl stow chsh reboot \
        modprobe udevadm gsettings kbuildsycoca6 awww awww-daemon ping; do
        ln -sf dry-stub "$bin/$cmd" || _run_dry_fail "could not create the $cmd stand-in"
    done

    export LYNE_DRY_RUN=1 LYNE_DRY_HOME
    # shellcheck disable=SC2031 # the PATH change at the step subshell is meant to stay there
    export HOME="$LYNE_DRY_HOME" PATH="$bin:$PATH"
    hash -r
    [[ "$(command -v sudo)" == "$bin/sudo" ]] || _run_dry_fail "sudo doesn't resolve to its stand-in"
    # Only the throwaway HOME: nothing may follow these to the real one
    unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
}
