pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

Singleton {
    id: root

    // ========================================================================
    // STATE
    // ========================================================================

    // Newest first. Items are snapshots, so they outlive the D-Bus object
    property list<NotifData> list: []
    readonly property list<NotifData> popups: list.filter(n => n.popup)

    // App names ordered by their most recent notification (history groups)
    readonly property var groupNames: {
        const names = [];
        for (const n of list) {
            if (!names.includes(n.appName))
                names.push(n.appName);
        }
        return names;
    }

    readonly property int count: list.length
    readonly property int activePopupCount: popups.length

    property bool dndEnabled: StateService.get("notifications.dnd", false)

    signal windowToggleRequested

    Connections {
        target: StateService

        function onStateLoaded() {
            root.dndEnabled = StateService.get("notifications.dnd", false);
        }
    }

    // ========================================================================
    // DND
    // ========================================================================

    function setDnd(enabled: bool) {
        if (dndEnabled === enabled)
            return;
        dndEnabled = enabled;
        StateService.set("notifications.dnd", enabled);
        if (enabled) {
            for (const n of popups) {
                if (n.urgency !== NotificationUrgency.Critical)
                    n.hidePopup();
            }
        }
    }

    function toggleDnd() {
        setDnd(!dndEnabled);
    }

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    function notificationsOf(appName: string): var {
        return list.filter(n => n.appName === appName);
    }

    function dismissGroup(appName: string) {
        for (const n of notificationsOf(appName))
            n.close();
    }

    function clearAll() {
        for (const n of list.slice())
            n.close();
    }

    // "now", "5m", "2h", "3d" — re-evaluated every second through TimeService
    function relativeTime(time: date): string {
        const minutes = Math.floor((TimeService.date.getTime() - time.getTime()) / 60000);
        if (minutes < 1)
            return "now";
        if (minutes < 60)
            return minutes + "m";
        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return hours + "h";
        return Math.floor(hours / 24) + "d";
    }

    function iconSource(icon: string): string {
        if (icon === "")
            return "";
        if (icon.startsWith("/"))
            return "file://" + icon;
        if (icon.includes("://"))
            return icon;
        return Quickshell.iconPath(icon, true);
    }

    // Keep at most notifMaxPopups on screen, hiding the oldest ones first
    function trimPopups() {
        const visible = popups.filter(n => !n.exiting);
        for (let i = Config.notifMaxPopups; i < visible.length; i++)
            visible[i].hidePopup();
    }

    // ========================================================================
    // NOTIFICATION SERVER
    // ========================================================================

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;

            const critical = notif.urgency === NotificationUrgency.Critical;
            const data = notifComponent.createObject(root, {
                "notification": notif
            });

            root.list = [data, ...root.list];

            // Notifications restored after a reload go straight to history
            if (!notif.lastGeneration && (critical || !root.dndEnabled))
                data.showPopup();
            else if (data.isTransient)
                data.close();
        }
    }

    Component {
        id: notifComponent
        NotifData {}
    }

    // ========================================================================
    // NOTIFICATION DATA
    // ========================================================================

    component NotifData: QtObject {
        id: notif

        required property Notification notification

        readonly property date time: new Date()
        property bool popup: false
        // Popup is playing its exit animation; `popup` turns false right after
        property bool exiting: false
        property bool closeAfterExit: false
        property bool closed: false
        property bool dropped: false

        // Set by the popup while hovered or typing a reply
        property bool held: false

        // Snapshot of the D-Bus notification (refreshed when the app replaces it)
        property int notifId: -1
        property string appName: ""
        property string appIcon: ""
        property string summary: ""
        property string body: ""
        property string image: ""
        property int urgency: NotificationUrgency.Normal
        property bool resident: false
        property bool isTransient: false
        property bool hasActionIcons: false
        property bool hasInlineReply: false
        property string inlineReplyPlaceholder: ""
        property real expireTimeout: 0
        property var actions: []
        property int progressValue: -1

        readonly property bool isCritical: urgency === NotificationUrgency.Critical
        readonly property var defaultAction: actions.find(a => a.identifier === "default") ?? null
        readonly property var buttonActions: actions.filter(a => a.identifier !== "default" && a.text !== "")

        // Popup lifetime in ms; 0 means it stays until dismissed
        readonly property int timeout: {
            if (isCritical)
                return 0;
            if (expireTimeout > 0)
                return expireTimeout;
            return Config.notifTimeout;
        }

        // 1 → 0 while the popup is on screen (drives the timeout bar)
        property real timeLeft: 1

        readonly property NumberAnimation expireAnim: NumberAnimation {
            target: notif
            property: "timeLeft"
            from: 1
            to: 0
            duration: notif.timeout
            paused: running && notif.held
            onFinished: notif.hidePopup()
        }

        readonly property Timer exitTimer: Timer {
            interval: Config.animDuration
            onTriggered: notif.finishExit()
        }

        function showPopup() {
            exitTimer.stop();
            exiting = false;
            popup = true;
            expireAnim.stop();
            timeLeft = 1;
            if (timeout > 0)
                expireAnim.start();
            root.trimPopups();
        }

        function hidePopup() {
            if (!popup || exiting)
                return;
            expireAnim.stop();
            exiting = true;
            exitTimer.restart();
        }

        function finishExit() {
            exiting = false;
            popup = false;
            if (isTransient || closeAfterExit)
                close();
        }

        function invokeAction(action) {
            action.invoke();
            if (!resident)
                close();
            else
                hidePopup();
        }

        // Click on the notification body: default action if the app offers one
        function activate() {
            if (defaultAction)
                invokeAction(defaultAction);
            else
                hidePopup();
        }

        function sendReply(text: string) {
            notification?.sendInlineReply(text);
            if (!resident)
                close();
        }

        function close() {
            if (closed)
                return;
            // Let the popup slide out first
            if (popup) {
                closeAfterExit = true;
                hidePopup();
                return;
            }
            closed = true;
            expireAnim.stop();
            popup = false;
            root.list = root.list.filter(n => n !== notif);
            if (!dropped)
                notification?.dismiss();
            // Delayed so delegates showing it are gone before it becomes null
            destroy(Config.animDurationLong);
        }

        function refresh() {
            notifId = notification.id;
            appName = notification.appName || "System";
            summary = notification.summary || "";
            body = notification.body || "";

            // `notify-send -i` arrives as image://icon/<name or path>: a themed
            // name is really an icon, a path is a real image
            let img = notification.image || "";
            let iconHint = "";
            if (img.startsWith("image://icon/")) {
                const name = img.slice("image://icon/".length);
                img = name.startsWith("/") ? "file://" + name : "";
                iconHint = name.startsWith("/") ? "" : name;
            }
            image = img;

            const candidates = [iconHint, notification.appIcon, notification.desktopEntry, appName.toLowerCase()];
            appIcon = candidates.find(c => c && root.iconSource(c) !== "") ?? "";
            urgency = notification.urgency;
            resident = notification.resident;
            isTransient = notification.transient;
            hasActionIcons = notification.hasActionIcons;
            hasInlineReply = notification.hasInlineReply;
            inlineReplyPlaceholder = notification.inlineReplyPlaceholder || "";
            expireTimeout = notification.expireTimeout;
            actions = notification.actions.map(a => ({
                        "identifier": a.identifier,
                        "text": a.text,
                        "invoke": () => a.invoke()
                    }));

            const value = notification.hints?.value;
            progressValue = value !== undefined ? Math.max(0, Math.min(100, value)) : -1;
        }

        readonly property Connections conn: Connections {
            target: notif.notification

            // The app replaced the notification (same id): refresh and show it again
            function onSummaryChanged() {
                notif.replaced();
            }
            function onBodyChanged() {
                notif.replaced();
            }
            function onHintsChanged() {
                notif.replaced();
            }

            // Closed by the app, expired or dismissed elsewhere
            function onClosed() {
                notif.dropped = true;
                notif.close();
            }
        }

        function replaced() {
            // Several properties change in one update; handle it once
            Qt.callLater(() => {
                if (closed)
                    return;
                refresh();
                if (popup || (!root.dndEnabled || isCritical))
                    showPopup();
            });
        }

        Component.onCompleted: refresh()
    }

    // ========================================================================
    // IPC — qs ipc call notifications <function>
    // ========================================================================

    IpcHandler {
        target: "notifications"

        function toggleWindow(): void {
            root.windowToggleRequested();
        }

        function toggleDnd(): void {
            root.toggleDnd();
        }

        function clear(): void {
            root.clearAll();
        }
    }
}
