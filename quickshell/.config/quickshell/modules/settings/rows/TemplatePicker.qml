pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Layout template choice: a row of TemplateTiles below the label (or a grid
// of `columns` per row). `options` is a list of { label, value }; `preview`
// draws a thumbnail of one option and must have a `value` property
SettingRow {
    id: root

    required property var options
    property Component preview
    property var value: path !== "" ? StateService.get(path, StateService.getDefault(path, options[0].value)) : options[0].value
    property real thumbHeight: Config.fontSizeIconLarge * 2 + Config.spacing * 2
    // Tiles per row; 0 = all in one row
    property int columns: 0
    readonly property int shownColumns: columns > 0 ? Math.min(columns, options.length) : Math.max(options.length, 1)

    signal selected(var value)

    below: GridLayout {
        width: parent.width
        columns: root.shownColumns
        columnSpacing: Config.spacing
        rowSpacing: Config.spacing

        Repeater {
            model: root.options

            TemplateTile {
                required property var modelData

                label: modelData.label
                value: modelData.value
                current: modelData.value === root.value
                preview: root.preview
                thumbHeight: root.thumbHeight
                onClicked: {
                    if (root.path !== "")
                        StateService.set(root.path, modelData.value);
                    root.selected(modelData.value);
                }
            }
        }
    }
}
