pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../../components/"

// Numeric setting with − value + buttons, for small ranges or exact values.
// With `values`, the buttons walk that list instead of from/to/stepSize
SettingRow {
    id: root

    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: path !== "" ? StateService.get(path, StateService.getDefault(path, from)) : from
    property var values: []
    property var format: v => String(v)

    signal moved(real value)

    readonly property int buttonSize: Config.fontSizeIconSmall + Config.padding * 2

    // Position in `values`: the closest entry, so off-list values still step sanely
    readonly property int _index: {
        let best = 0;
        values.forEach((v, i) => {
            if (Math.abs(v - value) < Math.abs(values[best] - value))
                best = i;
        });
        return best;
    }
    readonly property bool _canDecrease: values.length > 0 ? _index > 0 : value > from
    readonly property bool _canIncrease: values.length > 0 ? _index < values.length - 1 : value < to

    function _step(direction: int) {
        const next = values.length > 0 ? values[Math.min(values.length - 1, Math.max(0, _index + direction))] : Number(Math.min(to, Math.max(from, value + direction * stepSize)).toFixed(4));
        if (next === value)
            return;
        if (path !== "")
            StateService.set(path, next);
        moved(next);
    }

    // md-minus
    ActionButton {
        icon: "\u{f0374}"
        size: root.buttonSize
        baseColor: root.controlColor
        hoverColor: Config.surface3Color
        iconSize: Config.fontSizeNormal
        opacity: root._canDecrease ? 1 : 0.4
        onClicked: root._step(-1)
    }

    Text {
        // Fixed width so the buttons don't move while the value changes
        Layout.preferredWidth: valueMetrics.width
        horizontalAlignment: Text.AlignHCenter
        text: root.format(root.value)
        font.family: Config.font
        font.pixelSize: Config.fontSizeNormal
        font.bold: true
        color: Config.textColor

        TextMetrics {
            id: valueMetrics
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            font.bold: true
            // Widest label, so rows of the same kind line up
            text: (root.values.length > 0 ? root.values.map(v => root.format(v)).reduce((a, b) => b.length > a.length ? b : a, "") : root.format(root.to)) + "0"
        }
    }

    // md-plus
    ActionButton {
        icon: "\u{f0415}"
        size: root.buttonSize
        baseColor: root.controlColor
        hoverColor: Config.surface3Color
        iconSize: Config.fontSizeNormal
        opacity: root._canIncrease ? 1 : 0.4
        onClicked: root._step(1)
    }
}
