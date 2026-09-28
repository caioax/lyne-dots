pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Settings search results, in place of the sidebar pages while there's a
// query: pages, groups and rows (SettingsService.searchIndex). The search
// field drives the selection with move() and activateCurrent()
Item {
    id: root

    property string query
    readonly property var results: SettingsService.indexing ? [] : SettingsService.search(query)
    readonly property int boxSize: Config.fontSizeIconSmall * 2

    signal activated

    function move(delta: int) {
        if (results.length === 0)
            return;
        list.currentIndex = Math.max(0, Math.min(results.length - 1, list.currentIndex + delta));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }

    function activateCurrent() {
        if (list.currentIndex >= 0 && list.currentIndex < results.length) {
            SettingsService.reveal(results[list.currentIndex]);
            activated();
        }
    }

    // A new query starts from the best match
    onResultsChanged: list.currentIndex = 0

    ListView {
        id: list

        anchors.fill: parent
        clip: true
        model: root.results
        spacing: Math.round(Config.padding / 3)
        boundsBehavior: Flickable.StopAtBounds
        highlightFollowsCurrentItem: false

        ScrollBar.vertical: QsScrollBar {
            autoHide: true
            peek: listHover.hovered
        }

        HoverHandler {
            id: listHover
        }

        delegate: Rectangle {
            id: item

            required property var modelData
            required property int index
            readonly property bool current: ListView.isCurrentItem
            readonly property string context: modelData.kind === "page" ? modelData.description : modelData.kind === "group" ? modelData.pageLabel + " · section" : modelData.pageLabel + (modelData.group !== "" ? " › " + modelData.group : "")

            width: list.width - Config.padding * 2
            implicitHeight: row.implicitHeight + Config.padding * 2
            radius: Config.radiusLarge
            color: current ? Qt.alpha(Config.accentColor, 0.15) : mouse.containsMouse ? Config.surface1Color : Qt.alpha(Config.surface1Color, 0)

            Behavior on color {
                enabled: !Config.themeTransitioning
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }

            RowLayout {
                id: row

                anchors.fill: parent
                anchors.margins: Config.padding
                spacing: Config.spacing + Config.padding

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: root.boxSize
                    implicitHeight: root.boxSize
                    radius: Config.radiusLarge
                    color: item.current ? Config.accentColor : Config.surface1Color

                    Behavior on color {
                        enabled: !Config.themeTransitioning
                        ColorAnimation {
                            duration: Config.animDurationShort
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: item.modelData.icon
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeLarge
                        color: item.current ? Config.textReverseColor : Config.textColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: item.modelData.label
                        elide: Text.ElideRight
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        font.bold: item.modelData.kind !== "row"
                        color: item.current ? Config.accentColor : Config.textColor
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: item.context
                        elide: Text.ElideRight
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                    }
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    list.currentIndex = item.index;
                    root.activateCurrent();
                }
            }
        }
    }

    // Nothing found
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - Config.padding * 4
        visible: root.results.length === 0
        spacing: Config.spacing

        // md-magnify_close
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "\u{f0980}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconLarge
            color: Config.mutedColor
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: SettingsService.indexing ? "Searching…" : "No settings match “" + root.query.trim() + "”"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }
    }
}
