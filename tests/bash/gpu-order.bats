#!/usr/bin/env bats
# lib/gpu-order.sh: GPU links, udev rules, the order and gpus.lua

load helpers

setup() {
    lyne_setup
    SYS="$BATS_TEST_TMPDIR/sys"
    export LYNE_SYSFS="$SYS" LYNE_PCI_IDS="$FIXTURES/pci.ids"
    export LYNE_UDEV_DIR="$BATS_TEST_TMPDIR/udev" LYNE_HYPR_DIR="$HOME/.config/hypr"
    export LYNE_STATE_FILE="$HOME/state.json"
    mkdir -p "$LYNE_UDEV_DIR"
    echo '{"gpus": {"order": []}, "other": 1}' >"$LYNE_STATE_FILE"
}

hybrid() {
    fx_gpu "$SYS" 0000:01:00.0 10de:1f9d driver=nvidia card=card0 outputs="HDMI-A-1:connected"
    fx_gpu "$SYS" 0000:00:02.0 8086:3e9b driver=i915 card=card1 outputs="eDP-1:connected"
}

order() { in_lyne gpus gpu-order -- "gpu_detect; gpu_links; $1"; }

@test "links: vendor and kind, -2 on repeats, none for virtual GPUs" {
    fx_gpu "$SYS" 0000:00:02.0 8086:3e9b
    fx_gpu "$SYS" 0000:01:00.0 10de:1f9d
    fx_gpu "$SYS" 0000:02:00.0 10de:2882
    fx_gpu "$SYS" 0000:03:00.0 1a03:2000
    fx_gpu "$SYS" 0000:04:00.0 1002:15bf
    fx_gpu "$SYS" 0000:00:01.0 1af4:1050
    run order 'for ((i = 0; i < GPU_COUNT; i++)); do echo "${GPU_PCI[i]}=${GPU_LINK[i]}"; done'
    assert_success
    assert_line "0000:00:02.0=intel-igpu"
    assert_line "0000:04:00.0=amd-igpu"
    assert_line "0000:01:00.0=nvidia-dgpu"
    assert_line "0000:02:00.0=nvidia-dgpu-2"
    assert_line "0000:03:00.0=gpu-dgpu"
    assert_line "0000:00:01.0="
}

@test "gpu_multi counts real GPUs only" {
    fx_gpu "$SYS" 0000:01:00.0 10de:1f9d
    fx_gpu "$SYS" 0000:00:01.0 1af4:1050
    run order 'gpu_multi'
    assert_failure
    fx_gpu "$SYS" 0000:00:02.0 8086:3e9b
    run order 'gpu_multi'
    assert_success
}

@test "rules: one symlink per GPU by PCI address, installed once" {
    hybrid
    run order 'gpu_rules_content'
    assert_line 'KERNEL=="card*", KERNELS=="0000:00:02.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/intel-igpu"'
    assert_line 'KERNEL=="card*", KERNELS=="0000:01:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/nvidia-dgpu"'
    run order 'gpu_rules_install'
    assert_success
    assert_equal "$(grep -c SYMLINK "$LYNE_UDEV_DIR/90-lyne-gpus.rules")" 2
    run cat "$STUB_LOG"
    assert_line "udevadm control --reload"
    assert_line "udevadm trigger --subsystem-match=drm"
    : >"$STUB_LOG"
    run order 'gpu_rules_install'
    assert_failure 1
    assert_output --partial "already set up"
    run cat "$STUB_LOG"
    refute_output --partial udevadm
}

@test "duplicates: hand-made files with only our links (continuations joined)" {
    hybrid
    cat >"$LYNE_UDEV_DIR/80-mine.rules" <<'EOF'
# set up by hand, like the wiki
KERNEL=="card*", \
    KERNELS=="0000:01:00.0", \
    SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/nvidia-dgpu"
EOF
    cat >"$LYNE_UDEV_DIR/81-more.rules" <<'EOF'
KERNEL=="card*", KERNELS=="0000:00:02.0", SUBSYSTEM=="drm", SYMLINK+="dri/intel-igpu"
ACTION=="add", SUBSYSTEM=="usb", RUN+="/bin/true"
EOF
    echo 'KERNEL=="card*", KERNELS=="0000:00:02.0", SYMLINK+="dri/igpu"' >"$LYNE_UDEV_DIR/82-other-name.rules"
    echo '# only comments' >"$LYNE_UDEV_DIR/83-empty.rules"
    run order 'gpu_rules_install >/dev/null; gpu_rules_duplicates'
    assert_success
    assert_output "$LYNE_UDEV_DIR/80-mine.rules"
}

@test "resolve: presets, explicit addresses, errors on stderr only" {
    hybrid
    run order 'gpu_order_resolve auto; echo "status=$?"'
    assert_output "status=0"
    run order 'gpu_order_resolve igpu | xargs'
    assert_output "0000:00:02.0 0000:01:00.0"
    run order 'gpu_order_resolve dgpu | xargs'
    assert_output "0000:01:00.0 0000:00:02.0"
    run order 'gpu_order_resolve only-dgpu'
    assert_output "0000:01:00.0"
    run order 'gpu_order_resolve 0000:01:00.0 0000:00:02.0 | xargs'
    assert_output "0000:01:00.0 0000:00:02.0"
    run order 'gpu_order_resolve 0000:09:00.0 2>/dev/null'
    assert_failure
    assert_output ""
    run order 'gpu_order_resolve 0000:09:00.0 2>&1 >/dev/null'
    assert_output --partial "No GPU at 0000:09:00.0"
}

@test "resolve: only-igpu without an integrated GPU fails" {
    fx_gpu "$SYS" 0000:01:00.0 10de:1f9d
    fx_gpu "$SYS" 0000:02:00.0 10de:2882
    run order 'gpu_order_resolve only-igpu 2>&1'
    assert_failure
    assert_output --partial "No GPU for 'only-igpu'"
    # only-* keeps the first GPU of the kind
    run order 'gpu_order_resolve only-dgpu'
    assert_output "0000:01:00.0"
}

@test "an AQ_DRM_DEVICES value maps to PCI addresses through links and cards" {
    hybrid
    local dri="$BATS_TEST_TMPDIR/dev/dri"
    mkdir -p "$dri"
    touch "$dri/card0" "$dri/card1"
    ln -s card0 "$dri/nvidia-dgpu"
    run order "gpu_order_from_aq '$dri/nvidia-dgpu:$dri/card1:$dri/missing:' | xargs"
    assert_output "0000:01:00.0 0000:00:02.0"
}

# Runs gpus.lua in Lua with hl.env recorded and io.popen answering $2 (the
# paths present; "nil" = popen fails)
run_lua() {
    local popen='io.popen = function() return { read = function() return os.getenv("PRESENT") end, close = function() end } end'
    [[ "$2" == nil ]] && popen='io.popen = function() return nil end'
    PRESENT="$2" lua - <<EOF
hl = { env = function(k, v) print(k .. "=" .. v) end }
$popen
$1
print("file=" .. lyne_gpus_file)
EOF
}

@test "gpus.lua: automatic sets nothing; an order sets the GPUs present" {
    command -v lua >/dev/null || skip "lua not installed"
    hybrid
    run order 'gpu_lua_content'
    run run_lua "$output" ""
    assert_output "file=automatic"
    run order 'gpu_lua_content 0000:01:00.0 0000:00:02.0'
    local lua="$output"
    run run_lua "$lua" $'/dev/dri/nvidia-dgpu\n/dev/dri/intel-igpu\n'
    assert_line "AQ_DRM_DEVICES=/dev/dri/nvidia-dgpu:/dev/dri/intel-igpu"
    assert_line "file=0000:01:00.0 0000:00:02.0"
    # A missing link is dropped; none present leaves AQ unset
    run run_lua "$lua" $'/dev/dri/intel-igpu\n'
    assert_line "AQ_DRM_DEVICES=/dev/dri/intel-igpu"
    run run_lua "$lua" ""
    refute_output --partial AQ_DRM_DEVICES
    # popen unavailable: the whole order
    run run_lua "$lua" nil
    assert_line "AQ_DRM_DEVICES=/dev/dri/nvidia-dgpu:/dev/dri/intel-igpu"
}

@test "gpu_order_write: gpus.lua written whole, state.json gets the order" {
    hybrid
    run order 'gpu_order_write 0000:01:00.0 0000:00:02.0 && gpu_order_saved | xargs'
    assert_success
    assert_output "0000:01:00.0 0000:00:02.0"
    assert [ -f "$LYNE_HYPR_DIR/local/gpus.lua" ]
    run ls -A "$LYNE_HYPR_DIR/local"
    assert_output "gpus.lua"
    run ls -A "$LYNE_HYPR_DIR"
    assert_output "local"
    assert_equal "$(jq -c . "$LYNE_STATE_FILE")" '{"gpus":{"order":["0000:01:00.0","0000:00:02.0"]},"other":1}'
    run order 'gpu_order_write && gpu_order_saved'
    assert_output ""
    grep -q 'lyne_gpus_file = "automatic"' "$LYNE_HYPR_DIR/local/gpus.lua"
}

@test "running order and explicit list from this session's Hyprland log" {
    hybrid
    export LYNE_HYPR_LOG="$BATS_TEST_TMPDIR/hyprland.log"
    cat >"$LYNE_HYPR_LOG" <<'EOF'
[LOG] drm: Explicit device list /dev/dri/card1:/dev/dri/card0
[LOG] drm: Starting backend for /dev/dri/card1
[LOG] drm: Starting backend for /dev/dri/card0
[LOG] drm: Starting backend for /dev/dri/card1
EOF
    run order 'gpu_running_order | xargs; gpu_running_explicit && echo explicit'
    assert_line "0000:00:02.0 0000:01:00.0"
    assert_line explicit
    unset LYNE_HYPR_LOG
    run order 'gpu_running_order; gpu_running_explicit || echo none'
    assert_output none
}
