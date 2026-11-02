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

# Runs gpus.lua in Lua with hl.env and hl.config recorded and io.popen
# answering $2 ("<path> <1 = monitor plugged in|0>" lines for the GPUs
# present; "nil" = popen fails). $3 is the AQ_DRM_DEVICES Hyprland already
# has (a reload)
run_lua() {
    local popen='io.popen = function() return { read = function() return os.getenv("PRESENT") end, close = function() end } end'
    [[ "$2" == nil ]] && popen='io.popen = function() return nil end'
    env -u AQ_DRM_DEVICES PRESENT="$2" ${3:+AQ_DRM_DEVICES="$3"} lua - <<EOF
hl = {
    env = function(k, v) print(k .. "=" .. v) end,
    config = function(t) print("skip_non_kms=" .. tostring(t.quirks.skip_non_kms_dmabuf_formats)) end,
}
$popen
$1
print("file=" .. lyne_gpus_file)
EOF
}

NV=/dev/dri/nvidia-dgpu
IG=/dev/dri/intel-igpu

@test "gpus.lua: automatic sets nothing; an order sets the GPUs present" {
    command -v lua >/dev/null || skip "lua not installed"
    hybrid
    run order 'gpu_lua_content'
    local auto="$output"
    assert_output --partial "prime-run"
    run run_lua "$auto" ""
    assert_output "file=automatic"
    run order 'gpu_lua_content 0000:00:02.0 0000:01:00.0'
    local lua="$output"
    run run_lua "$lua" "$IG 1"$'\n'"$NV 1"
    assert_output "AQ_DRM_DEVICES=$IG:$NV"$'\n'"file=0000:00:02.0 0000:01:00.0"
    # A missing link is dropped; none present leaves AQ unset
    run run_lua "$lua" "$IG 1"
    assert_line "AQ_DRM_DEVICES=$IG"
    run run_lua "$lua" ""
    refute_output --partial AQ_DRM_DEVICES
    # popen unavailable: the whole order
    run run_lua "$lua" nil
    assert_line "AQ_DRM_DEVICES=$IG:$NV"
}

@test "gpus.lua: NVIDIA first renders with a monitor on it, with its variables and the quirk off" {
    command -v lua >/dev/null || skip "lua not installed"
    hybrid
    run order 'gpu_lua_content 0000:01:00.0 0000:00:02.0'
    local lua="$output"
    run run_lua "$lua" "$NV 1"$'\n'"$IG 1"
    assert_line "AQ_DRM_DEVICES=$NV:$IG"
    assert_line "LIBVA_DRIVER_NAME=nvidia"
    assert_line "__GLX_VENDOR_LIBRARY_NAME=nvidia"
    assert_line "skip_non_kms=false"
}

@test "gpus.lua: NVIDIA first without a monitor on it gives way to the integrated GPU" {
    command -v lua >/dev/null || skip "lua not installed"
    hybrid
    run order 'gpu_lua_content 0000:01:00.0 0000:00:02.0'
    run run_lua "$output" "$NV 0"$'\n'"$IG 1"
    assert_line "AQ_DRM_DEVICES=$IG:$NV"
    refute_output --partial LIBVA_DRIVER_NAME
    refute_output --partial __GLX_VENDOR_LIBRARY_NAME
    # Still off: the HDMI can be plugged in mid-session
    assert_line "skip_non_kms=false"
    # Only NVIDIA in the order: the integrated GPU comes from the rest
    run order 'gpu_lua_content 0000:01:00.0'
    local only="$output"
    run run_lua "$only" "$NV 0"$'\n'"$IG 1"
    assert_line "AQ_DRM_DEVICES=$IG:$NV"
    run run_lua "$only" "$NV 1"$'\n'"$IG 1"
    assert_line "AQ_DRM_DEVICES=$NV"
    # No GPU with a monitor at all: the order as it is
    run run_lua "$only" "$NV 0"$'\n'"$IG 0"
    assert_line "AQ_DRM_DEVICES=$NV"
}

@test "gpus.lua: a reload keeps the GPUs Hyprland started with" {
    command -v lua >/dev/null || skip "lua not installed"
    hybrid
    run order 'gpu_lua_content 0000:01:00.0 0000:00:02.0'
    # Started on the integrated GPU (no monitor on NVIDIA then); the HDMI
    # plugged in since doesn't move it, nor turn the NVIDIA variables on
    run run_lua "$output" "$NV 1"$'\n'"$IG 1" "$IG:$NV"
    assert_line "AQ_DRM_DEVICES=$IG:$NV"
    refute_output --partial LIBVA_DRIVER_NAME
}

@test "gpus.lua: integrated first and non-hybrid machines keep the quirk and the variables alone" {
    command -v lua >/dev/null || skip "lua not installed"
    hybrid
    run order 'gpu_lua_content 0000:00:02.0 0000:01:00.0'
    run run_lua "$output" "$IG 1"$'\n'"$NV 1"
    refute_output --partial skip_non_kms
    refute_output --partial LIBVA_DRIVER_NAME
    # Two dedicated GPUs: extra_environment.lua keeps setting the variables
    rm -rf "$SYS"
    fx_gpu "$SYS" 0000:01:00.0 10de:1f9d driver=nvidia card=card0 outputs="DP-1:connected"
    fx_gpu "$SYS" 0000:02:00.0 1002:73ff driver=amdgpu card=card1 outputs="DP-2:connected"
    run order 'gpu_lua_content 0000:01:00.0 0000:02:00.0'
    assert_line "local hybrid = false"
    local lua="$output"
    run run_lua "$lua" "/dev/dri/nvidia-dgpu 1"$'\n'"/dev/dri/amd-dgpu 1"
    assert_line "AQ_DRM_DEVICES=/dev/dri/nvidia-dgpu:/dev/dri/amd-dgpu"
    refute_output --partial LIBVA_DRIVER_NAME
    refute_output --partial skip_non_kms
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
