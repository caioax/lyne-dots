pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import "../../../components/"

Item {
    id: root

    // Height the page may use; the list of found devices scrolls within what's left
    property real availableHeight: 0

    signal backRequested

    readonly property var devices: BluetoothService.devicesList
    readonly property var connected: devices.filter(d => d.connected)
    readonly property var known: devices.filter(d => !d.connected && BluetoothService.isKnown(d))
    readonly property var found: devices.filter(d => !d.connected && !BluetoothService.isKnown(d))
    readonly property int rowHeight: Config.fontSizeIconSmall * 2 + Config.padding * 2

    Layout.fillWidth: true
    implicitHeight: main.implicitHeight

    // Look for devices while the page is open
    onVisibleChanged: {
        if (visible && BluetoothService.isPowered && !BluetoothService.isDiscovering)
            BluetoothService.toggleScan();
    }

    function status(device): string {
        if (device.pairing)
            return "Pairing…";
        if (BluetoothService.getIsConnecting(device))
            return "Connecting…";
        const kind = BluetoothService.deviceKind(device).label;
        if (device.connected)
            return "Connected · " + kind;
        return BluetoothService.isKnown(device) ? "Paired · " + kind : kind;
    }

    ColumnLayout {
        id: main

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Config.spacing

        // Everything above the found list, measured to size that list
        ColumnLayout {
            id: top

            Layout.fillWidth: true
            spacing: Config.spacing

            PageHeader {
                id: header
                Layout.bottomMargin: Config.padding
                icon: BluetoothService.systemIcon
                title: "Bluetooth"
                subtitle: {
                    if (!BluetoothService.isPowered)
                        return "Off";
                    if (BluetoothService.isDiscoverable)
                        return "Visible as " + (BluetoothService.adapter?.name ?? "this computer");
                    if (root.connected.length > 0)
                        return BluetoothService.statusText;
                    return "Not connected";
                }
                onBackClicked: root.backRequested()

                RefreshButton {
                    visible: BluetoothService.isPowered
                    size: header.boxSize
                    loading: BluetoothService.isDiscovering
                    onClicked: BluetoothService.toggleScan()
                }

                // Visible to other devices
                ActionButton {
                    visible: BluetoothService.isPowered
                    size: header.boxSize
                    icon: BluetoothService.isDiscoverable ? "󰈈" : "󰈉"
                    iconSize: Config.fontSizeLarge
                    baseColor: BluetoothService.isDiscoverable ? Config.accentColor : Config.surface1Color
                    hoverColor: BluetoothService.isDiscoverable ? Qt.lighter(Config.accentColor, 1.1) : Config.surface2Color
                    textColor: BluetoothService.isDiscoverable ? Config.textReverseColor : Config.textColor
                    onClicked: BluetoothService.toggleDiscoverable()
                }

                QsSwitch {
                    checked: BluetoothService.isPowered
                    onToggled: {
                        if (!BluetoothService.isPowered)
                            scanAfterPowerOn.restart();
                        BluetoothService.togglePower();
                    }
                }

                // The adapter needs a moment after powering on before it can scan
                Timer {
                    id: scanAfterPowerOn
                    interval: Config.animDurationLong
                    onTriggered: {
                        if (!BluetoothService.isDiscovering)
                            BluetoothService.toggleScan();
                    }
                }
            }

            // ========== CONNECTED DEVICES ==========
            Repeater {
                model: BluetoothService.isPowered ? root.connected : []

                // Outlined so it stands out from the lists below; its
                // actions are in the ⋮ menu
                Rectangle {
                    id: connectedCard

                    required property var modelData
                    readonly property bool hasBattery: modelData.batteryAvailable

                    Layout.fillWidth: true
                    implicitHeight: connectedRow.implicitHeight + Config.padding * 2
                    radius: Config.radiusLarge
                    color: Config.cardColor
                    border.width: 2
                    border.color: Qt.alpha(Config.accentColor, 0.6)

                    DeviceRow {
                        id: connectedRow

                        anchors.fill: parent
                        anchors.leftMargin: Config.padding * 2
                        anchors.rightMargin: Config.padding * 2
                        anchors.topMargin: Config.padding
                        anchors.bottomMargin: Config.padding
                        icon: BluetoothService.getDeviceIcon(connectedCard.modelData)
                        // Battery ring when the device reports it, a faint full ring otherwise
                        ring: connectedCard.hasBattery ? connectedCard.modelData.battery * 100 : 0
                        ringColor: connectedCard.hasBattery && connectedCard.modelData.battery < 0.2 ? Config.errorColor : Config.accentColor
                        ringTrackColor: connectedCard.hasBattery ? Config.surface2Color : Qt.alpha(Config.accentColor, 0.3)
                        title: BluetoothService.deviceName(connectedCard.modelData)
                        subtitle: root.status(connectedCard.modelData)
                        trailing: connectedCard.hasBattery ? Math.round(connectedCard.modelData.battery * 100) + "%" : ""
                        onClicked: connectedCard.modelData.disconnect()
                        menuModel: [
                            {
                                text: "Disconnect",
                                icon: "\u{f00b2}", // md-bluetooth_off
                                action: "disconnect"
                            },
                            {
                                text: "Forget",
                                icon: "\u{f01b4}", // md-delete
                                action: "forget",
                                color: Config.errorColor
                            }
                        ]
                        onMenuAction: action => {
                            if (action === "disconnect")
                                connectedCard.modelData.disconnect();
                            else if (action === "forget")
                                BluetoothService.forgetDevice(connectedCard.modelData);
                        }
                    }
                }
            }

            // ========== PAIRED DEVICES ==========
            Card {
                visible: BluetoothService.isPowered && root.known.length > 0
                Layout.fillWidth: true

                CardHeader {
                    icon: "󰂯"
                    title: "My devices"
                    subtitle: root.known.length + " paired"
                }

                Repeater {
                    model: root.known

                    DeviceRow {
                        required property var modelData

                        Layout.leftMargin: Config.padding
                        Layout.rightMargin: Config.padding
                        icon: BluetoothService.getDeviceIcon(modelData)
                        title: BluetoothService.deviceName(modelData)
                        subtitle: root.status(modelData)
                        connecting: modelData.pairing || BluetoothService.getIsConnecting(modelData)
                        menuModel: [
                            {
                                "text": "Connect",
                                "icon": "󰂱",
                                "action": "connect"
                            },
                            {
                                "text": "Forget",
                                "icon": "󰆴",
                                "action": "forget",
                                "color": Config.errorColor
                            }
                        ]
                        onClicked: BluetoothService.toggleConnection(modelData)
                        onMenuAction: action => {
                            if (action === "connect")
                                BluetoothService.toggleConnection(modelData);
                            else if (action === "forget")
                                BluetoothService.forgetDevice(modelData);
                        }
                    }
                }
            }
        }

        // ========== FOUND DEVICES ==========
        Card {
            id: foundCard

            visible: BluetoothService.isPowered
            Layout.fillWidth: true

            CardHeader {
                id: foundHeader
                icon: "󰂰"
                title: "Available"
                subtitle: BluetoothService.isDiscovering ? "Searching…" : root.found.length + " found"
            }

            Flickable {
                id: list

                // Whatever the page has left, but always room for a few rows
                readonly property real maxHeight: Math.max(root.rowHeight * 3, root.availableHeight - top.implicitHeight - main.spacing - foundCard.padding * 2 - foundHeader.implicitHeight - foundCard.spacing)

                visible: root.found.length > 0
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
                        model: root.found

                        DeviceRow {
                            required property var modelData

                            width: rows.width
                            icon: BluetoothService.getDeviceIcon(modelData)
                            title: BluetoothService.deviceName(modelData)
                            subtitle: root.status(modelData)
                            connecting: modelData.pairing || BluetoothService.getIsConnecting(modelData)
                            onClicked: BluetoothService.toggleConnection(modelData)
                        }
                    }
                }
            }

            Text {
                visible: root.found.length === 0
                Layout.fillWidth: true
                Layout.topMargin: Config.spacing
                Layout.bottomMargin: Config.spacing
                horizontalAlignment: Text.AlignHCenter
                text: BluetoothService.isDiscovering ? "Looking for devices…" : "Make sure the device is in pairing mode"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
            }
        }

        // ========== BLUETOOTH OFF ==========
        Card {
            visible: !BluetoothService.isPowered
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
                        text: "󰂲"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconLarge
                        color: Config.subtextColor
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Bluetooth is off"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    font.bold: true
                    color: Config.textColor
                }

                ActionButton {
                    Layout.alignment: Qt.AlignHCenter
                    size: header.boxSize
                    icon: "󰂯"
                    text: "Turn on"
                    baseColor: Config.accentColor
                    hoverColor: Qt.lighter(Config.accentColor, 1.1)
                    textColor: Config.textReverseColor
                    onClicked: {
                        scanAfterPowerOn.restart();
                        BluetoothService.togglePower();
                    }
                }
            }
        }
    }
}
