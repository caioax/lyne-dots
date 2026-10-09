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

    // UPower's display device: every laptop battery combined. Gone (null)
    // without one, also when it's removed
    readonly property var mainBattery: {
        const device = UPower.displayDevice;
        return device?.isLaptopBattery && device.isPresent ? device : null;
    }

    function getBatteryIcon() {
        if (state === UPowerDeviceState.Charging)
            return "󰂄";
        const p = percentage;
        if (p >= 90)
            return "󰁹";
        if (p >= 60)
            return "󰂀";
        if (p >= 40)
            return "󰁾";
        if (p >= 10)
            return "󰁼";
        return "󰁺";
    }
}
