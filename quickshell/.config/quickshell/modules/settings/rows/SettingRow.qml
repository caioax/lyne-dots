pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Base row of a SettingsGroup: label + description on the left, a control on
// the right (`trailing`), optionally an icon/picture before the label
// (`leading`) and a full-width control below (`below`).
// With a state `path`, a reset button shows up while the value differs from
// defaults.json
Rectangle {
    id: root

    property string label
    property string description
    property string path

    // Set by SettingsGroup: only the ends of a group get the large radius
    property bool first: true
    property bool last: true

    default property alias trailing: trailingRow.data
    property alias below: belowSlot.data
    property alias leading: leadingRow.data

    readonly property bool hovered: rowHover.hovered
    // Background for controls inside the row, so they stay visible on hover
    readonly property color controlColor: hovered ? Config.surface2Color : Config.surface1Color
    readonly property bool modified: path !== "" && !StateService.isDefault(path)
    readonly property int rowPadding: Config.padding * 2

    signal resetRequested

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + rowPadding * 2

    color: rowHover.hovered ? Config.surface1Color : Config.surface0Color
    topLeftRadius: first ? Config.radiusLarge : Config.radiusSmall
    topRightRadius: first ? Config.radiusLarge : Config.radiusSmall
    bottomLeftRadius: last ? Config.radiusLarge : Config.radiusSmall
    bottomRightRadius: last ? Config.radiusLarge : Config.radiusSmall

    // Disabled rows (e.g. depending on a switched off option) fade out
    opacity: enabled ? 1 : 0.4

    Behavior on color {
        ColorAnimation {
            duration: Config.animDurationShort
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animDuration
        }
    }

    HoverHandler {
        id: rowHover
    }

    Column {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: root.rowPadding
        spacing: Config.spacing

        RowLayout {
            width: parent.width
            spacing: Config.spacing

            RowLayout {
                id: leadingRow
                visible: children.length > 0
                Layout.rightMargin: Config.padding
                spacing: Config.spacing
            }

            Column {
                Layout.fillWidth: true
                spacing: Math.round(Config.padding / 3)

                Text {
                    width: parent.width
                    text: root.label
                    elide: Text.ElideRight
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    font.bold: true
                    color: Config.textColor
                }

                Text {
                    width: parent.width
                    visible: root.description !== ""
                    text: root.description
                    wrapMode: Text.WordWrap
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }
            }

            // Reset to default (md-restore)
            Text {
                id: resetButton

                visible: root.modified
                text: "\u{f099b}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconSmall
                color: resetMouse.containsMouse ? Config.accentColor : Config.subtextColor
                opacity: rowHover.hovered ? 1 : 0.5

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animDurationShort
                    }
                }

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent
                    anchors.margins: -Config.padding
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        StateService.reset(root.path);
                        root.resetRequested();
                    }
                }
            }

            RowLayout {
                id: trailingRow
                spacing: Config.spacing
            }
        }

        Item {
            id: belowSlot

            width: parent.width
            visible: children.length > 0
            implicitHeight: childrenRect.height
        }
    }
}
