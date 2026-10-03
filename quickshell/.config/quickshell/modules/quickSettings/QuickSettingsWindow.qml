pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services
import "../../components/"
import "./pages/"

// One per bar; shows itself while QuickSettingsService is open on its
// screen. Pages slide sideways (forward when going deeper) and the panel
// follows the height of the current one
QsPopupWindow {
    id: root

    readonly property bool wanted: QuickSettingsService.screen !== "" && QuickSettingsService.screen === (screen?.name ?? "")

    // Page this window shows; follows QuickSettingsService.page while open
    // here, so the other screens' windows don't switch along
    property string shownPage: ""
    // Page fading out while `slide` runs
    property string leavingPage: ""

    readonly property var slots: ({
            "": mainSlot,
            wifi: wifiSlot,
            wifiPassword: wifiPasswordSlot,
            bluetooth: bluetoothSlot,
            nightLight: nightLightSlot,
            sound: soundSlot,
            notifications: notificationsSlot
        })

    popupWidth: Config.fontSizeNormal * 30
    // Up to the screen's free height, so the notifications preview fits
    popupMaxHeight: screen ? screen.height - Config.barReservedHeight - Config.spacing * 2 : 820
    anchorSide: "right"
    moduleName: "QuickSettings"
    contentImplicitHeight: (slots[shownPage] ?? mainSlot).implicitHeight
    keyTargets: [keyHandler]
    visible: false

    onWantedChanged: {
        if (!wanted)
            closeWindow();
    }

    // Closed from the popup itself (Escape, a click outside)
    onClosing: {
        if (wanted)
            QuickSettingsService.close();
        slide.stop();
        shownPage = "";
        mainPage.pickedMonitor = null;
        // Still open on another screen: that one keeps its page
        if (QuickSettingsService.screen === "")
            QuickSettingsService.page = "";
    }

    function goTo(page: string) {
        if (page === shownPage)
            return;
        slide.stop();
        if (!visible || isClosing) {
            shownPage = page;
            return;
        }
        slide.forward = QuickSettingsService.depth(page) >= QuickSettingsService.depth(shownPage);
        slide.fromSlot = slots[shownPage] ?? mainSlot;
        slide.toSlot = slots[page] ?? mainSlot;
        // Running before the swap, so the leaving page never hides in between
        slide.start();
        leavingPage = shownPage;
        shownPage = page;
    }

    Connections {
        target: QuickSettingsService

        function onShown() {
            if (!root.wanted)
                return;
            root.goTo(QuickSettingsService.page);
            root.reopen();
        }

        function onPageChanged() {
            if (root.wanted)
                root.goTo(QuickSettingsService.page);
        }
    }

    // Escape on a sub-page goes back instead of closing
    Item {
        id: keyHandler

        Keys.onEscapePressed: event => {
            if (root.shownPage === "") {
                event.accepted = false;
                return;
            }
            QuickSettingsService.back();
        }
    }

    // Short sideways move plus a fade, like the Settings pages
    ParallelAnimation {
        id: slide

        property bool forward: true
        property Item fromSlot
        property Item toSlot
        readonly property real offset: Config.spacing * 3

        onStopped: {
            if (fromSlot) {
                fromSlot.x = 0;
                fromSlot.opacity = 1;
            }
            if (toSlot) {
                toSlot.x = 0;
                toSlot.opacity = 1;
            }
        }

        NumberAnimation {
            target: slide.toSlot
            property: "x"
            from: slide.forward ? slide.offset : -slide.offset
            to: 0
            duration: Config.animDuration
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: slide.toSlot
            property: "opacity"
            from: 0
            to: 1
            duration: Config.animDuration
        }

        NumberAnimation {
            target: slide.fromSlot
            property: "x"
            from: 0
            to: slide.forward ? -slide.offset : slide.offset
            duration: Config.animDuration
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: slide.fromSlot
            property: "opacity"
            from: 1
            to: 0
            duration: Config.animDurationShort
        }
    }

    // A page; shown while current or sliding out
    component PageSlot: Item {
        id: slot

        required property string pageId
        default property alias page: holder.data

        width: parent?.width ?? 0
        implicitHeight: holder.childrenRect.height
        visible: root.shownPage === pageId || (slide.running && root.leavingPage === pageId)

        Item {
            id: holder
            width: parent.width
        }
    }

    Item {
        anchors.fill: parent

        PageSlot {
            id: mainSlot
            pageId: ""

            DashboardPage {
                id: mainPage
                width: parent.width
                availableHeight: root.contentMaxHeight
                onCloseWindow: root.closeWindow()
            }
        }

        PageSlot {
            id: wifiSlot
            pageId: "wifi"

            WifiPage {
                width: parent.width
                availableHeight: root.contentMaxHeight
                onBackRequested: QuickSettingsService.back()
                onPasswordRequested: ssid => {
                    wifiPasswordPage.targetSsid = ssid;
                    QuickSettingsService.showPage("wifiPassword");
                }
            }
        }

        PageSlot {
            id: wifiPasswordSlot
            pageId: "wifiPassword"

            WifiPasswordPage {
                id: wifiPasswordPage
                width: parent.width
                onCancelled: QuickSettingsService.back()
                onConnectClicked: password => {
                    NetworkService.connect(targetSsid, password);
                    QuickSettingsService.back();
                }
            }
        }

        PageSlot {
            id: bluetoothSlot
            pageId: "bluetooth"

            BluetoothPage {
                width: parent.width
                availableHeight: root.contentMaxHeight
                onBackRequested: QuickSettingsService.back()
            }
        }

        PageSlot {
            id: nightLightSlot
            pageId: "nightLight"

            NightLightPage {
                width: parent.width
                onBackRequested: QuickSettingsService.back()
            }
        }

        PageSlot {
            id: soundSlot
            pageId: "sound"

            SoundPage {
                width: parent.width
                onBackRequested: QuickSettingsService.back()
            }
        }

        PageSlot {
            id: notificationsSlot
            pageId: "notifications"

            NotificationsPage {
                width: parent.width
                availableHeight: root.contentMaxHeight
                onBackRequested: QuickSettingsService.back()
                onCloseWindow: root.closeWindow()
            }
        }
    }
}
