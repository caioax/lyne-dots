import QtQuick

// Holds a service while `active`: acquire() when it turns true, release()
// when it turns false or this is destroyed, only on real changes (a change
// handler doesn't run for the initial value, so a bare onActiveChanged
// misses a start already active). `hold: "watch"` uses watch()/unwatch()
QtObject {
    id: root

    property QtObject service
    property bool active: false
    property string hold: "acquire"

    property bool _held: false

    function _sync(): void {
        if (active === _held || !service)
            return;
        _held = active;
        if (hold === "watch")
            active ? service.watch() : service.unwatch();
        else
            active ? service.acquire() : service.release();
    }

    onActiveChanged: _sync()
    Component.onCompleted: _sync()
    Component.onDestruction: {
        if (!_held)
            return;
        hold === "watch" ? service.unwatch() : service.release();
    }
}
