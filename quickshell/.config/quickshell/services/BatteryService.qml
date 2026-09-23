pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    // Returns true if a laptop battery was found
    readonly property bool hasBattery: mainBattery !== null

    // Percentage (0 to 100)
    readonly property int percentage: mainBattery ? Math.round(mainBattery.percentage * 100) : 0

    // State (Charging, Discharging, Full...)
    readonly property int state: mainBattery ? mainBattery.state : UPowerDeviceState.Unknown

    // Boolean helper to simplify UI bindings
    readonly property bool isCharging: state === UPowerDeviceState.Charging

    // "2h 15m left" / "40m to full"; empty when UPower has no estimate
    readonly property string timeText: {
        if (!mainBattery)
            return "";
        const seconds = isCharging ? mainBattery.timeToFull : mainBattery.timeToEmpty;
        if (!seconds || seconds <= 0)
            return state === UPowerDeviceState.FullyCharged ? "Full" : "";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.round((seconds % 3600) / 60);
        const duration = hours > 0 ? hours + "h " + minutes + "m" : minutes + "m";
        return duration + (isCharging ? " to full" : " left");
    }

    // Holds the reference to the battery object
    property var mainBattery: null

    // The Instantiator scans the device list without creating visuals
    Instantiator {
        model: UPower.devices

        delegate: QtObject {
            required property var modelData
            
            // When a device is created or changes, we check if it is the main battery
            Component.onCompleted: checkDevice()
            
            function checkDevice() {
                if (modelData && modelData.isLaptopBattery) {
                    root.mainBattery = modelData
                }
            }
        }
    }

    // Icon logic here.
    function getBatteryIcon() {
        if (state === UPowerDeviceState.Charging) return "󰂄"

        const p = percentage
        if (p >= 90) return "󰁹"
        if (p >= 60) return "󰂀"
        if (p >= 40) return "󰁾"
        if (p >= 10) return "󰁼"
        return "󰁺"
    }
}