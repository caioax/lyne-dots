#!/bin/bash
# =============================================================================
# power-profiles.sh - The power profiles daemon (UPower.PowerProfiles)
# =============================================================================
# The shell switches profiles through the D-Bus API (org.freedesktop.UPower.
# PowerProfiles, as Quickshell asks; also net.hadess) that power-profiles-daemon,
# tuned-ppd and tlp-pd all serve (they conflict with each other). Whoever runs
# TLP or TuneD gets its own bridge (tlp-pd, tuned-ppd), everyone else
# power-profiles-daemon. auto-cpufreq has no bridge and fights them, so it
# blocks the install.
#
#   pp_daemon            the daemon package installed, or nothing
#   pp_candidate         what pp_install would add, or nothing when something
#                        blocks it (see pp_blocker)
#   pp_blocker           what keeps it from installing: auto-cpufreq, or
#                        tlp+tuned (they conflict); nothing when it can
#   pp_rival <daemon>    a tool that fights that daemon over the CPU:
#                        auto-cpufreq, or tlp / tuned without its own bridge
#   pp_state             ok <daemon> (on the bus; daemon "unknown" when no
#                        package says), stopped <daemon> (installed, not on the
#                        bus: masked?), both followed by the rival if any;
#                        missing <candidate> or conflict <blocker>
#   pp_install           install the candidate and enable its service, or
#                        enable the installed one; 1 when blocked (nothing to
#                        do when an unknown daemon is on the bus)
#   pp_has_battery       0 on a laptop (a BAT* power supply)
#   pp_auto_install      the installer's and migration's take: on a laptop
#                        with no daemon and no TLP, TuneD or auto-cpufreq,
#                        install power-profiles-daemon; anything else is
#                        left as it is (Settings › System › Power profiles
#                        offers the rest)
#
# LYNE_PP_BUS_NAMES (the bus names, one per line), LYNE_PP_COMMANDS
# (installed commands, space separated) and LYNE_PP_POWER_SUPPLY (a
# /sys/class/power_supply stand-in) replace the system in tests; pacman is
# asked as is (stub it with a function).
# =============================================================================

PP_BUS_NAME="org.freedesktop.UPower.PowerProfiles"
PP_DAEMONS=(power-profiles-daemon tuned-ppd tlp-pd)

_pp_installed() {
    pacman -Q "$1" &>/dev/null
}

_pp_has_command() {
    if [[ -n "${LYNE_PP_COMMANDS+x}" ]]; then
        [[ " $LYNE_PP_COMMANDS " == *" $1 "* ]]
    else
        command -v "$1" &>/dev/null
    fi
}

# Running or activatable
_pp_on_bus() {
    local names
    if [[ -n "${LYNE_PP_BUS_NAMES+x}" ]]; then
        names="$LYNE_PP_BUS_NAMES"
    else
        names="$(busctl --system list --no-legend --no-pager 2>/dev/null | awk '{print $1}')"
    fi
    grep -qxF "$PP_BUS_NAME" <<<"$names"
}

pp_daemon() {
    local pkg
    for pkg in "${PP_DAEMONS[@]}"; do
        if _pp_installed "$pkg"; then
            echo "$pkg"
            return
        fi
    done
}

pp_blocker() {
    if _pp_installed auto-cpufreq || _pp_has_command auto-cpufreq; then
        echo auto-cpufreq
    elif _pp_installed tlp && _pp_installed tuned; then
        echo tlp+tuned
    fi
}

pp_candidate() {
    [[ -n "$(pp_blocker)" ]] && return
    if _pp_installed tlp; then
        echo tlp-pd
    elif _pp_installed tuned; then
        echo tuned-ppd
    else
        echo power-profiles-daemon
    fi
}

pp_rival() {
    if _pp_installed auto-cpufreq || _pp_has_command auto-cpufreq; then
        echo auto-cpufreq
    elif [[ "$1" != tlp-pd ]] && _pp_installed tlp; then
        echo tlp
    elif [[ "$1" != tuned-ppd ]] && _pp_installed tuned; then
        echo tuned
    fi
}

pp_state() {
    local daemon rival
    daemon="$(pp_daemon)"
    rival="$(pp_rival "$daemon")"
    if _pp_on_bus; then
        echo "ok ${daemon:-unknown}${rival:+ $rival}"
    elif [[ -n "$daemon" ]]; then
        echo "stopped $daemon${rival:+ $rival}"
    elif [[ -n "$(pp_blocker)" ]]; then
        echo "conflict $(pp_blocker)"
    else
        echo "missing $(pp_candidate)"
    fi
}

pp_install() {
    if ! command -v pacman &>/dev/null; then
        echo "   pacman not found: install power-profiles-daemon (or tuned-ppd / tlp-pd) and enable its service"
        return 1
    fi

    local pkg
    pkg="$(pp_daemon)"
    if [[ -z "$pkg" ]] && _pp_on_bus; then
        echo "   Another daemon already serves power profiles, nothing to do"
        return 0
    elif [[ -z "$pkg" ]]; then
        local blocker
        blocker="$(pp_blocker)"
        if [[ "$blocker" == auto-cpufreq ]]; then
            echo "   auto-cpufreq manages the CPU and fights power profile daemons: remove it first (auto-cpufreq --remove)"
            return 1
        elif [[ -n "$blocker" ]]; then
            echo "   TLP and TuneD are both installed and conflict: keep one of them first"
            return 1
        fi
        pkg="$(pp_candidate)"
        echo "   Installing $pkg..."
        sudo pacman -S --needed --noconfirm "$pkg" || return 1
    else
        echo "   $pkg already installed"
    fi

    echo "   Enabling $pkg.service..."
    sudo systemctl enable --now "$pkg.service"
}

pp_has_battery() {
    local supply
    for supply in "${LYNE_PP_POWER_SUPPLY:-/sys/class/power_supply}"/BAT*; do
        [[ -e "$supply" ]] && return 0
    done
    return 1
}

pp_auto_install() {
    if ! pp_has_battery; then
        echo "   No battery, skipping power profiles (Settings › System › Power profiles can install them)"
        return 0
    fi
    local daemon
    daemon="$(pp_daemon)"
    if [[ -n "$daemon" ]]; then
        echo "   $daemon already installed, skipping"
        return 0
    fi
    if _pp_on_bus; then
        echo "   Another daemon already serves power profiles, skipping"
        return 0
    fi
    local rival
    rival="$(pp_rival "")"
    if [[ -n "$rival" ]]; then
        echo "   $rival manages power here, skipping (Settings › System › Power profiles explains the options)"
        return 0
    fi
    pp_install
}
