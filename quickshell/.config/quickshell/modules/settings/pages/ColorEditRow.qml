pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import "../rows/"
import "../../../services/ThemeGenerator.js" as ThemeGenerator

// One color of a theme being created: swatch + hex field; clicking the
// swatch or the chevron opens the visual picker (OklchPicker). `presets` adds
// ready-made choices above it, `alwaysOpen` keeps it open. `overridden`
// shows a reset to the generated color
SettingRow {
    id: root

    property string value: "#000000"
    property bool overridden: false
    property var presets: []
    property bool alwaysOpen: false
    property bool open: false
    readonly property bool expanded: alwaysOpen || open

    // Kept while dragging, so the hue doesn't jump when the chroma hits 0
    property var lch: ThemeGenerator.hexToOklch(value)

    signal edited(string value)
    signal resetClicked

    function _setLch(l: real, c: real, h: real) {
        lch = {
            l: l,
            c: c,
            h: h
        };
        root.edited(ThemeGenerator.oklch(l, c, h));
    }

    onValueChanged: {
        if (!expanded || ThemeGenerator.oklch(lch.l, lch.c, lch.h) !== value)
            lch = ThemeGenerator.hexToOklch(value);
    }

    leading: Rectangle {
        implicitWidth: Config.fontSizeIconSmall + Config.padding
        implicitHeight: implicitWidth
        radius: Config.radius
        color: root.value
        border.width: 1
        border.color: Qt.alpha(Config.textColor, 0.2)

        MouseArea {
            anchors.fill: parent
            enabled: !root.alwaysOpen
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    // Reset to the generated color (md-restore)
    Text {
        visible: root.overridden
        text: "\u{f099b}"
        font.family: Config.font
        font.pixelSize: Config.fontSizeIconSmall
        color: resetMouse.containsMouse ? Config.accentColor : Config.subtextColor

        MouseArea {
            id: resetMouse
            anchors.fill: parent
            anchors.margins: -Config.padding
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.resetClicked()
        }
    }

    Rectangle {
        Layout.preferredWidth: Config.fontSizeNormal * 6
        implicitHeight: Config.fontSizeIconSmall + Config.padding * 2
        radius: Config.radius
        color: root.controlColor
        border.width: hexInput.activeFocus ? 1 : 0
        border.color: Qt.alpha(Config.accentColor, 0.6)

        TextInput {
            id: hexInput

            readonly property bool valid: /^#?[0-9a-fA-F]{6}$/.test(text.trim())

            anchors.fill: parent
            anchors.leftMargin: Config.padding * 1.5
            anchors.rightMargin: Config.padding * 1.5
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            text: root.value
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: valid ? Config.textColor : Config.errorColor
            selectionColor: Qt.alpha(Config.accentColor, 0.4)
            onTextEdited: {
                if (valid) {
                    const t = text.trim().toLowerCase();
                    root.edited(t.startsWith("#") ? t : "#" + t);
                }
            }
            onActiveFocusChanged: {
                if (!activeFocus)
                    text = Qt.binding(() => root.value);
            }
        }
    }

    // md-chevron_down / md-chevron_up
    Text {
        visible: !root.alwaysOpen
        text: root.expanded ? "\u{f0143}" : "\u{f0140}"
        font.family: Config.font
        font.pixelSize: Config.fontSizeIconSmall
        color: chevronMouse.containsMouse ? Config.accentColor : Config.subtextColor

        MouseArea {
            id: chevronMouse
            anchors.fill: parent
            anchors.margins: -Config.padding
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    belowVisible: expanded
    below: Column {
        width: parent.width
        spacing: Config.spacing

        Flow {
            visible: root.presets.length > 0
            width: parent.width
            spacing: Config.padding

            Repeater {
                model: root.presets

                Rectangle {
                    id: preset

                    required property string modelData
                    readonly property bool active: modelData === String(root.value).toLowerCase()

                    width: Config.fontSizeIconSmall + Config.padding
                    height: width
                    radius: width / 2
                    color: modelData
                    border.width: active ? 2 : presetMouse.containsMouse ? 1 : 0
                    border.color: Config.textColor

                    // md-check
                    Text {
                        visible: preset.active
                        anchors.centerIn: parent
                        text: "\u{f012c}"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: true
                        color: ThemeGenerator.contrast(preset.modelData, "#000000") > 7 ? "#000000" : "#ffffff"
                    }

                    MouseArea {
                        id: presetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.edited(preset.modelData)
                    }
                }
            }
        }

        // Only built while shown: one shader pair per open row
        Loader {
            width: parent.width
            active: root.expanded

            sourceComponent: OklchPicker {
                lch: root.lch
                onPicked: (l, c, h) => root._setLch(l, c, h)
            }
        }
    }
}
