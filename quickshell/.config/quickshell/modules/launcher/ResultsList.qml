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
    model: LauncherService.results
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
        // First click selects, a click on the selected one opens / runs it
        onActivated: {
            if (!selected) {
                LauncherService.select(index + root.offset);
                return;
            }
            root.launched();
            LauncherService.activate(modelData);
        }
        onMenuRequested: anchor => root.menuRequested(anchor, modelData)
    }

    ScrollBar.vertical: QsScrollBar {
        id: scrollBar
    }

    // Empty state for the current mode
    readonly property var emptyState: {
        const mode = LauncherService.mode.id;
        const term = LauncherService.term;
        if (mode === "calc") {
            if (LauncherService.calcError !== "")
                return {
                    icon: "\u{f0028}",
                    text: LauncherService.calcError
                };
            return {
                icon: "\u{f00ec}",
                text: term === "" ? "Type an expression, e.g. 2^10 or 5 km to mi" : "Calculating…"
            };
        }
        if (term !== "")
            return {
                icon: "\u{f0980}",
                text: "No " + (mode === "actions" ? "actions" : "apps") + " match \"" + term + "\""
            };
        return {
            icon: "\u{f003b}",
            text: "No apps found"
        };
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - Config.padding * 4
        visible: root.count === 0
        spacing: Config.spacing

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.emptyState.icon
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconLarge
            color: Config.mutedColor
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.emptyState.text
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: Config.subtextColor
        }
    }
}
