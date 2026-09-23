pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    // Gets the system's default adapter. Can be null if there is no bluetooth.
    property var adapter: Bluetooth?.defaultAdapter

    // Reactive properties (return false if there is no adapter)
    readonly property bool isPowered: (adapter && adapter.enabled) === true
    readonly property bool isDiscovering: (adapter && adapter.discovering) === true

    // Property to know if we are visible to others (useful for the UI)
    readonly property bool isDiscoverable: (adapter && adapter.discoverable) === true

    // Icon for the current bluetooth status
    readonly property string systemIcon: {
        if (!isPowered)
            return "󰂲";

        if (devicesList.some(dev => dev.connected))
            return "󰂱";

        return "";
    }

    // List of connected devices only
    readonly property var connectedDevices: {
        return devicesList.filter(dev => dev.connected);
    }

    // Count (For use in the UI)
    readonly property int connectedDevicesCount: connectedDevices.length

    // Smart text (For the Dashboard sublabel)
    readonly property string statusText: {
        if (!isPowered)
            return "Off";

        const count = connectedDevices.length;

        if (count === 0)
            return "On";

        if (count === 1)
            return deviceName(connectedDevices[0]);

        // If there is more than 1, return the count
        return count + " devices";
    }

    // The smart device list
    readonly property var devicesList: {
        if (!adapter || !adapter.devices)
            return [];

        // Quickshell's 'values' is not a pure JS Array, so we convert it
        // to ensure that .sort() works without errors.
        let list = Array.from(adapter.devices.values);

        // Sorting function
        return list.sort((a, b) => {
            // Connected devices appear first at the top
            if (a.connected && !b.connected)
                return -1;
            if (!a.connected && b.connected)
                return 1;

            // Known devices (Paired or Trusted) appear before new ones
            const aKnown = a.paired || a.trusted;
            const bKnown = b.paired || b.trusted;
            if (aKnown && !bKnown)
                return -1;
            if (!aKnown && bKnown)
                return 1;

            // Finally, alphabetical order by name
            const nameA = root.deviceName(a).toLowerCase();
            const nameB = root.deviceName(b).toLowerCase();
            return nameA.localeCompare(nameB);
        });
    }

    // --- ACTIONS ---

    // Toggle Power (On/Off)
    function togglePower() {
        if (adapter) {
            adapter.enabled = !adapter.enabled;
        }
    }

    // Toggle Search (Scan)
    function toggleScan() {
        if (!adapter)
            return;

        if (adapter.discovering) {
            // If the user clicked to stop manually
            adapter.discovering = false;
            scanTimer.stop();
        } else {
            // If the user clicked to start
            adapter.discovering = true;
            scanTimer.restart();
        }
    }

    // Timer to automatically stop the Scan
    Timer {
        id: scanTimer
        interval: 10000 // 10 Seconds
        repeat: false
        onTriggered: {
            if (root.adapter && root.adapter.discovering) {
                root.adapter.discovering = false;
            }
        }
    }

    // Connect/Disconnect
    function toggleConnection(device) {
        if (!device)
            return;

        if (device.connected) {
            device.disconnect();
            return;
        }

        if (device.state === BluetoothDeviceState.Connecting) {
            console.log("Please wait, device is already connecting...");
        }

        // Try to mark as trusted before connecting.
        // Vital for headphones on Linux without a visual PIN agent.
        try {
            device.trusted = true;
        } catch (e) {
            console.warn("Could not set trusted automatically." + e);
        }

        if (!device.paired) {
            try {
                device.pair();
            } catch (e) {
                console.error("Error pairing: " + e);
            }
            return;
        }

        device.connect();
    }

    // Make visible/invisible to other devices
    function toggleDiscoverable() {
        adapter.discoverable = !adapter.discoverable;
    }

    // Function to check if the device is trying to connect
    function getIsConnecting(device) {
        return device.state === BluetoothDeviceState.Connecting;
    }

    // Forget device
    function forgetDevice(device) {
        if (device) {
            device.forget();
        }
    }

    // Device kind from the BlueZ icon property or, failing that, its name
    function deviceKind(device): var {
        const iconProp = (device?.icon || "").toLowerCase();
        const name = (device?.name || device?.deviceName || "").toLowerCase();
        const has = keys => keys.some(k => iconProp.includes(k) || name.includes(k));

        if (has(["headset", "headphone", "audio", "airpod", "buds", "wh-", "wf-", "jbl", "soundcore", "speaker"]))
            return {
                "icon": "",
                "label": "Audio"
            };
        if (has(["mouse"]))
            return {
                "icon": "󰍽",
                "label": "Mouse"
            };
        if (has(["keyboard"]))
            return {
                "icon": "",
                "label": "Keyboard"
            };
        if (has(["phone", "android", "iphone", "redmi", "galaxy", "pixel"]))
            return {
                "icon": "",
                "label": "Phone"
            };
        if (has(["gamepad", "joystick", "controller"]))
            return {
                "icon": "",
                "label": "Controller"
            };
        if (has(["computer", "laptop"]))
            return {
                "icon": "󰌢",
                "label": "Computer"
            };
        if (has(["tv"]))
            return {
                "icon": "󰔂",
                "label": "TV"
            };
        return {
            "icon": "",
            "label": "Device"
        };
    }

    function getDeviceIcon(device) {
        return deviceKind(device).icon;
    }

    function deviceName(device): string {
        return device?.name || device?.deviceName || device?.address || "Unknown";
    }

    function isKnown(device): bool {
        return device.paired || device.trusted;
    }
}
