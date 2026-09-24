pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Scrollable list of AppRows following LauncherService's selection. Its
// implicit height fits up to `maxRows` rows (or the empty state)
ListView {
    id: root

    property int maxRows: 7
    property bool showDescription: true
    readonly property int rowHeight: Config.fontSizeIconLarge + Config.padding * 4
    readonly property int emptyHeight: Config.fontSizeIconLarge * 4
    // Rows leave room for the scrollbar when the list scrolls
    readonly property int rowWidth: width - (contentHeight > height ? scrollBar.width + Config.padding : 0)

    signal launched

    implicitHeight: count === 0 ? emptyHeight : Math.min(count, maxRows) * (rowHeight + spacing) - spacing
    clip: true
    spacing: Math.round(Config.padding / 2)
    boundsBehavior: Flickable.StopAtBounds
    model: LauncherService.filteredApps
    currentIndex: LauncherService.selectedIndex

    // No animation while keeping the selection in view, so the mouse
    // doesn't land on a moving row
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

    highlightFollowsCurrentItem: false
    highlight: Rectangle {
        width: root.rowWidth
        height: root.rowHeight
        y: root.currentItem?.y ?? 0
        radius: Config.radiusLarge
        color: Config.surface1Color
        border.width: 1
        border.color: Qt.alpha(Config.accentColor, 0.6)

        Behavior on y {
            NumberAnimation {
                duration: Config.animDurationShort
                easing.type: Easing.OutCubic
            }
        }
    }

    delegate: AppRow {
        width: root.rowWidth
        height: root.rowHeight
        selected: index === LauncherService.selectedIndex
        showDescription: root.showDescription
        onActivated: {
            root.launched();
            LauncherService.launch(modelData);
        }
    }

    ScrollBar.vertical: QsScrollBar {
        id: scrollBar
    }

    Column {
        anchors.centerIn: parent
        visible: root.count === 0
        spacing: Config.spacing

        // md-magnify-close / md-apps
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: LauncherService.query !== "" ? "\u{f0980}" : "\u{f003b}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconLarge
            color: Config.mutedColor
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: LauncherService.query !== "" ? "No apps match \"" + LauncherService.query + "\"" : "No apps found"
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: Config.subtextColor
        }
    }
}
