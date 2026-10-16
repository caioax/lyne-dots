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
                description: [GpuService.kindLabel(modelData), modelData.driver !== "" ? modelData.driver : I18n.tr("no driver"), outputs.length > 0 ? outputs.join(", ") : I18n.tr("no monitor")].join(" · ")

                // md-laptop (the built-in screen's GPU) / md-expansion_card
                leading: Text {
                    text: GpuService.data.internal === gpuRow.index ? "\u{f0322}" : "\u{f08ae}"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIcon
                    color: gpuRow.runningIndex < 0 && GpuService.running.length > 0 ? Config.subtextColor : Config.textColor
                }

                Text {
                    visible: GpuService.multi && GpuService.running.length > 0
                    text: gpuRow.runningIndex === 0 ? I18n.tr("Renders now") : gpuRow.runningIndex > 0 ? I18n.tr("In use") : I18n.tr("Not in use")
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: gpuRow.runningIndex === 0
                    color: gpuRow.runningIndex === 0 ? Config.accentColor : Config.subtextColor
                }
            }
        }

        SettingRow {
            label: I18n.tr("Detect again")
            description: GpuService.loaded && GpuService.gpus.length === 0 ? I18n.tr("No graphics card found") : I18n.tr("Reads the GPUs, links and driver again (after installing a driver or changing GPUs)")

            // md-refresh
            ActionButton {
                icon: "\u{f0450}"
                text: GpuService.loading ? I18n.tr("Reading…") : I18n.tr("Detect")
                opacity: GpuService.loading ? 0.6 : 1
                onClicked: GpuService.refresh()
            }
        }
    }

    // Hybrid machines: which kind renders, and the other one kept in use
    SettingsGroup {
        title: I18n.tr("Rendering")
        visible: GpuService.multi && GpuService.igpu !== null && GpuService.dgpu !== null

        SelectRow {
            label: I18n.tr("Renders the desktop")
            description: GpuService.renderer === "igpu" ? I18n.tr("Uses less power: recommended for laptops") : GpuService.renderer === "dgpu" ? I18n.tr("Faster, and monitors plugged into it need no copy between GPUs") : I18n.tr("Hyprland picks: the GPU of the built-in screen")
            segmentWidth: Config.fontSizeNormal * 8
            value: GpuService.renderer
            options: [
                {
                    label: GpuService.igpu?.brand ?? I18n.tr("Integrated"),
                    icon: "\u{f0322}",
                    value: "igpu"
                },
                {
                    label: GpuService.dgpu?.brand ?? I18n.tr("Dedicated"),
                    icon: "\u{f08ae}",
                    value: "dgpu"
                },
                {
                    label: I18n.tr("Automatic"),
                    icon: "\u{f0068}",
                    value: "auto"
                }
            ]
            onSelected: value => GpuService.setPreset(value, GpuService.useOther)
        }

        ToggleRow {
            readonly property var other: GpuService.renderer === "igpu" ? GpuService.dgpu : GpuService.igpu

            label: I18n.tr("Use the other GPU")
            enabled: GpuService.renderer !== "auto"
            checked: GpuService.useOther
            description: GpuService.renderer === "auto" ? I18n.tr("Automatic uses every GPU") : checked ? I18n.tr("Monitors plugged into the %1 GPU keep working", other?.brand ?? I18n.tr("other")) : GpuService.darkened.length > 0 ? I18n.tr("%1 is plugged into the %2 GPU and goes dark", GpuService.connected(GpuService.darkened[0]).join(", "), GpuService.darkened[0].brand) : I18n.tr("Only one GPU: monitors plugged into the %1 one stay dark", other?.brand ?? I18n.tr("other"))
            descriptionColor: GpuService.darkened.length > 0 ? Config.warningColor : Config.subtextColor
            onToggled: value => GpuService.setPreset(GpuService.renderer, value)
        }

        NextLoginRow {}
    }

    // More than one GPU without an integrated one: an ordered list
    SettingsGroup {
        title: I18n.tr("Order")
        visible: GpuService.multi && (GpuService.igpu === null || GpuService.dgpu === null)

        ToggleRow {
            label: I18n.tr("Automatic")
            description: checked ? I18n.tr("Hyprland picks the order") : I18n.tr("The first GPU below renders; switched-off ones aren't used")
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
                description: auto ? "/dev/dri/" + gpu?.link : !used ? (GpuService.connected(gpu).length > 0 ? I18n.tr("Not used: %1 goes dark", GpuService.connected(gpu).join(", ")) : I18n.tr("Not used")) : GpuService.savedOrder[0] === modelData ? I18n.tr("Renders") : I18n.tr("Also used")
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
        title: I18n.tr("Links")
        visible: GpuService.multi

        SettingRow {
            label: I18n.tr("GPU links")
            description: {
                const links = GpuService.linked.map(g => "/dev/dri/" + g.link).join(", ");
                switch (GpuService.rules) {
                case "missing":
                    return I18n.tr("Not set up: the order can't apply without %1", links);
                case "changed":
                    return I18n.tr("The GPUs changed since %1 was written", GpuService.data.rulesPath);
                }
                if (!GpuService.linksReady)
                    return I18n.tr("%1: not all there yet (they appear once udev reloads, or after a reboot)", links);
                if (GpuService.duplicates.length > 0)
                    return I18n.tr("%1. %2 makes the same links", links, GpuService.duplicates.join(", "));
                return I18n.tr("%1, by PCI address (%2)", links, GpuService.data.rulesPath);
            }
            descriptionColor: GpuService.linksReady && GpuService.duplicates.length === 0 ? Config.subtextColor : Config.warningColor

            // md-link_variant
            ActionButton {
                visible: !GpuService.linksReady || GpuService.duplicates.length > 0
                icon: "\u{f0339}"
                text: GpuService.rules === "missing" ? I18n.tr("Set up") : I18n.tr("Update")
                onClicked: GpuService.inTerminal("lyne gpu links")
            }
        }

        SettingRow {
            visible: GpuService.otherAq.length > 0
            label: I18n.tr("Also set by hand")
            description: I18n.tr("%1 sets AQ_DRM_DEVICES too: remove that line so the order here applies", GpuService.otherAq.join(", "))
            descriptionColor: Config.warningColor
        }
    }

    // What lyne nvidia status says
    SettingsGroup {
        title: I18n.tr("NVIDIA driver")
        visible: GpuService.nvidia !== null

        SettingRow {
            readonly property var nv: GpuService.nvidia

            label: I18n.tr("Driver")
            description: {
                if (!nv)
                    return "";
                if (nv.action === "unsupported")
                    return GpuService.label(GpuService.gpus[nv.gpu]) + ": " + nv.note;
                if (nv.current === "")
                    return I18n.tr("Not installed: %1", nv.note);
                const loaded = nv.loaded !== "" ? I18n.tr("loaded %1", nv.loaded) : I18n.tr("not loaded (reboot)");
                return [nv.current + " " + nv.version, loaded].concat(nv.action === "replace" ? [I18n.tr("doesn't support this GPU anymore")] : []).join(" · ");
            }
            descriptionColor: nv && (nv.action === "install" || nv.action === "replace") ? Config.warningColor : Config.subtextColor

            // md-download / md-wrench
            ActionButton {
                readonly property var nv: GpuService.nvidia

                visible: nv !== null && (nv.action === "install" || nv.action === "replace" || (nv.action === "ok" && nv.changes))
                icon: nv?.action === "ok" ? "\u{f05b7}" : "\u{f01da}"
                text: nv?.action === "install" ? I18n.tr("Install") : nv?.action === "replace" ? I18n.tr("Switch") : I18n.tr("Fix")
                onClicked: GpuService.inTerminal("lyne nvidia install")
            }
        }

        Repeater {
            model: GpuService.nvidia?.notes ?? []

            SettingRow {
                required property string modelData

                label: I18n.tr("Check")
                description: modelData
                descriptionColor: Config.warningColor
                resettable: false
            }
        }
    }

    // The saved order against the running one, with a way to apply it now
    component NextLoginRow: SettingRow {
        label: I18n.tr("Next login")
        description: GpuService.pending ? I18n.tr("%1. Now: %2", GpuService.orderLabel(GpuService.savedOrder), GpuService.orderLabel(GpuService.runningExplicit ? GpuService.running : [])) : GpuService.orderLabel(GpuService.savedOrder)
        descriptionColor: GpuService.pending ? Config.warningColor : Config.subtextColor

        // md-logout
        ActionButton {
            visible: GpuService.pending
            icon: "\u{f0343}"
            text: I18n.tr("Log out")
            onClicked: GpuService.logout()
        }
    }
}
