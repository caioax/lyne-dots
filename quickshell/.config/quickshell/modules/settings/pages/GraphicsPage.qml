pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// The GPUs, which one renders Hyprland (AQ_DRM_DEVICES, through
// hypr/local/gpus.lua: applies at the next login), their udev links and the
// NVIDIA driver (GpuService, lyne gpu / lyne nvidia)
ColumnLayout {
    id: root

    spacing: Config.spacing * 3

    Component.onCompleted: GpuService.refresh()

    // Every GPU, with what the running session uses it for
    SettingsGroup {
        title: "GPUs"

        Repeater {
            model: GpuService.gpus

            SettingRow {
                id: gpuRow

                required property var modelData
                required property int index
                readonly property int runningIndex: GpuService.running.indexOf(modelData.pci)
                readonly property var outputs: GpuService.connected(modelData)

                label: GpuService.label(modelData)
                description: [GpuService.kindLabel(modelData), modelData.driver !== "" ? modelData.driver : "no driver", outputs.length > 0 ? outputs.join(", ") : "no monitor"].join(" · ")

                // md-laptop (the built-in screen's GPU) / md-expansion_card
                leading: Text {
                    text: GpuService.data.internal === gpuRow.index ? "\u{f0322}" : "\u{f08ae}"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIcon
                    color: gpuRow.runningIndex < 0 && GpuService.running.length > 0 ? Config.subtextColor : Config.textColor
                }

                Text {
                    visible: GpuService.multi && GpuService.running.length > 0
                    text: gpuRow.runningIndex === 0 ? "Renders now" : gpuRow.runningIndex > 0 ? "In use" : "Not in use"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: gpuRow.runningIndex === 0
                    color: gpuRow.runningIndex === 0 ? Config.accentColor : Config.subtextColor
                }
            }
        }

        SettingRow {
            label: "Detect again"
            description: GpuService.loaded && GpuService.gpus.length === 0 ? "No graphics card found" : "Reads the GPUs, links and driver again (after installing a driver or changing GPUs)"

            // md-refresh
            ActionButton {
                icon: "\u{f0450}"
                text: GpuService.loading ? "Reading…" : "Detect"
                opacity: GpuService.loading ? 0.6 : 1
                onClicked: GpuService.refresh()
            }
        }
    }

    // Hybrid machines: which kind renders, and the other one kept in use
    SettingsGroup {
        title: "Rendering"
        visible: GpuService.multi && GpuService.igpu !== null && GpuService.dgpu !== null

        SelectRow {
            label: "Renders the desktop"
            description: GpuService.renderer === "igpu" ? "Uses less power: recommended for laptops" : GpuService.renderer === "dgpu" ? "Faster, and monitors plugged into it need no copy between GPUs" : "Hyprland picks: the GPU of the built-in screen"
            segmentWidth: Config.fontSizeNormal * 8
            value: GpuService.renderer
            options: [
                {
                    label: GpuService.igpu?.brand ?? "Integrated",
                    icon: "\u{f0322}",
                    value: "igpu"
                },
                {
                    label: GpuService.dgpu?.brand ?? "Dedicated",
                    icon: "\u{f08ae}",
                    value: "dgpu"
                },
                {
                    label: "Automatic",
                    icon: "\u{f0068}",
                    value: "auto"
                }
            ]
            onSelected: value => GpuService.setPreset(value, GpuService.useOther)
        }

        ToggleRow {
            readonly property var other: GpuService.renderer === "igpu" ? GpuService.dgpu : GpuService.igpu

            label: "Use the other GPU"
            enabled: GpuService.renderer !== "auto"
            checked: GpuService.useOther
            description: GpuService.renderer === "auto" ? "Automatic uses every GPU" : checked ? "Monitors plugged into the " + (other?.brand ?? "other") + " GPU keep working" : GpuService.darkened.length > 0 ? GpuService.connected(GpuService.darkened[0]).join(", ") + " is plugged into the " + GpuService.darkened[0].brand + " GPU and goes dark" : "Only one GPU: monitors plugged into the " + (other?.brand ?? "other") + " one stay dark"
            descriptionColor: GpuService.darkened.length > 0 ? Config.warningColor : Config.subtextColor
            onToggled: value => GpuService.setPreset(GpuService.renderer, value)
        }

        NextLoginRow {}
    }

    // More than one GPU without an integrated one: an ordered list
    SettingsGroup {
        title: "Order"
        visible: GpuService.multi && (GpuService.igpu === null || GpuService.dgpu === null)

        ToggleRow {
            label: "Automatic"
            description: checked ? "Hyprland picks the order" : "The first GPU below renders; switched-off ones aren't used"
            checked: GpuService.savedOrder.length === 0
            onToggled: value => GpuService.setOrder(value ? [] : GpuService.listOrder)
        }

        Repeater {
            model: GpuService.listOrder

            SettingRow {
                id: orderRow

                required property string modelData
                required property int index
                readonly property var gpu: GpuService.gpuAt(modelData)
                readonly property bool used: GpuService.savedOrder.includes(modelData)
                readonly property bool auto: GpuService.savedOrder.length === 0

                label: (index + 1) + ". " + GpuService.label(gpu)
                description: auto ? "/dev/dri/" + gpu?.link : !used ? "Not used" + (GpuService.connected(gpu).length > 0 ? ": " + GpuService.connected(gpu).join(", ") + " goes dark" : "") : GpuService.savedOrder[0] === modelData ? "Renders" : "Also used"
                descriptionColor: !auto && !used && GpuService.connected(gpu).length > 0 ? Config.warningColor : Config.subtextColor
                enabled: !auto

                // md-chevron_up (only GPUs in use have a place in the order)
                ActionButton {
                    visible: orderRow.used
                    size: Config.fontSizeIconSmall + Config.padding * 3
                    icon: "\u{f0143}"
                    baseColor: orderRow.controlColor
                    enabled: orderRow.index > 0
                    opacity: enabled ? 1 : 0.4
                    onClicked: GpuService.move(orderRow.modelData, -1)
                }

                // md-chevron_down
                ActionButton {
                    visible: orderRow.used
                    size: Config.fontSizeIconSmall + Config.padding * 3
                    icon: "\u{f0140}"
                    baseColor: orderRow.controlColor
                    enabled: orderRow.index < GpuService.savedOrder.length - 1
                    opacity: enabled ? 1 : 0.4
                    onClicked: GpuService.move(orderRow.modelData, 1)
                }

                QsSwitch {
                    checked: orderRow.used || orderRow.auto
                    onToggled: {
                        GpuService.setUsed(orderRow.modelData, checked);
                        checked = Qt.binding(() => orderRow.used || orderRow.auto);
                    }
                }
            }
        }

        NextLoginRow {}
    }

    // The /dev/dri names the order uses, from udev rules by PCI address
    SettingsGroup {
        title: "Links"
        visible: GpuService.multi

        SettingRow {
            label: "GPU links"
            description: {
                const links = GpuService.linked.map(g => "/dev/dri/" + g.link).join(", ");
                switch (GpuService.rules) {
                case "missing":
                    return "Not set up: the order can't apply without " + links;
                case "changed":
                    return "The GPUs changed since " + GpuService.data.rulesPath + " was written";
                }
                if (!GpuService.linksReady)
                    return links + ": not all there yet (they appear once udev reloads, or after a reboot)";
                if (GpuService.duplicates.length > 0)
                    return links + ". " + GpuService.duplicates.join(", ") + " makes the same links";
                return links + ", by PCI address (" + GpuService.data.rulesPath + ")";
            }
            descriptionColor: GpuService.linksReady && GpuService.duplicates.length === 0 ? Config.subtextColor : Config.warningColor

            // md-link_variant
            ActionButton {
                visible: !GpuService.linksReady || GpuService.duplicates.length > 0
                icon: "\u{f0339}"
                text: GpuService.rules === "missing" ? "Set up" : "Update"
                onClicked: GpuService.inTerminal("lyne gpu links")
            }
        }

        SettingRow {
            visible: GpuService.otherAq.length > 0
            label: "Also set by hand"
            description: GpuService.otherAq.join(", ") + " sets AQ_DRM_DEVICES too: remove that line so the order here applies"
            descriptionColor: Config.warningColor
        }
    }

    // What lyne nvidia status says
    SettingsGroup {
        title: "NVIDIA driver"
        visible: GpuService.nvidia !== null

        SettingRow {
            readonly property var nv: GpuService.nvidia

            label: "Driver"
            description: {
                if (!nv)
                    return "";
                if (nv.action === "unsupported")
                    return GpuService.label(GpuService.gpus[nv.gpu]) + ": " + nv.note;
                if (nv.current === "")
                    return "Not installed: " + nv.note;
                const loaded = nv.loaded !== "" ? "loaded " + nv.loaded : "not loaded (reboot)";
                return nv.current + " " + nv.version + " · " + loaded + (nv.action === "replace" ? " · doesn't support this GPU anymore" : "");
            }
            descriptionColor: nv && (nv.action === "install" || nv.action === "replace") ? Config.warningColor : Config.subtextColor

            // md-download / md-wrench
            ActionButton {
                readonly property var nv: GpuService.nvidia

                visible: nv !== null && (nv.action === "install" || nv.action === "replace" || (nv.action === "ok" && nv.changes))
                icon: nv?.action === "ok" ? "\u{f05b7}" : "\u{f01da}"
                text: nv?.action === "install" ? "Install" : nv?.action === "replace" ? "Switch" : "Fix"
                onClicked: GpuService.inTerminal("lyne nvidia install")
            }
        }

        Repeater {
            model: GpuService.nvidia?.notes ?? []

            SettingRow {
                required property string modelData

                label: "Check"
                description: modelData
                descriptionColor: Config.warningColor
                resettable: false
            }
        }
    }

    // The saved order against the running one, with a way to apply it now
    component NextLoginRow: SettingRow {
        label: "Next login"
        description: GpuService.orderLabel(GpuService.savedOrder) + (GpuService.pending ? ". Now: " + GpuService.orderLabel(GpuService.runningExplicit ? GpuService.running : []) : "")
        descriptionColor: GpuService.pending ? Config.warningColor : Config.subtextColor

        // md-logout
        ActionButton {
            visible: GpuService.pending
            icon: "\u{f0343}"
            text: "Log out"
            onClicked: GpuService.logout()
        }
    }
}
