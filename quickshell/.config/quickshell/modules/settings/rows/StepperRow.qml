pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../../components/"

// Numeric setting with − value + buttons, for small ranges or exact values
SettingRow {
    id: root

    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: path !== "" ? StateService.get(path, StateService.getDefault(path, from)) : from
    property var format: v => String(v)

    signal moved(real value)

    readonly property int buttonSize: Config.fontSizeIconSmall + Config.padding * 2

    function _step(direction: int) {
        const next = Number(Math.min(to, Math.max(from, value + direction * stepSize)).toFixed(4));
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
        opacity: root.value > root.from ? 1 : 0.4
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
            text: root.format(root.to) + "0"
        }
    }

    // md-plus
    ActionButton {
        icon: "\u{f0415}"
        size: root.buttonSize
        baseColor: root.controlColor
        hoverColor: Config.surface3Color
        iconSize: Config.fontSizeNormal
        opacity: root.value < root.to ? 1 : 0.4
        onClicked: root._step(1)
    }
}
