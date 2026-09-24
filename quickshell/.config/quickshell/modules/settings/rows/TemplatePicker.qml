pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Layout template choice: a row of TemplateTiles below the label. `options`
// is a list of { label, value }; `preview` draws a thumbnail of one option
// and must have a `value` property
SettingRow {
    id: root

    required property var options
    property Component preview
    property var value: path !== "" ? StateService.get(path, StateService.getDefault(path, options[0].value)) : options[0].value
    property real thumbHeight: Config.fontSizeIconLarge * 2 + Config.spacing * 2

    signal selected(var value)

    below: RowLayout {
        width: parent.width
        spacing: Config.spacing

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
