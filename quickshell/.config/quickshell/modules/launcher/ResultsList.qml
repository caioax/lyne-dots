pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// Scrollable list of AppRows following LauncherService's selection (which
// counts the favorites first). Its implicit height fits up to `maxRows` rows
// (or the empty state)
ListView {
    id: root

    property int maxRows: 7
    property bool showDescription: true
    readonly property int rowHeight: Config.fontSizeIconLarge + Config.padding * 4
    readonly property int emptyHeight: Config.fontSizeIconLarge * 4
    // Rows leave room for the scrollbar when the list scrolls
    readonly property int rowWidth: width - (contentHeight > height ? scrollBar.width + Config.padding : 0)

    readonly property int offset: LauncherService.favoriteCount
    // Selected row, -1 while a favorite is selected. Not ListView's
    // currentIndex, which snaps back to 0 on its own
    readonly property int selectedRow: LauncherService.selectedIndex - offset

    signal launched
    signal menuRequested(Item anchor, var app)

    implicitHeight: count === 0 ? emptyHeight : Math.min(count, maxRows) * (rowHeight + spacing) - spacing
    clip: true
    spacing: Math.round(Config.padding / 2)
    boundsBehavior: Flickable.StopAtBounds
    model: LauncherService.filteredApps
    // No animation while keeping the selection in view, so the mouse
    // doesn't land on a moving row
    onSelectedRowChanged: {
        if (selectedRow >= 0)
            positionViewAtIndex(selectedRow, ListView.Contain);
    }

    delegate: AppRow {
        width: root.rowWidth
        height: root.rowHeight
        selected: index === root.selectedRow
        showDescription: root.showDescription
        // First click selects the app, a click on the selected one opens it
        onActivated: {
            if (!selected) {
                LauncherService.select(index + root.offset);
                return;
            }
            root.launched();
            LauncherService.launch(modelData);
        }
        onMenuRequested: anchor => root.menuRequested(anchor, modelData)
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
