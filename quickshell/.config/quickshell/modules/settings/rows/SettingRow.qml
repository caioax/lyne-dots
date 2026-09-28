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
    property color descriptionColor: Config.subtextColor
    property string path

    // Set by SettingsGroup: only the ends of a group get the large radius
    readonly property bool isSettingRow: true
    property bool first: true
    property bool last: true

    default property alias trailing: trailingRow.data
    property alias below: belowSlot.data
    // false hides `below` without leaving a gap (a control that doesn't apply)
    property bool belowVisible: true
    property alias leading: leadingRow.data

    readonly property bool hovered: rowHover.hovered
    // Background for controls inside the row, so they stay visible on hover
    readonly property color controlColor: hovered ? Config.surface2Color : Config.surface1Color
    // false for quick on/off switches (e.g. caffeine) where "reset" is noise
    property bool resettable: true
    readonly property bool modified: resettable && path !== "" && !StateService.isDefault(path)
    readonly property int rowPadding: Config.padding * 2
    // Narrow windows: when the control would leave the label less than this,
    // it moves below the label instead of squeezing it
    readonly property int minLabelWidth: Config.fontSizeNormal * 11
    readonly property bool stacked: trailingRow.implicitWidth > 0 && content.width - trailingRow.implicitWidth - (leadingRow.visible ? leadingRow.implicitWidth + Config.padding : 0) - Config.spacing * 2 < minLabelWidth

    signal resetRequested

    // Draws attention to the row (e.g. opened from the Settings search)
    function flash() {
        flashAnim.restart();
    }

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + rowPadding * 2

    color: rowHover.hovered ? Config.cardHoverColor : Config.cardColor
    topLeftRadius: first ? Config.radiusLarge : Config.radiusSmall
    topRightRadius: first ? Config.radiusLarge : Config.radiusSmall
    bottomLeftRadius: last ? Config.radiusLarge : Config.radiusSmall
    bottomRightRadius: last ? Config.radiusLarge : Config.radiusSmall

    // Disabled rows (e.g. depending on a switched off option) fade out
    opacity: enabled ? 1 : 0.4

    Behavior on color {
        enabled: !Config.themeTransitioning
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

    // Accent wash pulsed by flash()
    Rectangle {
        id: flashOverlay

        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: Qt.alpha(Config.accentColor, 0.15)
        border.width: 1
        border.color: Qt.alpha(Config.accentColor, 0.6)
        opacity: 0

        SequentialAnimation {
            id: flashAnim

            NumberAnimation {
                target: flashOverlay
                property: "opacity"
                to: 1
                duration: Config.animDuration
            }
            NumberAnimation {
                target: flashOverlay
                property: "opacity"
                to: 0.3
                duration: Config.animDurationLong
            }
            NumberAnimation {
                target: flashOverlay
                property: "opacity"
                to: 1
                duration: Config.animDuration
            }
            PauseAnimation {
                duration: Config.animDurationLong
            }
            NumberAnimation {
                target: flashOverlay
                property: "opacity"
                to: 0
                duration: Config.animDurationLong * 2
            }
        }
    }

    Column {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: root.rowPadding
        spacing: Config.spacing

        RowLayout {
            id: headerRow

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
                    color: root.descriptionColor
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

                parent: root.stacked ? stackedSlot : headerRow
                spacing: Config.spacing
            }
        }

        // The control when `stacked`, under the label
        RowLayout {
            id: stackedSlot

            width: parent.width
            visible: root.stacked
        }

        Item {
            id: belowSlot

            width: parent.width
            visible: root.belowVisible && children.length > 0
            implicitHeight: childrenRect.height
        }
    }
}
