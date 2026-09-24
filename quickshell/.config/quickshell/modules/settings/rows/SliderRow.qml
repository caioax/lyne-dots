pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import "../../../components/"

// Numeric setting with a full-width slider below the label. Values snap to
// `stepSize`; `format` turns the value into the text on the right
SettingRow {
    id: root

    property real from: 0
    property real to: 1
    property real stepSize: 1
    property real value: path !== "" ? StateService.get(path, StateService.getDefault(path, from)) : from
    property var format: v => String(v)

    signal moved(real value)

    function _snap(v: real): real {
        const snapped = Math.round((v - from) / stepSize) * stepSize + from;
        // Avoid float noise like 0.30000000000000004
        return Number(Math.min(to, Math.max(from, snapped)).toFixed(4));
    }

    Text {
        text: root.format(root.value)
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        font.bold: true
        color: Config.subtextColor
    }

    below: QsSlider {
        width: parent.width
        value: root.value
        from: root.from
        to: root.to
        showPercentage: false
        onMoved: v => {
            const snapped = root._snap(v);
            if (root.path !== "")
                StateService.set(root.path, snapped);
            root.moved(snapped);
        }
    }
}
