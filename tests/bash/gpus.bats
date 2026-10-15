#!/usr/bin/env bats
# lib/gpus.sh: GPU detection from a fake sysfs and a pci.ids excerpt

load helpers

setup() {
    lyne_setup
    SYS="$BATS_TEST_TMPDIR/sys"
    export LYNE_SYSFS="$SYS" LYNE_PCI_IDS="$FIXTURES/pci.ids"
}

# One line per GPU with the fields the tests compare, then the totals
detect() {
    in_lyne gpus -- '
        gpu_detect
        for ((i = 0; i < GPU_COUNT; i++)); do
            echo "$i ${GPU_PCI[i]} ${GPU_VENDOR[i]} ${GPU_KIND[i]} arch=${GPU_ARCH[i]} family=${GPU_FAMILY[i]} chip=${GPU_CHIP[i]} name=${GPU_NAME[i]}"
        done
        echo "count=$GPU_COUNT hybrid=$GPU_HYBRID internal=$GPU_INTERNAL nvidia=$GPU_NVIDIA"'
}

@test "hybrid laptop: integrated first, built-in screen on the Intel GPU" {
    fx_gpu "$SYS" 0000:01:00.0 10de:1f9d driver=nvidia card=card0 outputs="HDMI-A-1:connected"
    fx_gpu "$SYS" 0000:00:02.0 8086:3e9b driver=i915 card=card1 outputs="eDP-1:connected DP-1:disconnected" boot_vga=1
    run detect
    assert_success
    assert_line "0 0000:00:02.0 intel integrated arch= family= chip=CoffeeLake-H GT2 name=UHD Graphics 630"
    assert_line "1 0000:01:00.0 nvidia dedicated arch=turing family=open chip=TU117M name=GeForce GTX 1650 Mobile / Max-Q"
    assert_line "count=2 hybrid=1 internal=0 nvidia=1"
    run in_lyne gpus -- 'gpu_detect; gpu_summary; gpu_setup_label; gpu_connected 0; echo; gpu_kind_label 1'
    assert_line "Intel UHD Graphics 630 + NVIDIA GeForce GTX 1650 Mobile / Max-Q (hybrid)"
    assert_line "hybrid: the built-in screen is on the Intel GPU"
    assert_line "eDP-1"
    assert_line "dedicated, Turing"
}

@test "NVIDIA generations and driver branches, by chip and by id range" {
    local ids=(1004 13c2 1c03 2882 2f00 1e04 1345 0fc5)
    local i=1
    for id in "${ids[@]}"; do
        fx_gpu "$SYS" "0000:0$i:00.0" "10de:$id"
        i=$((i + 1))
    done
    run in_lyne gpus -- 'gpu_detect; for ((i = 0; i < GPU_COUNT; i++)); do echo "${GPU_IDS[i]} ${GPU_ARCH[i]} ${GPU_FAMILY[i]}"; done'
    assert_success
    assert_line "10de:1004 kepler 470xx"
    assert_line "10de:13c2 maxwell 580xx"
    assert_line "10de:1c03 pascal 580xx"
    assert_line "10de:2882 ada open"
    # Not in the excerpt: the id ranges decide
    assert_line "10de:2f00 blackwell open"
    assert_line "10de:1e04 turing open"
    assert_line "10de:1345 maxwell 580xx"
    assert_line "10de:0fc5 kepler 470xx"
}

@test "Intel Arc: dedicated cards by id, Meteor Lake's Arc stays integrated" {
    fx_gpu "$SYS" 0000:00:02.0 8086:7d55
    fx_gpu "$SYS" 0000:03:00.0 8086:56a0
    run detect
    assert_line "0 0000:00:02.0 intel integrated arch= family= chip=Meteor Lake-P name=Intel Arc Graphics"
    assert_line "1 0000:03:00.0 intel dedicated arch= family= chip=DG2 name=Arc A770"
    assert_line "count=2 hybrid=1 internal=-1 nvidia=-1"
}

@test "AMD: APUs by codename, unknown ids by their video memory" {
    fx_gpu "$SYS" 0000:05:00.0 1002:15bf
    fx_gpu "$SYS" 0000:06:00.0 1002:1638
    fx_gpu "$SYS" 0000:03:00.0 1002:73ff
    fx_gpu "$SYS" 0000:07:00.0 1002:9999 vram=536870912
    fx_gpu "$SYS" 0000:08:00.0 1002:9998 vram=8589934592
    run in_lyne gpus -- 'gpu_detect; for ((i = 0; i < GPU_COUNT; i++)); do echo "${GPU_IDS[i]} ${GPU_KIND[i]} ${GPU_NAME[i]}"; done'
    assert_line "1002:15bf integrated Phoenix1"
    assert_line "1002:1638 integrated Radeon Vega Series / Radeon Vega Mobile Series"
    assert_line "1002:73ff dedicated Radeon RX 6600/6600 XT/6600M"
    assert_line "1002:9999 integrated GPU 1002:9999"
    assert_line "1002:9998 dedicated GPU 1002:9998"
    # Integrated first even at a higher PCI address than the dedicated card
    assert_line --index 0 "1002:15bf integrated Phoenix1"
    assert_line --index 3 "1002:73ff dedicated Radeon RX 6600/6600 XT/6600M"
}

@test "virtual GPUs go last, unknown vendors are dedicated, other PCI classes are ignored" {
    fx_gpu "$SYS" 0000:00:01.0 1af4:1050
    fx_gpu "$SYS" 0000:02:00.0 1a03:2000 class=0x038000
    fx_gpu "$SYS" 0000:00:1f.3 8086:a348 class=0x040300
    run in_lyne gpus -- 'gpu_detect; for ((i = 0; i < GPU_COUNT; i++)); do echo "${GPU_BRAND[i]}|${GPU_KIND[i]}|${GPU_NAME[i]}"; done; echo "count=$GPU_COUNT hybrid=$GPU_HYBRID"'
    assert_line --index 0 "PCI 1a03|dedicated|ASPEED Graphics Family"
    assert_line --index 1 "Virtual|virtual|Virtio 1.0 GPU"
    assert_line "count=2 hybrid=0"
}

@test "built-in screen: a connected panel wins, else any panel listed" {
    fx_gpu "$SYS" 0000:00:02.0 8086:3e9b card=card0 outputs="eDP-1:disconnected"
    fx_gpu "$SYS" 0000:01:00.0 10de:1f9d card=card1 outputs="eDP-2:connected"
    run detect
    assert_line "count=2 hybrid=1 internal=1 nvidia=1"
    rm -rf "$SYS"
    fx_gpu "$SYS" 0000:00:02.0 8086:3e9b card=card0 outputs="DP-1:connected"
    fx_gpu "$SYS" 0000:01:00.0 10de:1f9d card=card1 outputs="LVDS-1:disconnected"
    run detect
    assert_line "count=2 hybrid=1 internal=1 nvidia=1"
}

@test "without pci.ids: placeholder names, NVIDIA generation from the id" {
    export LYNE_PCI_IDS="$BATS_TEST_TMPDIR/none"
    fx_gpu "$SYS" 0000:01:00.0 10de:1f9d
    run detect
    assert_success
    assert_line "0 0000:01:00.0 nvidia dedicated arch=turing family=open chip= name=GPU 10de:1f9d"
}

@test "no GPU at all" {
    mkdir -p "$SYS/bus/pci/devices"
    run in_lyne gpus -- 'gpu_detect; gpu_setup_label; gpu_summary; gpu_json'
    assert_success
    assert_line "no graphics card found"
    assert_line "none found"
    assert_line '{"hybrid":false,"internal":-1,"gpus":[]}'
}

@test "gpu_json is valid JSON with every field" {
    fx_gpu "$SYS" 0000:01:00.0 10de:1f9d driver=nvidia card=card0 outputs="HDMI-A-1:connected DP-1:disconnected" boot_vga=1
    fx_gpu "$SYS" 0000:00:02.0 8086:3e9b driver=i915 card=card1 outputs="eDP-1:connected"
    run in_lyne gpus -- 'gpu_detect; gpu_json'
    assert_success
    run jq -c '[.hybrid, .internal, (.gpus | length), .gpus[1].name, .gpus[1].family, .gpus[1].bootVga, .gpus[1].outputs]' <<<"$output"
    assert_output '[true,0,2,"GeForce GTX 1650 Mobile / Max-Q","open",true,[{"name":"DP-1","connected":false},{"name":"HDMI-A-1","connected":true}]]'
}

@test "gpu_status lists the outputs and the driver note" {
    fx_gpu "$SYS" 0000:01:00.0 10de:1c03 driver=nouveau card=card0 outputs="DP-1:connected HDMI-A-1:disconnected"
    run in_lyne gpus -- 'gpu_detect; gpu_status'
    assert_success
    assert_line "Graphics: one GPU"
    assert_line --partial "dedicated, Pascal (GP106) · 0000:01:00.0 · 10de:1c03 · driver nouveau · card0"
    assert_line "     outputs: DP-1 (on) HDMI-A-1"
    assert_line "     needs the legacy nvidia-580xx-dkms from the AUR (Maxwell to Volta)"
}

@test "runs on this machine's sysfs" {
    [[ -d /sys/bus/pci/devices ]] || skip "no /sys/bus/pci"
    unset LYNE_SYSFS LYNE_PCI_IDS
    run in_lyne gpus -- 'gpu_detect; gpu_json'
    assert_success
    jq -e '.gpus | type == "array"' <<<"$output"
}
