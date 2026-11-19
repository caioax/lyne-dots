pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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

    // History entries: one per conversation (app + summary, so each sender
    // of a chat), ordered by their newest notification
    readonly property var conversationKeys: {
        const keys = [];
        for (const n of list) {
            const key = conversationKey(n);
            if (!keys.includes(key))
                keys.push(key);
        }
        return keys;
    }

    readonly property int count: list.length
    readonly property int activePopupCount: popups.length

    property bool dndEnabled: StateService.get("notifications.dnd", false)

    // Screen the history popup (the bar's bell) is open on, "" = closed.
    // Each bar has its own NotificationsWindow that shows itself while this
    // names its screen
    property string historyScreen: ""
    readonly property bool historyOpen: historyScreen !== ""
    // Conversation the history opens on (expanded and scrolled to), from a
    // click on its popup; "" = the top
    property string focusKey: ""

    // Conversations with a message newer than the last look at the history
    // (the bell's badge); none while it is open
    readonly property int unseenCount: {
        if (historyOpen)
            return 0;
        const since = seen.at;
        const counted = [];
        let unseen = 0;
        // Newest first, so a conversation's first entry is its newest message
        for (const n of list) {
            const key = conversationKey(n);
            if (counted.includes(key))
                continue;
            counted.push(key);
            if (n.time.getTime() > since)
                unseen++;
        }
        return unseen;
    }

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

    // The popups step aside while it is open: they sit in the same corner,
    // and the history shows them anyway
    function openHistory(screenName: string): void {
        markSeen();
        for (const n of popups)
            n.hidePopup();
        historyScreen = screenName;
    }

    function closeHistory(): void {
        // What arrived while it was open was seen too
        if (historyOpen)
            markSeen();
        historyScreen = "";
        focusKey = "";
    }

    // Opens the history on a conversation (a click on its popup)
    function showConversation(key: string, screenName: string): void {
        focusKey = key;
        if (historyScreen !== screenName)
            openHistory(screenName);
    }

    // Closes it when open on that screen, otherwise opens or moves it there
    function toggleHistory(screenName: string): void {
        if (historyScreen === screenName)
            closeHistory();
        else
            openHistory(screenName);
    }

    function markSeen(): void {
        seen.at = Date.now();
    }

    function conversationKey(n: var): string {
        return n.appName + "\n" + n.summary;
    }

    // Newest first
    function conversationOf(key: string): var {
        return list.filter(n => conversationKey(n) === key);
    }

    // <img> in a notification's text: only local files are shown. A remote
    // src would be fetched by the shell (a tracking pixel for the sender)
    function stripRemoteImages(text: string): string {
        if (!text.includes("<img"))
            return text;
        // An expression arrow: a block one makes qmllint skip the whole file
        return text.replace(/<img\b[^>]*>/gi, tag => root._localImage(tag) ? tag : "");
    }

    function _localImage(tag: string): bool {
        const src = tag.match(/\bsrc\s*=\s*["']?([^"'\s>]*)/i)?.[1] ?? "";
        return /^(file:\/\/|\/)/i.test(src);
    }

    function dismissConversation(key: string) {
        for (const n of conversationOf(key))
            n.close();
    }

    function clearAll() {
        for (const n of list.slice())
            n.close();
    }

    // "now", "5m", "2h", "3d" — re-evaluated every minute through TimeService,
    // against the real time: TimeService.date stays at the minute's start, so
    // it read up to a minute short
    function relativeTime(time: date): string {
        void TimeService.date;
        const minutes = Math.floor((Date.now() - time.getTime()) / 60000);
        if (minutes < 1)
            return I18n.trc("time", "now");
        if (minutes < 60)
            return I18n.tr("%1m", minutes);
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
        return IconService.has(icon) ? IconService.url(icon, "") : "";
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
            // Restored after a reload: keeps the time it arrived, not "now"
            const saved = notif.lastGeneration ? root._times()[notif.id] : undefined;
            const data = notifComponent.createObject(root, {
                "notification": notif,
                "time": saved ? new Date(saved) : new Date()
            });
            root._setTime(data.notifId, data.time.getTime());

            // The earlier message of this conversation, just closed by the
            // app, stays as a copy
            if (data.chat) {
                for (const n of root.list.filter(n => n.nextTimer.running && n.appName === data.appName && n.summary === data.summary))
                    n.becomeCopyOf(data.notifId);
            }

            root.list = [data, ...root.list];
            // Its earlier messages come back with it, in time order
            if (notif.lastGeneration) {
                for (const c of root._copies().filter(c => c.sourceId === notif.id))
                    root._createCopy(c);
                root._sortList();
            }
            root._trimHistory();

            // Notifications restored after a reload go straight to history,
            // and so do new ones while it is open (critical ones still pop up)
            if (!notif.lastGeneration && (critical || (!root.dndEnabled && !root.historyOpen)))
                data.showPopup();
            else if (data.isTransient)
                data.close();
        }
    }

    // When the history was last looked at, kept across reloads
    PersistentProperties {
        id: seen
        reloadableId: "notificationSeen"

        property real at: 0
    }

    // Arrival times by notification id, kept across reloads (the history is
    // rebuilt then). JSON: a JS object doesn't survive the reload
    PersistentProperties {
        id: kept
        reloadableId: "notificationTimes"

        property string times: "{}"
    }

    function _times(): var {
        try {
            return JSON.parse(kept.times);
        } catch (e) {
            return {};
        }
    }

    function _setTime(id: int, ms: real): void {
        const times = _times();
        if (ms > 0)
            times[id] = ms;
        else
            delete times[id];
        kept.times = JSON.stringify(times);
    }

    // Earlier messages of a replaced chat notification (see _applyReplace):
    // frozen copies, kept across reloads as JSON like the times
    PersistentProperties {
        id: keptCopies
        reloadableId: "notificationCopies"

        property string copies: "[]"
    }

    function _copies(): var {
        try {
            return JSON.parse(keptCopies.copies);
        } catch (e) {
            return [];
        }
    }

    function _copyKey(c: var): string {
        return c.sourceId + ":" + c.time;
    }

    // Added and removed one by one (not rewritten from the list): during a
    // reload's restore the list doesn't hold everyone's copies yet
    function _keepCopy(c: var, keep: bool): void {
        const copies = _copies().filter(other => _copyKey(other) !== _copyKey(c));
        if (keep)
            copies.push(c);
        keptCopies.copies = JSON.stringify(copies);
    }

    // How long a chat notification closed by its app waits for the next
    // message (Chromium sends it within a few ms)
    readonly property int nextMessageWindow: 1000

    function _snapshot(n: var): var {
        return {
            "sourceId": n.frozen ? n.sourceId : n.notifId,
            "time": n.time.getTime(),
            "appName": n.appName,
            "appIcon": n.appIcon,
            "summary": n.summary,
            "body": n.body,
            "image": n.image,
            "urgency": n.urgency
        };
    }

    function _createCopy(c: var): void {
        const copy = notifComponent.createObject(root, {
            "notification": null,
            "frozen": true,
            "sourceId": c.sourceId,
            "time": new Date(c.time),
            "appName": c.appName,
            "appIcon": c.appIcon,
            "summary": c.summary,
            "body": c.body,
            "image": c.image,
            "urgency": c.urgency
        });
        list = [...list, copy];
    }

    // Newest first
    function _sortList(): void {
        list = list.slice().sort((a, b) => b.time.getTime() - a.time.getTime());
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

        // null for a frozen copy
        required property Notification notification
        // Frozen copy of an earlier message: text only (no actions or reply),
        // gone with its source when the app closes it
        property bool frozen: false
        // Copy: notifId of the notification it was taken from
        property int sourceId: -1
        // A chat: a replacement is a new message, the earlier one stays
        property bool chat: false

        // When it arrived, or when the app last replaced it with news
        property date time: new Date()
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
        // Where every action is offered (history rows, their menu): the
        // default one first, unless a button already carries its label (the
        // update notification sends "Details" as both)
        readonly property var listedActions: defaultAction && !buttonActions.some(a => a.text === defaultAction.text) ? [defaultAction, ...buttonActions] : buttonActions

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

        // Closed by a chat app: kept as an earlier message if the next one
        // of the conversation arrives now, gone otherwise (the chat was opened)
        readonly property Timer nextTimer: Timer {
            interval: root.nextMessageWindow
            onTriggered: notif.close()
        }

        function awaitNext() {
            hidePopup();
            nextTimer.restart();
        }

        // Turns into a frozen copy of the newer notification `id`, taking its
        // own copies along
        function becomeCopyOf(id: int) {
            nextTimer.stop();
            for (const c of root.list.filter(c => c.frozen && c.sourceId === notifId)) {
                root._keepCopy(root._snapshot(c), false);
                c.sourceId = id;
                root._keepCopy(root._snapshot(c), true);
            }
            root._setTime(notifId, 0);
            frozen = true;
            sourceId = id;
            actions = [];
            hasInlineReply = false;
            root._keepCopy(root._snapshot(notif), true);
        }

        function showPopup() {
            // One popup per conversation: the newest message takes the place
            // of the one before (it shows the earlier ones when opened)
            const key = root.conversationKey(notif);
            for (const other of root.popups) {
                if (other !== notif && root.conversationKey(other) === key)
                    other.hidePopup();
            }
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
            if (frozen) {
                root._keepCopy({
                    "sourceId": sourceId,
                    "time": time.getTime()
                }, false);
            } else {
                root._setTime(notifId, 0);
                // Its earlier messages go too, whoever closed it: they only
                // come back with it after a reload
                for (const c of root.list.filter(c => c.frozen && c.sourceId === notifId))
                    c.close();
            }
            expireAnim.stop();
            popup = false;
            root.list = root.list.filter(n => n !== notif);
            if (!dropped)
                notification?.dismiss();
            // Delayed so delegates showing it are gone before it becomes null
            destroy(Config.animDurationLong);
        }

        function refresh() {
            if (frozen)
                return;
            notifId = notification.id;
            appName = notification.appName || I18n.tr("System");
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
            summary = root.stripRemoteImages(summary);
            body = root.stripRemoteImages(body);

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

            const category = notification.hints?.category ?? "";
            chat = site !== null || category.startsWith("im") || hasInlineReply;

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
                // Chromium closes a chat's notification right before sending
                // the next message as a new one: wait for it (see onNotification)
                if (notif.chat && !notif.frozen)
                    notif.awaitNext();
                else
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
            const before = root._snapshot(notif);
            const summaryBefore = summary;
            const bodyBefore = body;
            refresh();
            // On screen: the new content gets a full timeout. Dismissed or
            // expired: only news brings it back (a new title, or new text
            // without a progress bar), not each step of a download
            const news = summary !== summaryBefore || (body !== bodyBefore && progressValue < 0);
            if (news) {
                time = new Date();
                root._setTime(notifId, time.getTime());
                // A chat keeps the earlier message as its own row
                if (chat) {
                    root._createCopy(before);
                    root._keepCopy(before, true);
                }
                root._sortList();
                root._trimHistory();
            }
            // Like a new one: not while the history is open (critical ones
            // still pop up)
            if (popup || (news && (isCritical || (!root.dndEnabled && !root.historyOpen))))
                showPopup();
        }

        Component.onCompleted: refresh()
    }

    // ========================================================================
    // IPC — qs ipc call notifications <function>
    // ========================================================================

    IpcHandler {
        target: "notifications"

        // The history popup, on the focused screen
        function toggleWindow(): void {
            root.toggleHistory(Hyprland.focusedMonitor?.name ?? "");
        }

        function toggleDnd(): void {
            root.toggleDnd();
        }

        function clear(): void {
            root.clearAll();
        }
    }
}
