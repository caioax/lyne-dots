pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import "../../../components/"

// On/off setting. Bound to `path` by default; set `checked` and handle
// `toggled` instead for values owned by a service
SettingRow {
    id: root

    property bool checked: path !== "" ? StateService.get(path, StateService.getDefault(path, false)) : false

    signal toggled(bool value)

    QsSwitch {
        id: toggle

        checked: root.checked
        onToggled: {
            if (root.path !== "")
                StateService.set(root.path, checked);
            root.toggled(checked);
            // Clicking breaks the binding; the state is the source of truth
            checked = Qt.binding(() => root.checked);
        }
    }
}
