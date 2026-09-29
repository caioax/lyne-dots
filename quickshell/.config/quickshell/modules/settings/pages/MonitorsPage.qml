pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"
import "../../../services/monitors.js" as Lib

// Resolution, refresh rate, scale, rotation and position of each connected
// monitor (MonitorsService). Changes are a draft until Apply, which tries
// them live and asks to keep them; ~/.config/hypr/monitors.lua is only
// rewritten when kept.
ColumnLayout {
    id: root

    spacing: Config.spacing * 3

    // The rules as Hyprland shows them now, and the edited copy
    property var base: []
    property var draft: []
    property int selected: 0
    // Monitors (by port) the draft was built for: a hotplug starts over
    property string _ports: ""

    readonly property var monitors: MonitorsService.monitors
    readonly property var lidOff: MonitorsService.lidOffNames
    readonly property var layoutRects: Lib.rects(draft, monitors, lidOff)
    readonly property var changed: draft.filter((r, i) => JSON.stringify(r) !== JSON.stringify(base[i]))
    readonly property bool dirty: changed.length > 0
    readonly property string problem: MonitorsService.problemWith(draft)
    readonly property bool trial: MonitorsService.trialActive

    readonly property var rule: draft[selected] ?? null
    readonly property var monitor: rule ? monitors.find(m => m.name === rule.name) ?? null : null
    readonly property bool ruleLidOff: rule !== null && lidOff.includes(rule.name)
    // On and editable (not turned off, not kept off by the lid)
    readonly property bool ruleOn: rule !== null && !rule.disabled && !ruleLidOff
    // Showing another monitor's picture: no place, scale or rotation of its own
    readonly property bool ruleMirrors: ruleOn && !!rule.mirror
    readonly property var mirrorers: rule ? Lib.mirroredBy(draft, selected) : []
    readonly property var mode: rule ? Lib.pixelSize(rule, monitor) : ({ width: 0, height: 0 })
    readonly property var modeList: monitor ? Lib.modes(monitor) : []
    // The monitor's preferred mode: the first one it reports
    readonly property var nativeMode: monitor ? Lib.parseMode((monitor.availableModes ?? [])[0]) : null
    readonly property var scaleNow: rule && typeof rule.scale === "number" ? rule.scale : (monitor?.scale ?? 1)

    function reset() {
        base = MonitorsService.currentRules();
        draft = JSON.parse(JSON.stringify(base));
        _ports = monitors.map(m => m.name).join(" ");
        if (selected >= draft.length || selected < 0)
            selected = 0;
        // Start on a monitor that's on the map
        if (layoutRects[selected] === null) {
            const onMap = layoutRects.findIndex(r => r !== null);
            if (onMap >= 0)
                selected = onMap;
        }
    }

    function setRule(index: int, changes) {
        const copy = draft.slice();
        copy[index] = Object.assign({}, draft[index], changes);
        draft = copy;
    }

    // Positions from a list of rects (null ones untouched), started at 0,0
    function placeAll(list) {
        const fixed = Lib.normalized(list);
        draft = draft.map((r, i) => fixed[i] ? Object.assign({}, r, {
            position: fixed[i].x + "x" + fixed[i].y
        }) : r);
    }

    // A change of size (mode, scale, rotation): neighbours keep touching
    function resize(index: int, changes) {
        const before = layoutRects;
        setRule(index, changes);
        const after = Lib.rects(draft, monitors, lidOff);
        if (before[index] && after[index])
            placeAll(Lib.resized(before, index, after[index].width, after[index].height));
    }

    function setEnabled(index: int, on: bool) {
        if (on) {
            const spot = Lib.placeRight(layoutRects);
            setRule(index, {
                disabled: false,
                position: spot.x + "x" + spot.y
            });
        } else {
            setRule(index, {
                disabled: true
            });
            // Monitors mirroring it would show nothing: they get their own
            // picture back, right of the others
            for (const i of Lib.mirroredBy(draft, index))
                setMirror(i, -1);
        }
        placeAll(Lib.rects(draft, monitors, lidOff));
    }

    // Monitor `index` shows the picture of monitor `target` (-1: its own)
    function setMirror(index: int, target: int) {
        if (target >= 0) {
            setRule(index, {
                mirror: draft[target].output
            });
        } else {
            const spot = Lib.placeRight(Lib.rects(draft, monitors, lidOff));
            setRule(index, {
                mirror: "",
                position: spot.x + "x" + spot.y
            });
        }
        placeAll(Lib.rects(draft, monitors, lidOff));
    }

    // Puts rules from another file (the old monitors.lua) into the draft:
    // each connected monitor takes the rule written for it, if any
    function loadRules(rules) {
        const next = draft.map(d => {
            const m = monitors.find(x => x.name === d.name);
            const found = m ? Lib.ruleFor(rules, m, monitors) : null;
            if (!found)
                return d;
            const r = Object.assign({}, d, found, {
                output: d.output,
                name: d.name,
                label: d.label
            });
            // nwg-displays mirrors by port: by the monitor's own selector here
            const target = r.mirror ? draft.find(x => x.name === r.mirror || x.output === r.mirror) : null;
            r.mirror = target ? target.output : "";
            return r;
        });
        draft = next;
        placeAll(Lib.rects(draft, monitors, lidOff));
    }

    function labelOf(output: string): string {
        const r = draft.find(x => x.output === output);
        return r ? (r.label || r.name) : output;
    }

    function setMode(width: int, height: int, refresh: real) {
        const changes = {
            mode: Lib.modeString(width, height, refresh)
        };
        // Keep a scale Hyprland accepts at the new size
        if (!Lib.scaleValid(width, height, scaleNow))
            changes.scale = Lib.nearestScale(width, height, scaleNow);
        resize(selected, changes);
    }

    function describe(r): string {
        if (!r)
            return "";
        if (lidOff.includes(r.name))
            return "Off (lid closed)";
        if (r.disabled)
            return "Off";
        if (r.mirror)
            return "Mirroring " + labelOf(r.mirror);
        const m = monitors.find(x => x.name === r.name);
        const px = Lib.pixelSize(r, m);
        const hz = Lib.parseMode(r.mode)?.refresh ?? 0;
        return px.width + "×" + px.height + (hz > 0 ? " · " + Math.round(hz) + " Hz" : "");
    }

    Component.onCompleted: {
        MonitorsService.refresh();
        if (MonitorsService.ready)
            reset();
    }

    Connections {
        target: MonitorsService

        function onMonitorsChanged() {
            // Keep an edit in progress unless the monitors themselves changed
            if (!root.dirty || root.monitors.map(m => m.name).join(" ") !== root._ports)
                root.reset();
        }
    }

    HyprlandErrorGroup {}

    SettingsGroup {
        title: "Layout"

        SettingRow {
            visible: MonitorsService.ready && root.draft.length === 0
            label: "No monitors"
            description: "Hyprland doesn't list any connected monitor"
        }

        // The map, as a full-width row
        Rectangle {
            readonly property bool isSettingRow: true
            property bool first: true
            property bool last: true

            visible: root.draft.length > 0
            Layout.fillWidth: true
            implicitHeight: mapColumn.implicitHeight + Config.padding * 4
            color: Config.cardColor
            topLeftRadius: first ? Config.radiusLarge : Config.radiusSmall
            topRightRadius: first ? Config.radiusLarge : Config.radiusSmall
            bottomLeftRadius: last ? Config.radiusLarge : Config.radiusSmall
            bottomRightRadius: last ? Config.radiusLarge : Config.radiusSmall

            ColumnLayout {
                id: mapColumn

                anchors.fill: parent
                anchors.margins: Config.padding * 2
                spacing: Config.spacing * 2

                MonitorMap {
                    id: map

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(Config.fontSizeNormal * 16, width * 0.45)
                    rects: root.layoutRects
                    infos: root.draft.map((r, i) => ({
                                number: i + 1,
                                label: r.label || r.name,
                                detail: root.describe(r),
                                internal: Lib.isInternal(r.name)
                            }))
                    selected: root.selected
                    interactive: !root.trial && !MonitorsService.busy
                    onPicked: index => root.selected = index
                    onMoved: (index, x, y) => {
                        const list = root.layoutRects.slice();
                        list[index] = Object.assign({}, list[index], {
                            x: x,
                            y: y
                        });
                        root.placeAll(list);
                    }
                }

                // Every monitor, when some aren't on the map (off, mirroring)
                Flow {
                    Layout.fillWidth: true
                    visible: root.layoutRects.some(r => r === null)
                    spacing: Config.spacing

                    Repeater {
                        model: root.draft

                        ActionButton {
                            required property var modelData
                            required property int index

                            readonly property bool isSelected: root.selected === index

                            // md-laptop / md-monitor / md-monitor_off
                            icon: root.layoutRects[index] === null ? "\u{f0d90}" : Lib.isInternal(modelData.name) ? "\u{f0322}" : "\u{f0379}"
                            text: (index + 1) + "  " + (modelData.label || modelData.name) + " · " + root.describe(modelData)
                            size: Config.fontSizeIconSmall + Config.padding * 2
                            baseColor: isSelected ? Qt.alpha(Config.accentColor, 0.2) : Config.surface1Color
                            hoverColor: isSelected ? Qt.alpha(Config.accentColor, 0.3) : Config.surface2Color
                            textColor: isSelected ? Config.accentColor : Config.textColor
                            onClicked: root.selected = index
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacing * 2

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: {
                            const r = root.layoutRects[root.selected];
                            const where = r ? "At " + r.x + ", " + r.y + " · " : "";
                            const apart = r && !Lib.touches(root.layoutRects, root.selected) ? "Not touching another monitor: the pointer can't move between them · " : "";
                            return where + apart + "Drag to arrange; arrow keys move the selected one (Shift: 10× further)";
                        }
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: root.layoutRects[root.selected] && !Lib.touches(root.layoutRects, root.selected) ? Config.warningColor : Config.subtextColor
                    }

                    // md-numeric (which screen is which)
                    ActionButton {
                        Layout.alignment: Qt.AlignTop
                        icon: "\u{f03a0}"
                        text: "Identify"
                        size: Config.fontSizeIconSmall + Config.padding * 2
                        baseColor: Config.surface1Color
                        onClicked: MonitorsService.identify()
                    }
                }
            }
        }

        // Draft → Apply; trial → Keep or Revert
        SettingRow {
            visible: root.dirty || root.trial
            label: root.trial ? "Keep these settings?" : root.changed.length === 1 ? "1 monitor changed" : root.changed.length + " monitors changed"
            description: root.trial ? "Going back to the previous ones in " + MonitorsService.trialRemaining + " s" : root.problem !== "" ? root.problem : "Tried right away: keep them within " + MonitorsService.trialSeconds + " seconds or they go back on their own"
            descriptionColor: !root.trial && root.problem !== "" ? Config.errorColor : Config.subtextColor

            ActionButton {
                text: root.trial ? "Revert" : "Discard"
                size: Config.fontSizeIconSmall + Config.padding * 2
                baseColor: Config.surface1Color
                onClicked: root.trial ? MonitorsService.revert("") : root.reset()
            }

            ActionButton {
                text: root.trial ? "Keep" : "Apply"
                size: Config.fontSizeIconSmall + Config.padding * 2
                baseColor: Config.accentColor
                hoverColor: Qt.lighter(Config.accentColor, 1.15)
                textColor: Config.textReverseColor
                opacity: root.trial || (root.problem === "" && !MonitorsService.busy) ? 1 : 0.4
                onClicked: {
                    if (root.trial)
                        MonitorsService.keep();
                    else if (root.problem === "")
                        MonitorsService.apply(root.draft);
                }
            }
        }

        SettingRow {
            visible: MonitorsService.error !== ""
            label: "Hyprland rejected the change"
            description: MonitorsService.error
            descriptionColor: Config.errorColor
        }

        // Settings writes hypr/local/monitors.lua; the one in hypr/ is from
        // nwg-displays (or from before an update moved it)
        SettingRow {
            visible: MonitorsService.legacyText !== "" && MonitorsService.fileManaged
            label: "Old monitors.lua found"
            description: "~/.config/hypr/monitors.lua (nwg-displays writes there) isn't read anymore. Load its settings to try them, or remove it"

            ActionButton {
                text: "Load"
                size: Config.fontSizeIconSmall + Config.padding * 2
                baseColor: Config.surface1Color
                opacity: root.trial ? 0.4 : 1
                onClicked: {
                    if (!root.trial)
                        root.loadRules(MonitorsService.legacyRules);
                }
            }

            ActionButton {
                text: "Remove"
                size: Config.fontSizeIconSmall + Config.padding * 2
                baseColor: Config.surface1Color
                onClicked: MonitorsService.removeLegacy()
            }
        }

        SettingRow {
            visible: !MonitorsService.fileManaged && (MonitorsService.fileText !== "" || MonitorsService.legacyText !== "")
            // Saved here before migration 025 moved the file, or by nwg-displays
            readonly property bool oldPlace: Lib.isManaged(MonitorsService.legacyText)

            label: MonitorsService.fileText !== "" ? "local/monitors.lua was written by hand" : oldPlace ? "monitors.lua is in the old place" : "Monitors set up by nwg-displays"
            description: MonitorsService.fileText !== "" ? "Its settings show here, and the first Apply rewrites it" : oldPlace ? "lyne update moves ~/.config/hypr/monitors.lua to hypr/local/, and so does the next Apply here" : "Hyprland reads ~/.config/hypr/monitors.lua until the first Apply here, which saves the settings to hypr/local/monitors.lua"
        }
    }

    SettingsGroup {
        visible: root.rule !== null
        title: root.rule ? (root.rule.label || root.rule.name) + " · " + root.rule.name : ""
        enabled: !root.trial && !MonitorsService.busy

        ToggleRow {
            label: "Screen on"
            description: root.ruleLidOff ? "Off while the laptop lid is closed (Settings › Hyprland › Workspaces)" : "Off, its workspaces move to the other monitors"
            enabled: !root.ruleLidOff
            checked: root.rule ? !root.rule.disabled || root.ruleLidOff : false
            onToggled: value => root.setEnabled(root.selected, value)
        }

        SettingRow {
            id: mirrorRow

            readonly property var targets: root.rule ? Lib.mirrorTargets(root.draft, root.selected, root.lidOff) : []

            label: "Mirror"
            description: root.mirrorers.length > 0 ? "Mirrored by " + root.mirrorers.map(i => root.draft[i].label || root.draft[i].name).join(", ") + ", so it can't mirror another one" : root.ruleMirrors ? "Shows the picture of " + root.labelOf(root.rule.mirror) + "; its workspaces go to the other monitors meanwhile" : "Show another monitor's picture instead of its own"
            enabled: root.ruleOn && root.mirrorers.length === 0 && (targets.length > 0 || root.ruleMirrors)

            ActionButton {
                id: mirrorButton

                text: (root.ruleMirrors ? root.labelOf(root.rule.mirror) : "Off") + "  \u{f0140}"
                size: Config.fontSizeIconSmall + Config.padding * 2
                baseColor: mirrorRow.controlColor
                onClicked: {
                    const items = [
                        {
                            // md-check
                            label: "Off (its own picture)",
                            icon: root.ruleMirrors ? "" : "\u{f012c}",
                            action: "-1"
                        }
                    ];
                    for (const i of mirrorRow.targets)
                        items.push({
                            label: (i + 1) + "  " + (root.draft[i].label || root.draft[i].name),
                            icon: root.rule.mirror === root.draft[i].output ? "\u{f012c}" : "",
                            action: String(i)
                        });
                    menu.kind = "mirror";
                    menu.items = items;
                    menu.openAt(mirrorButton, null);
                }
            }
        }

        SettingRow {
            id: resolutionRow

            label: "Resolution"
            description: !root.nativeMode ? "" : root.nativeMode.width === root.mode.width && root.nativeMode.height === root.mode.height ? "The monitor's own (recommended)" : "The monitor's own is " + root.nativeMode.width + " × " + root.nativeMode.height
            enabled: root.rule !== null && !root.rule.disabled && !root.ruleLidOff && root.modeList.length > 0

            ActionButton {
                id: resolutionButton

                // md-chevron_down
                text: root.mode.width + " × " + root.mode.height + "  \u{f0140}"
                size: Config.fontSizeIconSmall + Config.padding * 2
                baseColor: resolutionRow.controlColor
                onClicked: {
                    const seen = {};
                    const items = [];
                    for (const m of root.modeList) {
                        const key = m.width + "x" + m.height;
                        if (seen[key])
                            continue;
                        seen[key] = true;
                        const current = m.width === root.mode.width && m.height === root.mode.height;
                        const own = root.nativeMode && m.width === root.nativeMode.width && m.height === root.nativeMode.height;
                        items.push({
                            // md-check
                            label: m.width + " × " + m.height + (own ? "  (recommended)" : ""),
                            icon: current ? "\u{f012c}" : "",
                            action: key
                        });
                    }
                    menu.kind = "resolution";
                    menu.items = items;
                    menu.openAt(resolutionButton, null);
                }
            }
        }

        SettingRow {
            id: refreshRow

            readonly property var rates: root.modeList.filter(m => m.width === root.mode.width && m.height === root.mode.height)
            readonly property real refresh: Lib.parseMode(root.rule?.mode)?.refresh ?? 0

            label: "Refresh rate"
            description: rates.length > 1 ? "Higher is smoother" : "The only one this resolution has"
            enabled: root.rule !== null && !root.rule.disabled && !root.ruleLidOff && rates.length > 0

            ActionButton {
                id: refreshButton

                text: Lib.formatRefresh(refreshRow.refresh) + " Hz  \u{f0140}"
                size: Config.fontSizeIconSmall + Config.padding * 2
                baseColor: refreshRow.controlColor
                onClicked: {
                    menu.kind = "refresh";
                    menu.items = refreshRow.rates.map(m => ({
                                label: Lib.formatRefresh(m.refresh) + " Hz",
                                icon: Math.abs(m.refresh - refreshRow.refresh) < 0.01 ? "\u{f012c}" : "",
                                action: String(m.refresh)
                            }));
                    menu.openAt(refreshButton, null);
                }
            }
        }

        SettingRow {
            id: scaleRow

            readonly property var looks: Lib.logicalSize(root.mode.width, root.mode.height, root.scaleNow, 0)

            label: "Scale"
            description: "Things look like on a " + looks.width + " × " + looks.height + " screen"
            enabled: root.ruleOn && !root.ruleMirrors

            ActionButton {
                id: scaleButton

                text: Lib.formatScale(root.scaleNow) + "×  \u{f0140}"
                size: Config.fontSizeIconSmall + Config.padding * 2
                baseColor: scaleRow.controlColor
                onClicked: {
                    const steps = Lib.scaleSteps(root.mode.width, root.mode.height);
                    const item = s => ({
                                label: Lib.formatScale(s) + "×  (" + Math.round(root.mode.width / s) + " × " + Math.round(root.mode.height / s) + ")",
                                icon: Math.abs(s - root.scaleNow) < 0.00001 ? "\u{f012c}" : "",
                                action: String(s)
                            });
                    const items = steps.map(item);
                    // Every other scale Hyprland accepts at this size
                    const others = Lib.validScales(root.mode.width, root.mode.height).filter(s => s >= 1 && s <= 3 && !steps.includes(s));
                    if (others.length > 0)
                        items.push({
                            label: "Other scales",
                            icon: steps.some(s => Math.abs(s - root.scaleNow) < 0.00001) ? "" : "\u{f012c}",
                            children: others.map(item)
                        });
                    menu.kind = "scale";
                    menu.items = items;
                    menu.openAt(scaleButton, null);
                }
            }
        }

        SelectRow {
            label: "Rotation"
            enabled: root.ruleOn && !root.ruleMirrors
            segmentWidth: Config.fontSizeNormal * 4
            options: [
                {
                    label: "0°",
                    value: 0
                },
                {
                    label: "90°",
                    value: 1
                },
                {
                    label: "180°",
                    value: 2
                },
                {
                    label: "270°",
                    value: 3
                }
            ]
            value: (root.rule?.transform ?? 0) % 4
            onSelected: value => root.resize(root.selected, {
                    transform: value + ((root.rule?.transform ?? 0) >= 4 ? 4 : 0)
                })
        }

        ToggleRow {
            label: "Flipped"
            description: "Mirror the picture horizontally, e.g. for a projector behind glass"
            enabled: root.ruleOn && !root.ruleMirrors
            checked: (root.rule?.transform ?? 0) >= 4
            onToggled: value => root.setRule(root.selected, {
                    transform: (root.rule.transform % 4) + (value ? 4 : 0)
                })
        }
    }

    ContextMenu {
        id: menu

        // Which control opened it: resolution | refresh | scale
        property string kind

        onTriggered: action => {
            if (kind === "resolution") {
                const [w, h] = action.split("x").map(Number);
                // Fastest rate of the new resolution
                const best = root.modeList.find(m => m.width === w && m.height === h);
                root.setMode(w, h, best ? best.refresh : 60);
            } else if (kind === "refresh") {
                root.setRule(root.selected, {
                    mode: Lib.modeString(root.mode.width, root.mode.height, Number(action))
                });
            } else if (kind === "mirror") {
                root.setMirror(root.selected, Number(action));
            } else if (kind === "scale") {
                root.resize(root.selected, {
                    scale: Number(action)
                });
            }
        }
    }
}
