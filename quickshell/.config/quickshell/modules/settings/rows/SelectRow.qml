pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../../components/"

// One-of-many setting shown as a SegmentedControl. `options` is a list of
// { label, value, icon? }
SettingRow {
    id: root

    required property var options
    property var value: path !== "" ? StateService.get(path, StateService.getDefault(path, options[0].value)) : options[0].value

    // Width of each option; raise it for long labels
    property real segmentWidth: Config.fontSizeNormal * 6

    signal selected(var value)

    SegmentedControl {
        Layout.fillWidth: false
        Layout.preferredWidth: root.segmentWidth * root.options.length
        options: root.options
        currentIndex: Math.max(0, root.options.findIndex(o => o.value === root.value))
        onSelected: index => {
            const value = root.options[index].value;
            if (root.path !== "")
                StateService.set(root.path, value);
            root.selected(value);
        }
    }
}
