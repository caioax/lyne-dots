pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Widgets
import qs.config
import qs.services
import "../rows/"
import "../../../components/"
import "../../../services/ThemeGenerator.js" as ThemeGenerator

// New / edit theme view inside the Theme page. A few picks (accent, mode,
// mood), seeded from a color, a wallpaper or another theme, generate the
// whole theme (ThemeGenerator.js); single colors can then be set by hand.
// The mock desktop on the right follows the page while scrolling. Nothing
// touches the shell until it's saved
ColumnLayout {
    id: root

    // Custom theme being edited ("" for a new one)
    property string editSlug: ""
    // Theme whose colors a new one starts from (Duplicate)
    property string duplicateFrom: ""

    readonly property var swatches: ["#7aa2f7", "#89b4fa", "#b4befe", "#c678dd", "#f5a3c7", "#f7768e", "#962a1f", "#e0a153", "#e5c07b", "#9ece6a", "#50c8a0", "#7dcfff", "#888888"]
    readonly property var paletteKeys: [
        ["background", "Background"],
        ["surface0", "Panels"],
        ["surface1", "Cards"],
        ["surface2", "Hover and selection"],
        ["surface3", "Borders"],
        ["text", "Text"],
        ["subtext", "Secondary text"],
        ["muted", "Muted text"],
        ["textReverse", "Text on the accent"],
        ["subtextReverse", "Subtle lines"],
        ["accent", "Accent"],
        ["greyBlue", "Selected item"],
        ["success", "Success"],
        ["warning", "Warning"],
        ["error", "Error"],
        ["blueDark", "Deepest background"]
    ]
    readonly property var terminalKeys: [
        ["background", "Background"],
        ["foreground", "Text"],
        ["cursor", "Cursor"],
        ["selectionBackground", "Selection"],
        ["color0", "Black"],
        ["color1", "Red"],
        ["color2", "Green"],
        ["color3", "Yellow"],
        ["color4", "Blue"],
        ["color5", "Magenta"],
        ["color6", "Cyan"],
        ["color7", "White"],
        ["color8", "Bright black"],
        ["color9", "Bright red"],
        ["color10", "Bright green"],
        ["color11", "Bright yellow"],
        ["color12", "Bright blue"],
        ["color13", "Bright magenta"],
        ["color14", "Bright cyan"],
        ["color15", "Bright white"],
        ["color16", "Orange"],
        ["color17", "Dark red"]
    ]

    property string name: ""
    property var seed: ({
            scheme: ThemeService.colorScheme,
            accent: Config.accentColor.toString(),
            exactAccent: false,
            tint: 0.5,
            vibrance: 0.5,
            harmony: 0.15
        })
    // Colors set by hand: { palette: {}, terminal: {} }
    property var overrides: ({
            palette: {},
            terminal: {}
        })
    readonly property var generated: ThemeGenerator.generate(seed, overrides)
    readonly property var contrastChecks: ThemeGenerator.checks(generated)
    readonly property int failing: contrastChecks.filter(c => !c.ok).length
    readonly property int overrideCount: Object.keys(overrides.palette).length + Object.keys(overrides.terminal).length

    // "color" | "wallpaper" | "theme"
    property string source: "color"
    property string wallpaperPath: WallpaperService.currentWallpaper
    property bool pickingWallpaper: false
    property bool useWallpaper: true
    property var wallpaperColors: []
    property string sourceTheme: ""

    property bool fineTune: false
    property string fineTuneSection: "palette"
    property bool applyAfter: true
    property bool saving: false
    property string saveError: ""
    // Something was changed since opening: leaving asks for a second Escape
    property bool dirty: false
    property bool leaveArmed: false
    property bool _ready: false

    readonly property var editPreview: editSlug !== "" ? ThemeService.themePreviews[editSlug] ?? null : null
    readonly property string slug: editSlug !== "" ? editSlug : ThemeGenerator.slugify(name)
    readonly property string nameError: {
        if (name.trim() === "")
            return "Give it a name";
        if (slug === "")
            return "Use some letters or numbers";
        if (editSlug === "" && ThemeService.availableThemes.includes(slug))
            return "There's already a theme with this name";
        return "";
    }
    readonly property string mockWallpaper: {
        if (source === "wallpaper" && useWallpaper)
            return wallpaperPath;
        if (editPreview && editPreview.wallpaper)
            return ThemeService.wallpaperDir + "/" + editPreview.wallpaper;
        return "";
    }

    // SettingsWindow's page Flickable, for the sticky mock
    property Item flick: null

    signal back
    signal saved(string slug)

    // Called by the Theme page on Escape: true while it only arms the discard
    function confirmLeave(): bool {
        if (!dirty || leaveArmed)
            return false;
        leaveArmed = true;
        return true;
    }

    onGeneratedChanged: {
        if (_ready)
            dirty = true;
        leaveArmed = false;
    }
    onNameChanged: {
        if (_ready)
            dirty = true;
    }

    function setSeed(key: string, value) {
        const next = Object.assign({}, seed);
        next[key] = value;
        seed = next;
    }

    function setOverride(section: string, key: string, value) {
        const next = {
            palette: Object.assign({}, overrides.palette),
            terminal: Object.assign({}, overrides.terminal)
        };
        if (value === undefined)
            delete next[section][key];
        else
            next[section][key] = value;
        overrides = next;
    }

    function clearOverrides() {
        overrides = {
            palette: {},
            terminal: {}
        };
    }

    function startFromTheme(themeName: string, exact: bool) {
        const preview = ThemeService.themePreviews[themeName];
        if (!preview)
            return;
        sourceTheme = themeName;
        const s = ThemeGenerator.seedFromTheme(preview);
        delete s.overrides;
        delete s.name;
        seed = s;
        if (exact)
            overrides = {
                palette: Object.assign({}, preview.palette),
                terminal: Object.assign({}, preview.terminal)
            };
        else
            clearOverrides();
    }

    function fix(check) {
        setOverride(check.fixSection, check.fixKey, ThemeGenerator.fixFor(generated, check));
    }

    // One failing check at a time: a fix can change what the next one sees
    function fixAll() {
        for (let i = 0; i < 8; i++) {
            const failingCheck = ThemeGenerator.checks(generated).find(c => !c.ok);
            if (!failingCheck)
                return;
            fix(failingCheck);
        }
    }

    function readWallpaperColors() {
        wallpaperColors = [];
        if (wallpaperPath === "")
            return;
        // Our own extraction (small bright areas count) plus matugen's
        colorsProc.command = ["sh", "-c", "python3 \"$2\" \"$1\" 2>/dev/null; matugen image \"$1\" --show-source-colors 2>/dev/null | grep -oiE '#[0-9a-f]{6}'", "sh", wallpaperPath, Qt.resolvedUrl("../../../scripts/wallpaper-colors.py").toString().replace("file://", "")];
        colorsProc.running = true;
    }

    function save() {
        if (nameError !== "" || saving)
            return;
        const data = Object.assign({}, generated, {
            name: name.trim()
        });
        let wallpaperFrom = "";
        if (source === "wallpaper" && useWallpaper && wallpaperPath !== "") {
            data.wallpaper = "themes/" + slug + "/" + WallpaperService.fileName(wallpaperPath);
            wallpaperFrom = wallpaperPath;
        } else {
            data.wallpaper = editPreview?.wallpaper ?? "";
        }
        saveError = "";
        saving = true;
        ThemeService.saveTheme(slug, data, applyAfter, wallpaperFrom);
    }

    Component.onCompleted: {
        let item = root.parent;
        while (item && item.contentY === undefined)
            item = item.parent;
        flick = item;

        if (editSlug !== "" && editPreview) {
            name = editPreview.name ?? editSlug;
            const s = ThemeGenerator.seedFromTheme(editPreview);
            delete s.name;
            // Themes made here keep their hand-set colors; others are copied
            overrides = s.overrides ?? (editPreview.seed ? {
                    palette: {},
                    terminal: {}
                } : {
                    palette: Object.assign({}, editPreview.palette),
                    terminal: Object.assign({}, editPreview.terminal)
                });
            delete s.overrides;
            seed = s;
        } else if (duplicateFrom !== "") {
            const preview = ThemeService.themePreviews[duplicateFrom];
            name = (preview?.name ?? duplicateFrom) + " Copy";
            source = "theme";
            startFromTheme(duplicateFrom, true);
        }
        _ready = true;
    }

    onSourceChanged: {
        if (source === "wallpaper" && wallpaperColors.length === 0)
            readWallpaperColors();
    }
    onWallpaperPathChanged: {
        if (source === "wallpaper")
            readWallpaperColors();
    }

    Connections {
        target: ThemeService

        function onThemeSaved(slug) {
            if (!root.saving || slug !== root.slug)
                return;
            root.saving = false;
            root.dirty = false;
            root.saved(slug);
        }

        function onThemeSaveFailed(slug) {
            if (slug !== root.slug)
                return;
            root.saving = false;
            root.saveError = "Couldn't write the theme file";
        }
    }

    Process {
        id: colorsProc

        property var _found: []

        onStarted: _found = []
        stdout: SplitParser {
            onRead: data => {
                const hex = data.trim().toLowerCase();
                if (hex)
                    colorsProc._found.push(hex);
            }
        }
        // Most colorful first; near-black/white ones only when nothing else
        onExited: {
            const unique = [...new Set(_found)].map(hex => ({
                        hex: hex,
                        lch: ThemeGenerator.hexToOklch(hex)
                    }));
            const usable = unique.filter(c => c.lch.l > 0.3 && c.lch.l < 0.95);
            const ranked = (usable.length > 0 ? usable : unique).sort((a, b) => b.lch.c - a.lch.c);
            root.wallpaperColors = ranked.slice(0, 8).map(c => c.hex);
            // The best candidate becomes the accent right away
            if (root.wallpaperColors.length > 0)
                root.setSeed("accent", root.wallpaperColors[0]);
        }
    }

    spacing: Config.spacing * 3

    PageHeader {
        title: root.editSlug !== "" ? "Edit " + (root.editPreview?.name ?? root.editSlug) : "New theme"
        subtitle: "A few picks: the rest of the colors follow from them"
        icon: "\u{f03d8}"
        onBackClicked: root.back()

        ActionButton {
            icon: root.saving ? "" : "\u{f0193}"
            text: root.saving ? "Saving…" : "Save"
            baseColor: root.nameError === "" ? Config.accentColor : Config.surface1Color
            hoverColor: root.nameError === "" ? Qt.lighter(Config.accentColor, 1.1) : Config.surface2Color
            textColor: root.nameError === "" ? Config.textReverseColor : Config.subtextColor
            onClicked: root.save()
        }
    }

    Rectangle {
        visible: root.leaveArmed
        Layout.fillWidth: true
        implicitHeight: leaveText.implicitHeight + Config.padding * 2
        radius: Config.radius
        color: Qt.alpha(Config.warningColor, 0.15)

        Text {
            id: leaveText
            anchors.fill: parent
            anchors.margins: Config.padding
            anchors.leftMargin: Config.padding * 2
            verticalAlignment: Text.AlignVCenter
            text: "Unsaved changes: press Escape again to discard them"
            wrapMode: Text.WordWrap
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.warningColor
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing * 2

        // ================= CONTROLS =================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Config.spacing * 3

            SettingsGroup {
                title: "Name"

                SettingRow {
                    id: nameRow

                    label: root.editSlug !== "" ? "Name" : "Theme name"
                    description: root.nameError !== "" ? root.nameError : root.editSlug !== "" ? "Saved as " + root.slug + ".json" : "Saved as ~/.local/themes/" + root.slug + ".json"
                    descriptionColor: root.nameError !== "" && root.name !== "" ? Config.errorColor : Config.subtextColor

                    below: Rectangle {
                        width: parent.width
                        implicitHeight: Config.fontSizeIconSmall + Config.padding * 3
                        radius: Config.radius
                        color: nameRow.controlColor
                        border.width: nameInput.activeFocus ? 1 : 0
                        border.color: Qt.alpha(Config.accentColor, 0.6)

                        TextInput {
                            id: nameInput

                            anchors.fill: parent
                            anchors.leftMargin: Config.padding * 2
                            anchors.rightMargin: Config.padding * 2
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            text: root.name
                            maximumLength: 40
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            color: Config.textColor
                            selectionColor: Qt.alpha(Config.accentColor, 0.4)
                            onTextEdited: root.name = text
                            onAccepted: root.save()

                            Text {
                                visible: nameInput.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: "My theme"
                                font: nameInput.font
                                color: Config.subtextColor
                            }
                        }
                    }
                }
            }

            // ================= START FROM =================
            SettingsGroup {
                visible: root.editSlug === ""
                title: "Start from"

                SettingRow {
                    label: {
                        if (root.source === "wallpaper")
                            return "A wallpaper";
                        if (root.source === "theme")
                            return "Another theme";
                        return "A color";
                    }
                    description: {
                        if (root.source === "wallpaper")
                            return "Its main colors become accent choices";
                        if (root.source === "theme")
                            return "Its accent, mode and background tone";
                        return "Pick the accent; everything else follows";
                    }

                    below: SegmentedControl {
                        width: parent.width
                        options: [
                            {
                                label: "Color",
                                icon: "\u{f08b5}"
                            },
                            {
                                label: "Wallpaper",
                                icon: "\u{f02e9}"
                            },
                            {
                                label: "Theme",
                                icon: "\u{f03d8}"
                            }
                        ]
                        currentIndex: ["color", "wallpaper", "theme"].indexOf(root.source)
                        onSelected: index => root.source = ["color", "wallpaper", "theme"][index]
                    }
                }

                // Color: curated accents
                SettingRow {
                    visible: root.source === "color"
                    label: "Accent"
                    description: "Or type any color in Colors › Accent"

                    below: Flow {
                        width: parent.width
                        spacing: Config.padding

                        Repeater {
                            model: root.swatches

                            Swatch {
                                required property string modelData
                                hex: modelData
                            }
                        }
                    }
                }

                // Wallpaper: which one, and its colors
                SettingRow {
                    id: wallRow

                    visible: root.source === "wallpaper"
                    label: root.wallpaperPath !== "" ? WallpaperService.fileName(root.wallpaperPath) : "No wallpaper"
                    description: root.wallpaperColors.length > 0 ? "Pick the accent from its colors" : "Reading its colors…"

                    leading: ClippingRectangle {
                        implicitWidth: Math.round(Config.fontSizeIconLarge * 2 * 16 / 9)
                        implicitHeight: Config.fontSizeIconLarge * 2
                        radius: Config.radius
                        color: Config.surface1Color

                        Image {
                            anchors.fill: parent
                            source: root.wallpaperPath !== "" ? "file://" + root.wallpaperPath : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(width * 2, height * 2)
                            asynchronous: true
                        }
                    }

                    ActionButton {
                        icon: root.pickingWallpaper ? "\u{f0156}" : "\u{f0977}"
                        text: root.pickingWallpaper ? "Close" : "Change"
                        baseColor: wallRow.controlColor
                        onClicked: root.pickingWallpaper = !root.pickingWallpaper
                    }

                    below: ColumnLayout {
                        width: parent.width
                        spacing: Config.spacing

                        Flow {
                            Layout.fillWidth: true
                            spacing: Config.padding

                            Repeater {
                                model: root.wallpaperColors

                                Swatch {
                                    required property string modelData
                                    hex: modelData
                                }
                            }
                        }

                        // Library picker
                        GridLayout {
                            id: wallGrid

                            readonly property real cell: (width - columnSpacing * 3) / 4

                            visible: root.pickingWallpaper
                            Layout.fillWidth: true
                            columns: 4
                            columnSpacing: Config.padding
                            rowSpacing: Config.padding

                            Repeater {
                                model: root.pickingWallpaper ? WallpaperService.wallpapers : []

                                ClippingRectangle {
                                    id: thumb

                                    required property string modelData

                                    Layout.preferredWidth: wallGrid.cell
                                    Layout.preferredHeight: Math.round(wallGrid.cell * 9 / 16)
                                    radius: Config.radius
                                    color: Config.surface1Color
                                    border.width: modelData === root.wallpaperPath ? 2 : 0
                                    border.color: Config.accentColor

                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + thumb.modelData
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize: Qt.size(width * 2, height * 2)
                                        asynchronous: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.wallpaperPath = thumb.modelData;
                                            root.pickingWallpaper = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ToggleRow {
                    visible: root.source === "wallpaper"
                    label: "Use it as the theme's wallpaper"
                    description: "Copied to the theme's wallpapers"
                    checked: root.useWallpaper
                    onToggled: value => root.useWallpaper = value
                }

                // Theme: which one
                SettingRow {
                    visible: root.source === "theme"
                    label: root.sourceTheme !== "" ? (ThemeService.themePreviews[root.sourceTheme]?.name ?? root.sourceTheme) : "Pick a theme"
                    description: root.sourceTheme !== "" && root.overrideCount > 0 ? "Its exact colors are copied: change them in Fine-tune" : "The generator recreates its look; copy its colors to keep them exactly"

                    ActionButton {
                        visible: root.sourceTheme !== ""
                        icon: "\u{f018f}"
                        text: "Copy its colors"
                        onClicked: root.startFromTheme(root.sourceTheme, true)
                    }

                    below: Flow {
                        width: parent.width
                        spacing: Config.padding

                        Repeater {
                            model: ThemeService.availableThemes

                            Rectangle {
                                id: chip

                                required property string modelData
                                readonly property bool active: modelData === root.sourceTheme
                                readonly property var pal: ThemeService.themePreviews[modelData]?.palette ?? {}

                                width: chipRow.implicitWidth + Config.padding * 3
                                height: chipRow.implicitHeight + Config.padding * 1.5
                                radius: height / 2
                                color: active ? Qt.alpha(Config.accentColor, 0.2) : chipMouse.containsMouse ? Config.surface2Color : Config.surface1Color
                                border.width: active ? 1 : 0
                                border.color: Config.accentColor

                                RowLayout {
                                    id: chipRow

                                    anchors.centerIn: parent
                                    spacing: Config.padding

                                    PaletteDots {
                                        colors: [chip.pal.background, chip.pal.accent]
                                    }

                                    Text {
                                        text: ThemeService.themePreviews[chip.modelData]?.name ?? chip.modelData
                                        font.family: Config.font
                                        font.pixelSize: Config.fontSizeSmall
                                        color: Config.textColor
                                    }
                                }

                                MouseArea {
                                    id: chipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.startFromTheme(chip.modelData, false)
                                }
                            }
                        }
                    }
                }
            }

            // ================= COLORS =================
            SettingsGroup {
                title: "Colors"

                ColorEditRow {
                    label: "Accent"
                    description: "Buttons, highlights and the active window border"
                    value: root.seed.accent
                    onEdited: value => root.setSeed("accent", value)
                }

                SelectRow {
                    label: "Mode"
                    options: [
                        {
                            label: "Dark",
                            icon: "\u{f0594}",
                            value: "dark"
                        },
                        {
                            label: "Light",
                            icon: "\u{f05a8}",
                            value: "light"
                        }
                    ]
                    value: root.seed.scheme
                    onSelected: value => root.setSeed("scheme", value)
                }

                ToggleRow {
                    label: "Keep the exact accent"
                    description: "Off: its brightness is adjusted to stay readable"
                    checked: root.seed.exactAccent
                    onToggled: value => root.setSeed("exactAccent", value)
                }
            }

            // ================= MOOD =================
            SettingsGroup {
                title: "Mood"

                SliderRow {
                    label: "Background tint"
                    description: "How much the backgrounds take the accent's hue"
                    value: root.seed.tint
                    stepSize: 0.05
                    format: v => Math.round(v * 100) + "%"
                    onMoved: value => root.setSeed("tint", value)
                }

                SliderRow {
                    label: "Vibrance"
                    description: "Saturation of the status and terminal colors"
                    value: root.seed.vibrance
                    stepSize: 0.05
                    format: v => Math.round(v * 100) + "%"
                    onMoved: value => root.setSeed("vibrance", value)
                }

                SliderRow {
                    label: "Harmony"
                    description: "How far those colors lean towards the accent"
                    value: root.seed.harmony
                    stepSize: 0.05
                    format: v => Math.round(v * 100) + "%"
                    onMoved: value => root.setSeed("harmony", value)
                }
            }

            // ================= CONTRAST =================
            SettingsGroup {
                title: "Contrast"

                SettingRow {
                    id: contrastSummary

                    label: root.failing === 0 ? "Everything is readable" : root.failing + (root.failing === 1 ? " pair is" : " pairs are") + " hard to read"
                    description: "WCAG contrast of the main color pairs"

                    leading: Text {
                        text: root.failing === 0 ? "\u{f05e0}" : "\u{f0028}"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIcon
                        color: root.failing === 0 ? Config.successColor : Config.warningColor
                    }

                    ActionButton {
                        visible: root.failing > 0
                        icon: "\u{f0068}"
                        text: "Fix all"
                        baseColor: contrastSummary.controlColor
                        onClicked: root.fixAll()
                    }
                }

                Repeater {
                    model: root.contrastChecks

                    SettingRow {
                        id: checkRow

                        required property var modelData

                        label: modelData.label
                        description: modelData.ratio.toFixed(1) + ":1 · needs " + modelData.min + ":1"
                        descriptionColor: modelData.ok ? Config.subtextColor : Config.warningColor

                        leading: Text {
                            text: checkRow.modelData.ok ? "\u{f012c}" : "\u{f0028}"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeIconSmall
                            color: checkRow.modelData.ok ? Config.successColor : Config.warningColor
                        }

                        ActionButton {
                            visible: !checkRow.modelData.ok
                            icon: "\u{f0068}"
                            text: "Fix"
                            baseColor: checkRow.controlColor
                            onClicked: root.fix(checkRow.modelData)
                        }
                    }
                }
            }

            // ================= FINE-TUNE =================
            SettingsGroup {
                title: "Fine-tune"

                ToggleRow {
                    id: fineTuneRow

                    label: "Set colors one by one"
                    description: root.overrideCount > 0 ? root.overrideCount + " set by hand; the rest follow the picks above" : "Optional: every color can be changed"
                    checked: root.fineTune
                    onToggled: value => root.fineTune = value
                }

                SettingRow {
                    id: sectionRow

                    visible: root.fineTune
                    label: "Colors of"

                    ActionButton {
                        visible: root.overrideCount > 0
                        icon: "\u{f099b}"
                        text: "Reset all"
                        baseColor: sectionRow.controlColor
                        onClicked: root.clearOverrides()
                    }

                    below: SegmentedControl {
                        width: parent.width
                        options: [
                            {
                                label: "Interface",
                                icon: "\u{f03d8}"
                            },
                            {
                                label: "Terminal",
                                icon: "\u{f018d}"
                            }
                        ]
                        currentIndex: root.fineTuneSection === "palette" ? 0 : 1
                        onSelected: index => root.fineTuneSection = index === 0 ? "palette" : "terminal"
                    }
                }

                Repeater {
                    model: root.fineTune ? (root.fineTuneSection === "palette" ? root.paletteKeys : root.terminalKeys) : []

                    ColorEditRow {
                        required property var modelData

                        label: modelData[1]
                        value: root.generated[root.fineTuneSection][modelData[0]]
                        overridden: root.overrides[root.fineTuneSection][modelData[0]] !== undefined
                        onEdited: value => root.setOverride(root.fineTuneSection, modelData[0], value)
                        onResetClicked: root.setOverride(root.fineTuneSection, modelData[0], undefined)
                    }
                }
            }

            // ================= SAVE =================
            SettingsGroup {
                title: "Save"

                ToggleRow {
                    label: root.editSlug !== "" && root.editSlug === ThemeService.currentThemeName ? "Update it now" : "Switch to it after saving"
                    checked: root.applyAfter
                    onToggled: value => root.applyAfter = value
                }

                SettingRow {
                    id: saveRow

                    label: root.nameError !== "" ? root.nameError : root.name.trim()
                    description: root.saveError !== "" ? root.saveError : root.editSlug !== "" ? "Overwrites " + root.slug + ".json" : "Adds it to your themes"
                    descriptionColor: root.saveError !== "" ? Config.errorColor : Config.subtextColor

                    ActionButton {
                        icon: "\u{f0193}"
                        text: root.saving ? "Saving…" : "Save theme"
                        baseColor: root.nameError === "" ? Config.accentColor : saveRow.controlColor
                        hoverColor: root.nameError === "" ? Qt.lighter(Config.accentColor, 1.1) : Config.surface2Color
                        textColor: root.nameError === "" ? Config.textReverseColor : Config.subtextColor
                        onClicked: root.save()
                    }
                }
            }
        }

        // ================= STICKY MOCK =================
        Item {
            id: mockSlot

            Layout.preferredWidth: Math.round(root.width * 0.36)
            Layout.fillHeight: true

            ThemeMock {
                id: mock

                width: parent.width
                height: Math.round(width * 1.5)
                portrait: true
                theme: root.generated
                wallpaper: root.mockWallpaper
                y: {
                    const f = root.flick;
                    if (!f)
                        return 0;
                    const top = mockSlot.mapToItem(f.contentItem, 0, 0).y;
                    return Math.max(0, Math.min(mockSlot.height - height, f.contentY - top + Config.padding * 2));
                }
            }
        }
    }

    // Round color choice that sets the accent
    component Swatch: Rectangle {
        id: swatch

        property string hex
        readonly property bool active: hex === String(root.seed.accent).toLowerCase()

        width: Config.fontSizeIconSmall + Config.padding
        height: width
        radius: width / 2
        color: hex
        border.width: active ? 2 : swatchMouse.containsMouse ? 1 : 0
        border.color: Config.textColor

        Text {
            visible: swatch.active
            anchors.centerIn: parent
            text: "\u{f012c}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: ThemeGenerator.contrast(swatch.hex, "#000000") > 7 ? "#000000" : "#ffffff"
        }

        MouseArea {
            id: swatchMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setSeed("accent", swatch.hex)
        }
    }
}
