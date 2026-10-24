pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.config
import qs.services
import "../../../components/"
import "../../../services/network.js" as Net

Item {
    id: root

    // Height the page may use; the network list scrolls within what's left
    property real availableHeight: 0

    signal backRequested
    signal passwordRequested(string ssid)

    readonly property var current: NetworkService.activeNetwork
    readonly property var wired: NetworkService.wired
    readonly property var others: NetworkService.accessPoints.filter(ap => !ap.active)
    readonly property int rowHeight: Config.fontSizeIconSmall * 2 + Config.padding * 2

    Layout.fillWidth: true
    implicitHeight: main.implicitHeight

    // Fresh scan and connection details only while the page is open
    // The window creates the page when it's shown, so also on creation
    function refresh(): void {
        NetworkService.scan();
        NetworkService.fetchDetails();
    }
    onVisibleChanged: {
        if (visible)
            refresh();
    }

    // Faster signal updates while the page is shown
    Watcher {
        service: NetworkService
        hold: "watch"
        active: root.visible && (QsWindow.window?.visible ?? false)
    }
    Component.onCompleted: refresh()

    Connections {
        target: NetworkService

        function onActiveNetworkChanged() {
            if (root.visible)
                NetworkService.fetchDetails();
        }
    }

    function connectTo(ap) {
        if (ap.saved || !ap.secure)
            NetworkService.connect(ap.ssid, "");
        else
            root.passwordRequested(ap.ssid);
    }

    function describe(ap): string {
        const parts = [];
        if (ap.saved)
            parts.push(I18n.tr("Saved"));
        if (ap.band)
            parts.push(ap.band);
        if (!ap.secure)
            parts.push(I18n.trc("network", "Open"));
        return parts.join(" · ");
    }

    ColumnLayout {
        id: main

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Config.spacing

        PageHeader {
            id: header
            Layout.bottomMargin: Config.padding
            // With a cable the page is the network's: the cable, then Wi-Fi
            icon: root.wired ? NetworkService.wiredIcon : NetworkService.systemIcon
            title: root.wired ? I18n.tr("Network") : I18n.tr("Wi-Fi")
            subtitle: {
                if (root.wired) {
                    if (!NetworkService.wifiEnabled)
                        return I18n.tr("Wired · Wi-Fi off");
                    if (root.current)
                        return I18n.tr("Wired · Wi-Fi: %1", root.current.ssid || I18n.tr("hidden network"));
                    return I18n.tr("Wired");
                }
                if (!NetworkService.wifiEnabled)
                    return I18n.tr("Off");
                if (root.current)
                    return I18n.tr("Connected to %1", root.current.ssid || I18n.tr("hidden network"));
                return I18n.tr("Not connected");
            }
            onBackClicked: root.backRequested()

            // With a cable the Wi-Fi controls move to the Wi-Fi networks
            // card, so this switch doesn't read as the whole network's
            RefreshButton {
                visible: NetworkService.wifiEnabled && !root.wired
                size: header.boxSize
                loading: NetworkService.scanning
                onClicked: NetworkService.scan()
            }

            QsSwitch {
                visible: !root.wired
                checked: NetworkService.wifiEnabled
                onToggled: NetworkService.toggleWifi()
            }
        }

        // ========== CABLE ==========
        // Outlined like the connected network; nothing to switch here, the
        // ⋮ menu copies its IP
        Rectangle {
            id: wiredCard

            readonly property string ip: NetworkService.wiredDetails.ip ?? ""

            visible: root.wired !== null
            Layout.fillWidth: true
            implicitHeight: wiredRow.implicitHeight + Config.padding * 2
            radius: Config.radiusLarge
            color: Config.cardColor
            border.width: 2
            border.color: Qt.alpha(Config.accentColor, 0.6)

            DeviceRow {
                id: wiredRow

                anchors.fill: parent
                anchors.leftMargin: Config.padding * 2
                anchors.rightMargin: Config.padding * 2
                anchors.topMargin: Config.padding
                anchors.bottomMargin: Config.padding
                icon: NetworkService.wiredIcon
                ring: 100
                title: root.wired?.connection || I18n.tr("Wired")
                subtitle: {
                    const parts = [];
                    const speed = Net.speedLabel(NetworkService.wiredDetails.speed ?? 0);
                    if (speed !== "")
                        parts.push(speed);
                    parts.push(wiredCard.ip !== "" ? wiredCard.ip : I18n.tr("Connected"));
                    return parts.join(" · ");
                }
                menuModel: wiredCard.ip !== "" ? [
                    {
                        "text": I18n.tr("Copy IP"),
                        "icon": "\u{f018f}", // md-content_copy
                        "action": "copyIp"
                    }
                ] : []
                onMenuAction: action => {
                    if (action === "copyIp")
                        Quickshell.execDetached(["wl-copy", "--", wiredCard.ip]);
                }
            }
        }

        // ========== CONNECTED NETWORK ==========
        // Outlined so the active network stands out from the list below;
        // its actions are in the ⋮ menu
        Rectangle {
            id: connectedCard

            readonly property bool portal: NetworkService.hasCaptivePortal
            readonly property color accent: portal ? Config.warningColor : Config.accentColor
            readonly property string ip: NetworkService.details.ip ?? ""

            visible: NetworkService.wifiEnabled && root.current !== null
            Layout.fillWidth: true
            implicitHeight: connectedRow.implicitHeight + Config.padding * 2
            radius: Config.radiusLarge
            color: Config.cardColor
            border.width: 2
            border.color: Qt.alpha(accent, 0.6)

            Behavior on border.color {
                enabled: !Config.themeTransitioning
                ColorAnimation {
                    duration: Config.animDuration
                }
            }

            DeviceRow {
                id: connectedRow

                anchors.fill: parent
                anchors.leftMargin: Config.padding * 2
                anchors.rightMargin: Config.padding * 2
                anchors.topMargin: Config.padding
                anchors.bottomMargin: Config.padding
                icon: NetworkService.systemIcon
                ring: root.current?.signal ?? 0
                ringColor: connectedCard.accent
                title: root.current?.ssid || I18n.tr("Hidden network")
                subtitle: {
                    if (!root.current)
                        return "";
                    const parts = [];
                    if (connectedCard.portal)
                        parts.push(I18n.tr("Login required"));
                    if (root.current.band)
                        parts.push(root.current.band);
                    parts.push(connectedCard.ip !== "" ? connectedCard.ip : I18n.tr("Connected"));
                    return parts.join(" · ");
                }
                trailing: (root.current?.signal ?? 0) + "%"
                onClicked: NetworkService.disconnect()
                menuModel: {
                    const items = [];
                    if (connectedCard.portal)
                        items.push({
                            text: I18n.tr("Log in"),
                            icon: "\u{f059f}", // md-web
                            action: "login"
                        });
                    items.push({
                        text: I18n.tr("Disconnect"),
                        icon: "\u{f05aa}", // md-wifi_off
                        action: "disconnect"
                    });
                    if (connectedCard.ip !== "")
                        items.push({
                            text: I18n.tr("Copy IP"),
                            icon: "\u{f018f}", // md-content_copy
                            action: "copyIp"
                        });
                    items.push({
                        text: I18n.tr("Forget"),
                        icon: "\u{f01b4}", // md-delete
                        action: "forget",
                        color: Config.errorColor
                    });
                    return items;
                }
                onMenuAction: action => {
                    if (action === "login")
                        NetworkService.openPortalBrowser();
                    else if (action === "disconnect")
                        NetworkService.disconnect();
                    else if (action === "copyIp")
                        Quickshell.execDetached(["wl-copy", "--", connectedCard.ip]);
                    else if (action === "forget")
                        NetworkService.forget(root.current.ssid);
                }
            }
        }

        // ========== AVAILABLE NETWORKS ==========
        Card {
            id: networksCard

            visible: NetworkService.wifiEnabled
            Layout.fillWidth: true

            CardHeader {
                id: networksHeader
                icon: "󰖩"
                title: root.wired ? I18n.tr("Wi-Fi networks") : I18n.tr("Networks")
                subtitle: NetworkService.scanning && root.others.length === 0 ? I18n.tr("Scanning…") : I18n.trn("%n available", "%n available", root.others.length)

                RefreshButton {
                    visible: root.wired !== null
                    size: header.boxSize
                    loading: NetworkService.scanning
                    onClicked: NetworkService.scan()
                }

                QsSwitch {
                    visible: root.wired !== null
                    checked: NetworkService.wifiEnabled
                    onToggled: NetworkService.toggleWifi()
                }
            }

            Flickable {
                id: list

                // Whatever the page has left, but always room for a few rows
                readonly property real maxHeight: {
                    const used = header.implicitHeight + header.Layout.bottomMargin + main.spacing + (connectedCard.visible ? connectedCard.implicitHeight + main.spacing : 0) + (wiredCard.visible ? wiredCard.implicitHeight + main.spacing : 0) + networksCard.padding * 2 + networksHeader.implicitHeight + networksCard.spacing;
                    return Math.max(root.rowHeight * 3, root.availableHeight - used);
                }

                visible: root.others.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(rows.implicitHeight, maxHeight)
                contentHeight: rows.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ScrollBar.vertical: QsScrollBar {}

                Column {
                    id: rows

                    // Room for the hover highlight, which bleeds past the row
                    x: Config.padding
                    width: list.width - Config.padding * 2

                    Repeater {
                        model: root.others

                        DeviceRow {
                            required property var modelData

                            width: rows.width
                            icon: NetworkService.getWifiIcon(modelData.signal)
                            title: modelData.ssid
                            subtitle: connecting ? I18n.tr("Connecting…") : root.describe(modelData)
                            secured: modelData.secure && !modelData.saved
                            connecting: NetworkService.connectingSsid === modelData.ssid
                            menuModel: modelData.saved ? [
                                {
                                    "text": I18n.tr("Connect"),
                                    "icon": "󰖩",
                                    "action": "connect"
                                },
                                {
                                    "text": I18n.tr("Forget"),
                                    "icon": "󰆴",
                                    "action": "forget",
                                    "color": Config.errorColor
                                }
                            ] : []

                            onClicked: root.connectTo(modelData)
                            onMenuAction: action => {
                                if (action === "connect")
                                    root.connectTo(modelData);
                                else if (action === "forget")
                                    NetworkService.forget(modelData.ssid);
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.others.length === 0
                Layout.fillWidth: true
                Layout.topMargin: Config.spacing
                Layout.bottomMargin: Config.spacing
                horizontalAlignment: Text.AlignHCenter
                text: NetworkService.scanning ? I18n.tr("Looking for networks…") : I18n.tr("No other networks found")
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
            }
        }

        // ========== WI-FI OFF ==========
        Card {
            visible: !NetworkService.wifiEnabled
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Config.spacing * 2
                Layout.bottomMargin: Config.spacing * 2
                spacing: Config.spacing

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Config.fontSizeIconLarge * 2
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: Config.surface1Color

                    Text {
                        anchors.centerIn: parent
                        text: "󰤮"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconLarge
                        color: Config.subtextColor
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: I18n.tr("Wi-Fi is off")
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    font.bold: true
                    color: Config.textColor
                }

                ActionButton {
                    Layout.alignment: Qt.AlignHCenter
                    size: header.boxSize
                    icon: "󰖩"
                    text: I18n.tr("Turn on")
                    baseColor: Config.accentColor
                    hoverColor: Qt.lighter(Config.accentColor, 1.1)
                    textColor: Config.textReverseColor
                    onClicked: NetworkService.toggleWifi()
                }
            }
        }
    }
}
