pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import "../../../components/"

Item {
    id: root

    // Height the page may use; the network list scrolls within what's left
    property real availableHeight: 0

    signal backRequested
    signal passwordRequested(string ssid)

    readonly property var current: NetworkService.activeNetwork
    readonly property var others: NetworkService.accessPoints.filter(ap => !ap.active)
    readonly property int rowHeight: Config.fontSizeIconSmall * 2 + Config.padding * 2

    Layout.fillWidth: true
    implicitHeight: main.implicitHeight

    // Fresh scan and connection details only while the page is open
    onVisibleChanged: {
        if (visible) {
            NetworkService.scan();
            NetworkService.fetchDetails();
        }
    }

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
            parts.push("Saved");
        if (ap.band)
            parts.push(ap.band);
        if (!ap.secure)
            parts.push("Open");
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
            icon: NetworkService.systemIcon
            title: "Wi-Fi"
            subtitle: {
                if (!NetworkService.wifiEnabled)
                    return "Off";
                if (root.current)
                    return "Connected to " + (root.current.ssid || "hidden network");
                return "Not connected";
            }
            onBackClicked: root.backRequested()

            RefreshButton {
                visible: NetworkService.wifiEnabled
                size: header.boxSize
                loading: NetworkService.scanning
                onClicked: NetworkService.scan()
            }

            QsSwitch {
                checked: NetworkService.wifiEnabled
                onToggled: NetworkService.toggleWifi()
            }
        }

        // ========== CONNECTED NETWORK ==========
        Card {
            id: connectedCard

            visible: NetworkService.wifiEnabled && root.current !== null
            Layout.fillWidth: true

            readonly property bool portal: NetworkService.hasCaptivePortal
            readonly property color accent: portal ? Config.warningColor : Config.accentColor

            // Outline so the active network stands out from the list below
            border.width: 1
            border.color: Qt.alpha(accent, 0.6)

            Behavior on border.color {
                ColorAnimation {
                    duration: Config.animDuration
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Config.spacing + Config.padding

                // Signal strength ring
                ProgressRing {
                    Layout.preferredWidth: Config.fontSizeIconSmall * 2 + Config.padding * 2
                    Layout.preferredHeight: Layout.preferredWidth
                    value: root.current?.signal ?? 0
                    strokeWidth: Math.round(Config.padding * 2 / 3)
                    color: connectedCard.accent

                    Text {
                        anchors.centerIn: parent
                        text: NetworkService.systemIcon
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconSmall
                        color: connectedCard.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: root.current?.ssid || "Hidden network"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        font.bold: true
                        color: Config.textColor
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!root.current)
                                return "";
                            const parts = [connectedCard.portal ? "Login required" : "Connected"];
                            if (root.current.band)
                                parts.push(root.current.band);
                            parts.push(root.current.securityType);
                            return parts.join(" · ");
                        }
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: connectedCard.portal ? Config.warningColor : Config.subtextColor
                        elide: Text.ElideRight
                    }
                }

                Text {
                    text: (root.current?.signal ?? 0) + "%"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: Config.subtextColor
                }
            }

            // IP / gateway
            Flow {
                visible: (NetworkService.details.ip ?? "") !== ""
                Layout.fillWidth: true
                spacing: Config.padding

                StatChip {
                    icon: "󰩟"
                    text: NetworkService.details.ip ?? ""
                }

                StatChip {
                    visible: (NetworkService.details.gateway ?? "") !== ""
                    icon: "󰑩"
                    text: NetworkService.details.gateway ?? ""
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Config.spacing

                ActionButton {
                    visible: connectedCard.portal
                    Layout.fillWidth: true
                    size: header.boxSize
                    icon: "󰖟"
                    text: "Log in"
                    baseColor: Config.warningColor
                    hoverColor: Qt.lighter(Config.warningColor, 1.1)
                    textColor: Config.textReverseColor
                    onClicked: NetworkService.openPortalBrowser()
                }

                ActionButton {
                    Layout.fillWidth: true
                    size: header.boxSize
                    icon: "󰖪"
                    text: "Disconnect"
                    onClicked: NetworkService.disconnect()
                }

                ActionButton {
                    Layout.fillWidth: true
                    size: header.boxSize
                    icon: "󰆴"
                    text: "Forget"
                    textColor: Config.errorColor
                    onClicked: NetworkService.forget(root.current.ssid)
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
                title: "Networks"
                subtitle: NetworkService.scanning && root.others.length === 0 ? "Scanning…" : root.others.length + " available"
            }

            Flickable {
                id: list

                // Whatever the page has left, but always room for a few rows
                readonly property real maxHeight: {
                    const used = header.implicitHeight + header.Layout.bottomMargin + main.spacing + (connectedCard.visible ? connectedCard.implicitHeight + main.spacing : 0) + networksCard.padding * 2 + networksHeader.implicitHeight + networksCard.spacing;
                    return Math.max(root.rowHeight * 3, root.availableHeight - used);
                }

                visible: root.others.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(rows.implicitHeight, maxHeight)
                contentHeight: rows.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded

                    contentItem: Rectangle {
                        implicitWidth: Math.round(Config.padding * 2 / 3)
                        radius: width / 2
                        color: Config.surface2Color
                        opacity: parent.active ? 0.8 : 0
                    }
                }

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
                            subtitle: connecting ? "Connecting…" : root.describe(modelData)
                            secured: modelData.secure && !modelData.saved
                            connecting: NetworkService.connectingSsid === modelData.ssid
                            menuModel: modelData.saved ? [
                                {
                                    "text": "Connect",
                                    "icon": "󰖩",
                                    "action": "connect"
                                },
                                {
                                    "text": "Forget",
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
                text: NetworkService.scanning ? "Looking for networks…" : "No other networks found"
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
                    text: "Wi-Fi is off"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    font.bold: true
                    color: Config.textColor
                }

                ActionButton {
                    Layout.alignment: Qt.AlignHCenter
                    size: header.boxSize
                    icon: "󰖩"
                    text: "Turn on"
                    baseColor: Config.accentColor
                    hoverColor: Qt.lighter(Config.accentColor, 1.1)
                    textColor: Config.textReverseColor
                    onClicked: NetworkService.toggleWifi()
                }
            }
        }
    }
}
