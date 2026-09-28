pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import "../rows/"
import "../../../components/"
import "../../../services/ThemeGenerator.js" as ThemeGenerator

// One color of a theme being created: swatch + hex field; clicking the row
// opens lightness / chroma / hue sliders. `overridden` shows a reset to the
// generated color
SettingRow {
    id: root

    property string value: "#000000"
    property bool overridden: false
    property bool expanded: false

    // Kept while dragging, so the hue doesn't jump when the chroma hits 0
    property var lch: ThemeGenerator.hexToOklch(value)

    signal edited(string value)
    signal resetClicked

    function _setLch(key: string, v: real) {
        const next = Object.assign({}, lch);
        next[key] = v;
        lch = next;
        root.edited(ThemeGenerator.oklch(next.l, next.c, next.h));
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
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
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
            onClicked: root.expanded = !root.expanded
        }
    }

    belowVisible: expanded
    below: GridLayout {
        width: parent.width
        columns: 3
        columnSpacing: Config.spacing
        rowSpacing: Config.padding

        Repeater {
            model: [
                {
                    key: "l",
                    label: "Lightness",
                    to: 1,
                    format: v => Math.round(v * 100) + "%"
                },
                {
                    key: "c",
                    label: "Colorfulness",
                    to: 0.37,
                    format: v => Math.round(v / 0.37 * 100) + "%"
                },
                {
                    key: "h",
                    label: "Hue",
                    to: 360,
                    format: v => Math.round(v) + "°"
                }
            ]

            ColumnLayout {
                id: slider

                required property var modelData

                Layout.fillWidth: true
                spacing: Math.round(Config.padding / 2)

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: slider.modelData.label
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                    }

                    Text {
                        text: slider.modelData.format(root.lch[slider.modelData.key])
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: true
                        color: Config.subtextColor
                    }
                }

                QsSlider {
                    Layout.fillWidth: true
                    value: root.lch[slider.modelData.key]
                    from: 0
                    to: slider.modelData.to
                    stepSize: slider.modelData.to / 200
                    showPercentage: false
                    wheelEnabled: false
                    onMoved: v => root._setLch(slider.modelData.key, v)
                }
            }
        }
    }
}
