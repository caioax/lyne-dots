#!/usr/bin/env bats
# lib/power-profiles.sh: which daemon, what blocks it, installing it
# shellcheck disable=SC2030,SC2031 # each @test runs in a subshell of its own

load helpers

setup() {
    lyne_setup
    export LYNE_PP_BUS_NAMES="" LYNE_PP_COMMANDS="" LYNE_PP_POWER_SUPPLY="$BATS_TEST_TMPDIR/power_supply"
    mkdir -p "$LYNE_PP_POWER_SUPPLY/AC"
}

on_bus() { export LYNE_PP_BUS_NAMES=$'org.freedesktop.DBus\norg.freedesktop.UPower.PowerProfiles'; }
battery() { mkdir -p "$LYNE_PP_POWER_SUPPLY/BAT0"; }
pp() { in_lyne power-profiles -- "$1"; }

@test "state: missing, ok, stopped, unknown daemon on the bus" {
    run pp pp_state
    assert_output "missing power-profiles-daemon"
    pkgs power-profiles-daemon
    run pp pp_state
    assert_output "stopped power-profiles-daemon"
    on_bus
    run pp pp_state
    assert_output "ok power-profiles-daemon"
    : >"$FAKE_PKGS"
    run pp pp_state
    assert_output "ok unknown"
}

@test "TLP and TuneD users get their own bridge" {
    pkgs tlp
    run pp pp_state
    assert_output "missing tlp-pd"
    : >"$FAKE_PKGS"
    pkgs tuned
    run pp pp_state
    assert_output "missing tuned-ppd"
    pkgs tuned-ppd
    on_bus
    run pp pp_state
    assert_output "ok tuned-ppd"
}

@test "rivals and conflicts" {
    pkgs power-profiles-daemon tlp
    on_bus
    run pp pp_state
    assert_output "ok power-profiles-daemon tlp"
    : >"$FAKE_PKGS"
    pkgs tlp tuned
    export LYNE_PP_BUS_NAMES=""
    run pp pp_state
    assert_output "conflict tlp+tuned"
    : >"$FAKE_PKGS"
    export LYNE_PP_COMMANDS="auto-cpufreq"
    run pp pp_state
    assert_output "conflict auto-cpufreq"
    pkgs power-profiles-daemon
    run pp pp_state
    assert_output "stopped power-profiles-daemon auto-cpufreq"
}

@test "install: the candidate, then its service" {
    pkgs tlp
    run pp pp_install
    assert_success
    run cat "$STUB_LOG"
    assert_line "sudo pacman -S --needed --noconfirm tlp-pd"
    assert_line "systemctl enable --now tlp-pd.service"
}

@test "install: an installed daemon is only enabled; another on the bus is left alone" {
    pkgs power-profiles-daemon
    run pp pp_install
    assert_success
    assert_line "   power-profiles-daemon already installed"
    run grep -c 'pacman -S' "$STUB_LOG"
    assert_output 0
    grep -qx "power-profiles-daemon.service" "$FAKE_ENABLED"
    : >"$FAKE_PKGS"
    : >"$STUB_LOG"
    on_bus
    run pp pp_install
    assert_success
    assert_output --partial "Another daemon already serves power profiles"
    run cat "$STUB_LOG"
    refute_output --partial "sudo"
}

@test "install: blocked by auto-cpufreq or by TLP with TuneD" {
    export LYNE_PP_COMMANDS="auto-cpufreq"
    run pp pp_install
    assert_failure
    assert_output --partial "auto-cpufreq --remove"
    export LYNE_PP_COMMANDS=""
    pkgs tlp tuned
    run pp pp_install
    assert_failure
    assert_output --partial "keep one of them first"
    run cat "$STUB_LOG"
    refute_output --partial "sudo"
}

@test "auto install: laptops with nothing get power-profiles-daemon; everything else is left alone" {
    run pp pp_auto_install
    assert_output --partial "No battery"
    battery
    pkgs tlp
    run pp pp_auto_install
    assert_output --partial "tlp manages power here"
    : >"$FAKE_PKGS"
    on_bus
    run pp pp_auto_install
    assert_output --partial "Another daemon already serves power profiles"
    export LYNE_PP_BUS_NAMES=""
    run grep -c sudo "$STUB_LOG"
    assert_output 0
    run pp pp_auto_install
    assert_success
    run cat "$STUB_LOG"
    assert_line "sudo pacman -S --needed --noconfirm power-profiles-daemon"
    run pp pp_auto_install
    assert_output --partial "power-profiles-daemon already installed, skipping"
}
