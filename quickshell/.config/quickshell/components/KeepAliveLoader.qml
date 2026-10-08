import QtQuick
import qs.config

// A Loader that keeps its item for `exitDuration` after `shown` turns false,
// so the exit animation plays before the item is destroyed; every open then
// starts from a fresh item
Loader {
    id: root

    property bool shown: false
    property int exitDuration: Config.animDurationLong

    active: shown || exitTimer.running
    onShownChanged: {
        if (!shown)
            exitTimer.restart();
    }

    Timer {
        id: exitTimer
        interval: root.exitDuration
    }
}
