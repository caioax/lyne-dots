pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.services

// Row of action buttons. With includeDefault the app's default action is
// offered too (as "Open"), for places where a click doesn't trigger it.
// Compact buttons (history) hug their text instead of sharing the width.
RowLayout {
    id: root

    required property var notif
    property bool includeDefault: false
    property bool compact: false

    readonly property var actions: includeDefault ? root.notif.listedActions : root.notif.buttonActions

    signal triggered

    visible: actions.length > 0
    spacing: Config.padding

    Repeater {
        model: root.actions

        Rectangle {
            id: pill

            required property var modelData
            readonly property string iconSource: root.notif.hasActionIcons ? (IconService.has(modelData.identifier) ? IconService.url(modelData.identifier, "") : "") : ""

            Layout.fillWidth: !root.compact
            implicitWidth: pillRow.implicitWidth + Config.padding * 4
            implicitHeight: Config.fontSizeSmall + Config.padding * 3
            radius: Config.radius
            color: pillMouse.containsMouse ? Config.surface2Color : Config.surface1Color

            Behavior on color {
                enabled: !Config.themeTransitioning
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }

            RowLayout {
                id: pillRow
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - Config.padding * 2)
                spacing: Config.padding

                IconImage {
                    visible: pill.iconSource !== ""
                    implicitSize: Config.fontSizeNormal
                    source: pill.iconSource
                }

                Text {
                    Layout.fillWidth: true
                    text: pill.modelData.text || I18n.tr("Open")
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: Config.textColor
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            MouseArea {
                id: pillMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.notif.invokeAction(pill.modelData);
                    root.triggered();
                }
            }
        }
    }
}
