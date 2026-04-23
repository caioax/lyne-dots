pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var accessPoints: []
    property var savedSsids: []
    property bool wifiEnabled: true
    property string wifiInterface: ""
    property string connectingSsid: ""
    property string connectivity: "unknown" // none | portal | limited | full | unknown
    property bool _portalNotified: false
    readonly property bool scanning: rescanProc.running
    readonly property bool hasCaptivePortal: {
        const activeNetwork = accessPoints.find(ap => ap.active === true);
        // Only "portal" is the real captive portal state.
        // "limited" fires on many normal networks where the NM check URL is blocked.
        return !!activeNetwork && connectivity === "portal";
    }

    onConnectivityChanged: {
        if (connectivity === "portal" && !_portalNotified) {
            _portalNotified = true;
            openPortalProc.running = true;
        } else if (connectivity !== "portal") {
            _portalNotified = false;
        }
    }
    readonly property string systemIcon: {
        if (!wifiEnabled)
            return "󰤮";
        const activeNetwork = accessPoints.find(ap => ap.active === true);
        if (activeNetwork) {
            if (hasCaptivePortal)
                return "󰤬";
            return getWifiIcon(activeNetwork.signal);
        }
        return "󰤫";
    }

    // --- FUNCTIONS ---

    function getWifiIcon(signal) {
        if (signal > 80)
            return "󰤨";
        if (signal > 60)
            return "󰤥";
        if (signal > 40)
            return "󰤢";
        if (signal > 20)
            return "󰤟";
        return "󰤫";
    }

    // Status text
    readonly property string statusText: {
        if (!wifiEnabled)
            return "Off";
        const activeNetwork = accessPoints.find(ap => ap.active === true);
        if (activeNetwork) {
            if (hasCaptivePortal)
                return (activeNetwork.ssid || "Hidden Network") + " · Portal";
            return activeNetwork.ssid || "Hidden Network";
        }
        return "On";
    }

    function openPortalBrowser() {
        openPortalProc.running = true;
    }

    function toggleWifi() {
        const cmd = wifiEnabled ? "off" : "on";
        toggleWifiProc.command = ["nmcli", "radio", "wifi", cmd];
        toggleWifiProc.running = true;
    }

    function scan() {
        if (!scanning)
            rescanProc.running = true;
    }

    function disconnect() {
        if (wifiInterface !== "") {
            console.log("Disconnecting interface: " + wifiInterface);
            disconnectProc.command = ["nmcli", "dev", "disconnect", wifiInterface];
            disconnectProc.running = true;
        }
    }

    function connect(ssid, password) {
        console.log("Attempting to connect to:", ssid);
        root.connectingSsid = ssid; // Mark which one we are trying

        if (password && password.length > 0) {
            connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", password];
        } else {
            // Try connecting using saved profile
            connectProc.command = ["nmcli", "dev", "wifi", "connect", ssid];
        }
        connectProc.running = true;
    }

    function forget(ssid) {
        console.log("Forgetting network: " + ssid);
        forgetProc.command = ["nmcli", "connection", "delete", "id", ssid];
        forgetProc.running = true;
    }

    // Internal function to clean up failed connections
    function cleanUpBadConnection(ssid) {
        console.warn("Connection failed. Removing invalid profile for: " + ssid);
        // Uses forgetProc to delete, since it is the same logic
        forget(ssid);
    }

    // --- PROCESSES ---

    // Connection Process
    Process {
        id: connectProc

        stdout: SplitParser {
            onRead: data => console.log("[Wifi] " + data)
        }
        stderr: SplitParser {
            onRead: data => console.error("[Wifi Error] " + data)
        }

        onExited: code => {
            if (code !== 0) {
                console.error("Connect command exited with code: " + code);
                // A non-zero exit can mean captive portal: WiFi associated but no internet.
                // Check real connectivity before deciding to delete the profile.
                portalCheckProc._failedSsid = root.connectingSsid;
                portalCheckProc.running = true;
            } else {
                console.log("Connected successfully!");
                root.connectingSsid = "";
                getSavedProc.running = true;
                getNetworksProc.running = true;
                connectivityProc.running = true;
            }
        }
    }

    // Detect Wifi Interface
    Process {
        id: findInterfaceProc
        command: ["nmcli", "-g", "DEVICE,TYPE", "device"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const lines = data.trim().split("\n");
                lines.forEach(line => {
                    const parts = line.split(":");
                    if (parts.length >= 2 && parts[1] === "wifi") {
                        root.wifiInterface = parts[0];
                    }
                });
            }
        }
    }

    // Status Monitor (Enabled/Disabled)
    Process {
        id: statusProc
        command: ["nmcli", "radio", "wifi"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                root.wifiEnabled = (data.trim() === "enabled");
                if (root.wifiEnabled)
                    getSavedProc.running = true;
                getNetworksProc.running = true;
            }
        }
    }

    // Toggle On/Off
    Process {
        id: toggleWifiProc
        onExited: statusProc.running = true
    }

    // Rescan (Refresh)
    Process {
        id: rescanProc
        command: ["nmcli", "dev", "wifi", "list", "--rescan", "yes"]
        onExited: getNetworksProc.running = true
    }

    // Disconnect
    Process {
        id: disconnectProc
        onExited: getNetworksProc.running = true
    }

    // Forget Network
    Process {
        id: forgetProc
        // The command is defined dynamically before running
        onExited: {
            getSavedProc.running = true;
            getNetworksProc.running = true;
        }
    }

    // Automatic Update Timer
    Timer {
        interval: 10000
        running: root.wifiEnabled
        repeat: true
        onTriggered: {
            getSavedProc.running = true;
            getNetworksProc.running = true;
            connectivityProc.running = true;
        }
    }

    // Connectivity check (detects captive portals)
    Process {
        id: connectivityProc
        command: ["nmcli", "-g", "CONNECTIVITY", "general"]
        running: true
        stdout: SplitParser {
            onRead: data => root.connectivity = data.trim().toLowerCase()
        }
    }

    // Opens the default browser to the portal login page
    Process {
        id: openPortalProc
        command: ["xdg-open", "http://detectportal.firefox.com/"]
        stderr: SplitParser {
            onRead: data => console.error("[Wifi:Portal] " + data)
        }
    }

    // Checks connectivity after a failed connect to distinguish captive portal from real failure
    Process {
        id: portalCheckProc
        property string _failedSsid: ""
        command: ["nmcli", "-g", "CONNECTIVITY", "general"]

        stdout: SplitParser {
            onRead: data => {
                const conn = data.trim().toLowerCase();
                root.connectivity = conn;
                if (conn === "none" || conn === "unknown") {
                    if (portalCheckProc._failedSsid !== "")
                        root.cleanUpBadConnection(portalCheckProc._failedSsid);
                } else {
                    console.log("[Wifi] Captive portal detected (" + conn + "), keeping profile");
                }
            }
        }

        onExited: {
            portalCheckProc._failedSsid = "";
            root.connectingSsid = "";
            getSavedProc.running = true;
            getNetworksProc.running = true;
        }
    }

    // List Saved Networks
    Process {
        id: getSavedProc
        command: ["nmcli", "-g", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                var savedList = [];
                lines.forEach(line => {
                    const parts = line.split(":");
                    if (parts.length >= 2 && parts[1] === "802-11-wireless") {
                        savedList.push(parts[0]);
                    }
                });
                root.savedSsids = savedList;
            }
        }
    }

    // List Available Networks (Scan)
    Process {
        id: getNetworksProc
        command: ["nmcli", "-g", "IN-USE,SIGNAL,SSID,SECURITY,BSSID,CHAN,RATE", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                var tempParams = [];
                const seen = new Set();

                lines.forEach(line => {
                    if (line.length < 5)
                        return;
                    const parts = line.split(":");
                    if (parts.length < 7)
                        return;

                    const inUse = parts[0] === "*";
                    const signal = parseInt(parts[1]) || 0;
                    const ssid = parts[2];
                    const security = parts[3];
                    const bssid = parts[4];
                    const channel = parts[5];
                    const rate = parts[6];

                    if (!ssid)
                        return;
                    if (seen.has(ssid))
                        return; // Avoid visual duplicates
                    seen.add(ssid);

                    const isSaved = root.savedSsids.includes(ssid);

                    tempParams.push({
                        ssid: ssid,
                        signal: signal,
                        active: inUse,
                        secure: security.length > 0,
                        securityType: security || "Open",
                        saved: isSaved,
                        bssid: bssid,
                        channel: channel,
                        rate: rate
                    });
                });

                // Sort: Connected > Saved > Signal
                tempParams.sort((a, b) => {
                    if (a.active)
                        return -1;
                    if (b.active)
                        return 1;
                    if (a.saved && !b.saved)
                        return -1;
                    if (!a.saved && b.saved)
                        return 1;
                    return b.signal - a.signal;
                });

                root.accessPoints = tempParams;
            }
        }
    }
}
