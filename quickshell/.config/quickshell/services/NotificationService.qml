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

        function onStateLoaded(keys) {
            if (keys.includes("notifications"))
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
            root._trimHistory();

            // Notifications restored after a reload go straight to history
            if (!notif.lastGeneration && (critical || !root.dndEnabled))
                data.showPopup();
            else if (data.isTransient)
                data.close();
        }
    }

    // History kept: older notifications go, except resident ones and those
    // still on screen (each holds its D-Bus object and image)
    readonly property int historyMax: 100

    function _trimHistory(): void {
        let extra = list.length - historyMax;
        for (let i = list.length - 1; i >= 0 && extra > 0; i--) {
            const n = list[i];
            if (n.resident || n.popup)
                continue;
            n.close();
            extra--;
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

            // Chromium web apps (the WhatsApp special) send as "Chromium" with a
            // link to the site on top of the body and the page's picture as the
            // app icon: name them after their special (or the site), drop the
            // link and show the picture as the image
            let appIconHint = notification.appIcon;
            const site = notification.desktopEntry === "chromium" ? body.match(/^<a href="https?:\/\/([^/"]+)\/?">[^<]*<\/a>\s*/) : null;
            if (site) {
                const host = site[1];
                // Chromium names an app window chrome-<site>__-Default
                const special = SpecialsService.list.find(s => {
                    try {
                        return (s.class ?? "") !== "" && new RegExp(s.class).test("chrome-" + host + "__-Default");
                    } catch (e) {
                        return false;
                    }
                });
                appName = special?.name ?? host;
                body = body.slice(site[0].length);
                iconHint = iconHint || host.split(".").slice(-2, -1)[0];
                img = img || appIconHint;
                appIconHint = "";
            }
            image = img;

            const candidates = [iconHint, appIconHint, notification.desktopEntry, appName.toLowerCase()];
            appIcon = candidates.find(c => c && root.iconSource(c) !== "") ?? "";
            urgency = notification.urgency;
            resident = notification.resident;
            isTransient = notification.transient;
            hasActionIcons = notification.hasActionIcons;
            hasInlineReply = notification.hasInlineReply;
            inlineReplyPlaceholder = notification.inlineReplyPlaceholder || "";
            expireTimeout = notification.expireTimeout;
            // Chromium's Settings button opens its own notification settings
            actions = notification.actions.filter(a => !(site && a.identifier === "settings")).map(a => ({
                        "identifier": a.identifier,
                        "text": a.text,
                        "invoke": () => a.invoke()
                    }));

            const value = notification.hints?.value;
            progressValue = value !== undefined ? Math.max(0, Math.min(100, value)) : -1;
        }

        readonly property Connections conn: Connections {
            target: notif.notification

            // The app replaced the notification (same id)
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
            // Summary, body and hints change in one update: callLater with
            // the same function runs it once
            Qt.callLater(notif._applyReplace);
        }

        function _applyReplace() {
            if (closed)
                return;
            const summaryBefore = summary;
            const bodyBefore = body;
            refresh();
            // On screen: the new content gets a full timeout. Dismissed or
            // expired: only news brings it back (a new title, or new text
            // without a progress bar), not each step of a download
            const news = summary !== summaryBefore || (body !== bodyBefore && progressValue < 0);
            if (popup || (news && (!root.dndEnabled || isCritical)))
                showPopup();
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
