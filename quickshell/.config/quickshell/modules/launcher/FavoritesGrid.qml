pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Pinned apps as tiles. They are the first `LauncherService.favoriteCount`
// entries of the selection
GridLayout {
    id: root

    readonly property int count: LauncherService.favoriteCount

    signal launched
    signal menuRequested(Item anchor, var app)

    columns: 6
    columnSpacing: Config.padding
    rowSpacing: Config.padding

    Repeater {
        model: LauncherService.favoriteApps

        AppTile {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            selected: index === LauncherService.selectedIndex
            // First click selects, a click on the selected one opens it
            onActivated: {
                if (!selected) {
                    LauncherService.select(index);
                    return;
                }
                root.launched();
                LauncherService.launch(modelData);
            }
            onMenuRequested: anchor => root.menuRequested(anchor, modelData)
        }
    }

    // Keeps a short row at column size instead of stretching its tiles
    Repeater {
        model: Math.max(0, root.columns - root.count)

        Item {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
        }
    }
}
