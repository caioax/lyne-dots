pragma ComponentBehavior: Bound
import QtQuick
import QtQml
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// Context menu of a tray item (its DBus menu), drawn like the shared ⋮
// ContextMenu: a card of rows, submenus open in place with a back row.
// A window of its own, since the menu is taller than the bar.
PanelWindow {
    id: root

    // Set before open()
    property var rootMenuHandle: null
    property int anchorX: 0
    // From the screen top, or with the bar at the bottom, from the screen
    // bottom (a layer doesn't know its own position, so it anchors to the
    // edge the menu grows from)
    property int anchorY: 0
    property int anchorBottom: 0
    // Window the menu was opened from (the tray overflow popup): part of
    // the focus grab, so clicks on it don't dismiss the menu
    property var companion: null

    // Shell rows above the app's own entries (root menu only):
    // [{ action, label, glyph }], answered with extraTriggered(action)
    property var extras: []

    signal extraTriggered(string action)
    // How the menu went away: "triggered", "escape" or "outside"
    signal dismissed(string reason)

    // Submenus entered so far: [{ entry, label }]; empty = the root menu
    property var stack: []
    readonly property var current: stack.length > 0 ? stack[stack.length - 1] : null

    readonly property int minWidth: Config.fontSizeNormal * 16
    readonly property int maxWidth: Config.fontSizeNormal * 26

    color: "transparent"
    implicitWidth: Math.max(minWidth, Math.min(maxWidth, column.widest + card.padding * 2))
    implicitHeight: column.implicitHeight + card.padding * 2

    WlrLayershell.namespace: "qs_modules"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: -1

    anchors {
        left: true
        top: !Config.barOnBottom
        bottom: Config.barOnBottom
    }
    margins {
        left: Math.max(Config.spacing, Math.min(root.screen.width - implicitWidth - Config.spacing, root.anchorX))
        top: Config.barOnBottom ? 0 : Math.min(root.screen.height - implicitHeight - Config.spacing, root.anchorY)
        bottom: Config.barOnBottom ? root.anchorBottom : 0
    }

    // Drives the open/close animation; the window stays mapped until the
    // closing one ends
    property bool shown: false

    function open() {
        hideTimer.stop();
        if (!shown)
            stack = [];
        visible = true;
        shown = true;
        focusTimer.restart();
    }

    function close(reason) {
        if (!shown)
            return;
        shown = false;
        focusGrab.active = false;
        hideTimer.restart();
        dismissed(reason ?? "outside");
    }

    Timer {
        id: hideTimer
        interval: Config.animDurationShort
        onTriggered: {
            root.visible = false;
            root.stack = [];
        }
    }

    // Entering or leaving a submenu fades the new rows in
    onStackChanged: {
        if (shown)
            contentFade.restart();
    }

    function enter(entry) {
        stack = [...stack, {
                entry: entry,
                label: cleanLabel(entry.text)
            }];
    }

    function back() {
        stack = stack.slice(0, -1);
    }

    // DBus menus mark mnemonics with "_" ("_Quit"); "__" is a literal one
    function cleanLabel(text) {
        return (text ?? "").replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_");
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: root.companion ? [root, root.companion] : [root]
        active: false
        onCleared: root.close("outside")
    }

    // The grab is cleared at once when activated in the same tick the
    // window maps
    Timer {
        id: focusTimer
        interval: 50
        onTriggered: {
            focusGrab.active = true;
            card.forceActiveFocus();
        }
    }

    QsMenuOpener {
        id: menuOpener
        menu: root.current ? root.current.entry : root.rootMenuHandle
    }

    // A menu is only loaded while an opener holds it, and unloading one
    // destroys its entries: keep the root and every entered level open, or
    // the submenu entry shown right now turns null
    QsMenuOpener {
        menu: root.visible ? root.rootMenuHandle : null
    }

    Instantiator {
        model: root.stack

        QsMenuOpener {
            required property var modelData
            menu: modelData.entry
        }
    }

    Rectangle {
        id: card

        readonly property int padding: Math.round(Config.padding / 2)

        anchors.fill: parent
        radius: Config.radiusLarge
        color: Config.cardColor
        border.width: 1
        border.color: Config.surface2Color
        enabled: root.shown

        // Grows out of the tray icon: from its top-left corner under a top
        // bar, from the bottom-left above a bottom one
        transformOrigin: Config.barOnBottom ? Item.BottomLeft : Item.TopLeft
        scale: root.shown ? 1 : 0.9
        opacity: root.shown ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: Config.animDurationShort
                easing.type: root.shown ? Easing.OutExpo : Easing.InCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }

        focus: true
        Keys.onEscapePressed: {
            if (root.current)
                root.back();
            else
                root.close("escape");
        }

        Column {
            id: column

            NumberAnimation {
                id: contentFade
                target: column
                property: "opacity"
                from: 0
                to: 1
                duration: Config.animDurationShort
                easing.type: Easing.OutCubic
            }

            // Widest row's natural width, so long labels widen the menu
            // (up to maxWidth) instead of eliding right away
            readonly property real widest: {
                let w = 0;
                for (const child of children)
                    if (child.visible && child.naturalWidth !== undefined)
                        w = Math.max(w, child.naturalWidth);
                return w;
            }

            // Whether any row of the shown menu has an icon or a toggle
            // (the shell rows on top always have a glyph)
            readonly property bool anyLeading: (!root.current && root.extras.length > 0) || (menuOpener.children?.values ?? []).some(e => !e.isSeparator && (e.buttonType !== QsMenuButtonType.None || (e.icon ?? "") !== ""))

            anchors.fill: parent
            anchors.margins: card.padding
            spacing: Math.round(Config.padding / 3)

            // Back from a submenu (md-chevron_left)
            MenuRow {
                visible: root.current !== null
                label: root.current?.label ?? ""
                glyph: "\u{f0141}"
                muted: true
                onClicked: root.back()
            }

            Repeater {
                model: root.current ? [] : root.extras

                MenuRow {
                    required property var modelData

                    label: modelData.label
                    glyph: modelData.glyph
                    muted: true
                    onClicked: {
                        root.extraTriggered(modelData.action);
                        root.close("triggered");
                    }
                }
            }

            // Between the shell rows and the app's entries
            Item {
                visible: !root.current && root.extras.length > 0 && (menuOpener.children?.values.length ?? 0) > 0
                width: parent.width
                implicitHeight: Config.padding + 1

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - Config.padding * 2
                    height: 1
                    color: Config.surface2Color
                }
            }

            Repeater {
                model: menuOpener.children

                delegate: Loader {
                    id: entryLoader

                    required property var modelData
                    readonly property real naturalWidth: item?.naturalWidth ?? 0

                    width: column.width
                    sourceComponent: modelData?.isSeparator ? separator : entryRow

                    Component {
                        id: separator

                        Item {
                            readonly property real naturalWidth: 0
                            implicitHeight: Config.padding + 1

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - Config.padding * 2
                                height: 1
                                color: Config.surface2Color
                            }
                        }
                    }

                    Component {
                        id: entryRow

                        MenuRow {
                            readonly property var entry: entryLoader.modelData

                            // entry turns null for a moment while the menu reloads
                            label: root.cleanLabel(entry?.text)
                            iconSource: TrayService.getMenuIconSource(entry?.icon)
                            buttonType: entry?.buttonType ?? QsMenuButtonType.None
                            checked: entry?.checkState === Qt.Checked
                            // md-chevron_right
                            trailingGlyph: entry?.hasChildren ? "\u{f0142}" : ""
                            enabled: entry?.enabled ?? false
                            reserveLeading: column.anyLeading
                            onClicked: {
                                if (entry.hasChildren) {
                                    root.enter(entry);
                                } else {
                                    entry.triggered();
                                    root.close("triggered");
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component MenuRow: Rectangle {
        id: menuRow

        property string label
        property string glyph
        property string iconSource
        property int buttonType: QsMenuButtonType.None
        property bool checked: false
        property string trailingGlyph
        property bool muted: false
        property bool reserveLeading: false
        readonly property bool hasLeading: glyph !== "" || iconSource !== "" || buttonType !== QsMenuButtonType.None

        readonly property real naturalWidth: row.implicitWidth + row.anchors.leftMargin + row.anchors.rightMargin

        signal clicked

        width: parent?.width ?? 0
        implicitHeight: row.implicitHeight + Config.padding * 2
        radius: Config.radius
        opacity: enabled ? 1 : 0.4
        color: rowMouse.containsMouse ? Config.surface1Color : Qt.alpha(Config.surface1Color, 0)

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration
            }
        }

        RowLayout {
            id: row

            anchors.fill: parent
            anchors.leftMargin: Config.padding * 2
            anchors.rightMargin: Config.padding * 2
            spacing: Config.spacing

            // Glyph, app icon or toggle; the slot stays empty (but keeps
            // its width) on plain rows of a menu where others have one
            Item {
                visible: menuRow.hasLeading || menuRow.reserveLeading
                Layout.preferredWidth: Config.fontSizeLarge
                Layout.preferredHeight: Config.fontSizeLarge

                Text {
                    anchors.centerIn: parent
                    visible: menuRow.glyph !== ""
                    text: menuRow.glyph
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    color: menuRow.muted ? Config.subtextColor : Config.textColor
                }

                // App-provided icon; hidden while missing or broken
                Image {
                    anchors.fill: parent
                    visible: menuRow.iconSource !== "" && status === Image.Ready
                    source: menuRow.iconSource
                    sourceSize: Qt.size(Config.fontSizeLarge * 2, Config.fontSizeLarge * 2)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                // Check box / radio button of toggle entries
                Rectangle {
                    id: toggle

                    readonly property bool radio: menuRow.buttonType === QsMenuButtonType.RadioButton

                    anchors.centerIn: parent
                    visible: menuRow.buttonType !== QsMenuButtonType.None
                    width: Config.fontSizeNormal
                    height: Config.fontSizeNormal
                    radius: radio ? width / 2 : Config.radiusSmall / 2
                    color: menuRow.checked && !radio ? Config.accentColor : Qt.alpha(Config.accentColor, 0)
                    border.width: 1
                    border.color: menuRow.checked ? Config.accentColor : Config.subtextColor

                    // md-check for boxes, an inner dot for radios
                    Text {
                        anchors.centerIn: parent
                        visible: menuRow.checked && !toggle.radio
                        text: "\u{f012c}"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.backgroundColor
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        visible: menuRow.checked && toggle.radio
                        width: parent.width / 2
                        height: width
                        radius: width / 2
                        color: Config.accentColor
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: menuRow.label
                elide: Text.ElideRight
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                font.bold: menuRow.muted
                color: menuRow.muted ? Config.subtextColor : Config.textColor
            }

            Text {
                visible: menuRow.trailingGlyph !== ""
                text: menuRow.trailingGlyph
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: Config.subtextColor
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menuRow.clicked()
        }
    }
}
