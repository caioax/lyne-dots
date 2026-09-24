pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import "../../../components/"

// On/off setting. Bound to `path` by default; set `checked` and handle
// `toggled` instead for values owned by a service. `inverted` shows the
// opposite of the stored bool (e.g. "acceleration" for force_no_accel)
SettingRow {
    id: root

    property bool inverted: false
    property bool checked: path !== "" ? StateService.get(path, StateService.getDefault(path, false)) !== inverted : false

    signal toggled(bool value)

    QsSwitch {
        id: toggle

        checked: root.checked
        onToggled: {
            if (root.path !== "")
                StateService.set(root.path, checked !== root.inverted);
            root.toggled(checked);
            // Clicking breaks the binding; the state is the source of truth
            checked = Qt.binding(() => root.checked);
        }
    }
}
