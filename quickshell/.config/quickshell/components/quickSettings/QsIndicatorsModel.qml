pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// Status indicators of the Quick Settings bar button, shared by every style.
// Each one is { shown, icon, tone, alert } (plus extras per id); styles walk
// `order` and draw the shown ones. tone: "normal", "success", "warning" or
// "error", mapped to colors by the style. alert: worth a glance (no network,
// low battery...), for styles that fold everything into one icon.
QtObject {
    id: root

    readonly property var order: ["network", "bluetooth", "volume", "mic", "battery"]

    // Percentage next to the battery (bar.quickSettings.batteryPercent)
    readonly property bool batteryPercent: Config.barQsBatteryPercent

    // Worst state among the shown indicators, for styles that fold them into
    // one icon: "error" (a nearly empty battery, no network),
    // "warning" (other alerts) or "" when nothing needs a glance
    readonly property string summaryTone: {
        let worst = "";
        for (const id of order) {
            const ind = indicators[id];
            if (!ind.shown)
                continue;
            let tone = "";
            if (ind.alert)
                tone = ind.tone === "error" ? "error" : "warning";
            if (tone === "error")
                return tone;
            if (tone)
                worst = tone;
        }
        return worst;
    }

    // Tone to color; "normal" is the style's own icon color
    function toneColor(tone: string, normal: color): color {
        switch (tone) {
        case "success":
            return Config.successColor;
        case "warning":
            return Config.warningColor;
        case "error":
            return Config.errorColor;
        default:
            return normal;
        }
    }

    // false for previews: `sampleIndicators` (same shape, keyed by id) stand
    // in for the system state
    property bool live: true
    property var sampleIndicators: ({})

    // The system state (or the sample), minus the indicators switched off in
    // Settings (bar.quickSettings.indicators)
    readonly property var indicators: {
        const all = Object.assign({}, live ? {
            "network": network,
            "bluetooth": bluetooth,
            "volume": volume,
            "mic": mic,
            "battery": battery
        } : sampleIndicators);
        const allowed = Config.barQsIndicators;
        for (const id of order) {
            if (allowed[id] === false)
                all[id] = Object.assign({}, all[id], {
                    shown: false
                });
        }
        return all;
    }

    // Shown ids in order; styles use it to put gaps only between them
    readonly property var shownIds: order.filter(id => indicators[id]?.shown)

    // Ethernet first; otherwise the Wi-Fi state
    readonly property var network: {
        if (NetworkService.ethernetConnected)
            return {
                shown: true,
                icon: NetworkService.wiredIcon,
                tone: "normal",
                alert: false
            };
        const connected = NetworkService.activeNetwork !== null;
        return {
            shown: true,
            icon: NetworkService.systemIcon,
            tone: NetworkService.hasCaptivePortal ? "warning" : "normal",
            alert: !connected || NetworkService.hasCaptivePortal
        };
    }

    // Only with a device connected: powered with nothing on it says nothing
    readonly property var bluetooth: ({
            shown: BluetoothService.connectedDevicesCount > 0,
            icon: BluetoothService.systemIcon,
            tone: "normal",
            alert: false,
            count: BluetoothService.connectedDevicesCount
        })

    readonly property var volume: ({
            shown: AudioService.sinkReady && AudioService.muted,
            icon: "󰖁",
            tone: "normal",
            alert: false
        })

    // Muted wins over in use: nothing reaches the app
    readonly property var mic: {
        const muted = AudioService.sourceReady && AudioService.sourceMuted;
        return {
            shown: muted || AudioService.micInUse,
            icon: muted ? "󰍭" : "󰍬",
            tone: muted ? "normal" : "warning",
            alert: !muted && AudioService.micInUse,
            apps: AudioService.micApps
        };
    }

    readonly property var battery: ({
            shown: BatteryService.hasBattery,
            icon: BatteryService.getBatteryIcon(),
            tone: BatteryService.isCharging ? "success" : BatteryService.percentage < 10 ? "error" : BatteryService.percentage < 20 ? "warning" : "normal",
            alert: !BatteryService.isCharging && BatteryService.percentage < 20,
            percentage: BatteryService.percentage,
            charging: BatteryService.isCharging
        })
}
