pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.config
import qs.services
import "../../components/"

// Results as AppTiles in `columns` columns (the Grid template). Selection
// works like ResultsList: it counts the favorites first
GridView {
    id: root

    property int columns: 6
    readonly property int offset: LauncherService.favoriteCount
    readonly property int selectedCell: LauncherService.selectedIndex - offset
    readonly property int tileHeight: Config.fontSizeIconLarge + Config.padding * 7 + Config.fontSizeSmall
    readonly property int rowsVisible: Math.max(1, Math.floor(height / cellHeight))

    signal launched
    signal menuRequested(Item anchor, var app)

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    cellWidth: Math.floor(width / columns)
    cellHeight: tileHeight + Config.padding
    model: LauncherService.results

    onSelectedCellChanged: {
        if (selectedCell >= 0)
            positionViewAtIndex(selectedCell, GridView.Contain);
    }

    delegate: Item {
        id: cell

        required property var modelData
        required property int index

        width: root.cellWidth
        height: root.cellHeight

        AppTile {
            anchors.fill: parent
            anchors.margins: Math.round(Config.padding / 2)
            modelData: cell.modelData
            index: cell.index
            selected: cell.index === root.selectedCell
            // First click selects, a click on the selected one opens it
            onActivated: {
                if (!selected) {
                    LauncherService.select(cell.index + root.offset);
                    return;
                }
                root.launched();
                LauncherService.activate(cell.modelData);
            }
            onMenuRequested: anchor => root.menuRequested(anchor, cell.modelData)
        }
    }

    ScrollBar.vertical: QsScrollBar {}
}
