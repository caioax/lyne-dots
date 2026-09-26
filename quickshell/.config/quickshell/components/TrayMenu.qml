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
    property int anchorY: 0

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

    // With the bar at the bottom the menu opens upward from it (a layer
    // doesn't know its own position, so anchorY only works from the top)
    anchors {
        left: true
        top: !Config.barOnBottom
        bottom: Config.barOnBottom
    }
    margins {
        left: Math.max(Config.spacing, Math.min(root.screen.width - implicitWidth - Config.spacing, root.anchorX))
        top: Config.barOnBottom ? 0 : Math.min(root.screen.height - implicitHeight - Config.spacing, root.anchorY)
        bottom: Config.barOnBottom ? Config.barReservedHeight + Config.padding : 0
    }

    function open() {
        stack = [];
        visible = true;
        focusTimer.restart();
    }

    function close() {
        visible = false;
        stack = [];
        focusGrab.active = false;
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
        windows: [root]
        active: false
        onCleared: root.close()
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

        focus: true
        Keys.onEscapePressed: {
            if (root.current)
                root.back();
            else
                root.close();
        }

        Column {
            id: column

            // Widest row's natural width, so long labels widen the menu
            // (up to maxWidth) instead of eliding right away
            readonly property real widest: {
                let w = 0;
                for (const child of children)
                    if (child.visible && child.naturalWidth !== undefined)
                        w = Math.max(w, child.naturalWidth);
                return w;
            }

            // Whether any entry of the shown menu has an icon or a toggle
            readonly property bool anyLeading: (menuOpener.children?.values ?? []).some(e => !e.isSeparator && (e.buttonType !== QsMenuButtonType.None || (e.icon ?? "") !== ""))

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
                                    root.close();
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
