const test = require("node:test");
const assert = require("node:assert/strict");
const { load, fixture } = require("./load");

const N = load("services/network.js");

test("fields unescapes colons and backslashes inside values", () => {
    assert.deepEqual(N.fields("wlan0:wifi:connected:Home\\: 5G"), ["wlan0", "wifi", "connected", "Home: 5G"]);
    assert.deepEqual(N.fields("a\\\\:b"), ["a\\", "b"]);
    assert.deepEqual(N.fields("lo::"), ["lo", "", ""]);
});

test("a connected cable is found among other devices", () => {
    assert.deepEqual(N.wiredConnection(fixture("nmcli-devices-wired.txt")), {
        device: "enp3s0",
        connection: "Wired connection 2"
    });
});

test("Wi-Fi only, or a cable still connecting, is no wired connection", () => {
    assert.equal(N.wiredConnection(fixture("nmcli-devices-wifi.txt")), null);
    assert.equal(N.wiredConnection(fixture("nmcli-devices-connecting.txt")), null);
    assert.equal(N.wiredConnection(""), null);
});

test("cable and Wi-Fi both connected: the cable", () => {
    assert.deepEqual(N.wiredConnection(fixture("nmcli-devices-both.txt")), {
        device: "enp0s31f6",
        connection: "Wired connection 1"
    });
});

test("a cable set up outside NetworkManager counts", () => {
    assert.equal(N.wiredConnection("eth0:ethernet:connected (externally):eth0").device, "eth0");
});

test("details: first address without the prefix, first DNS, speed", () => {
    assert.deepEqual(N.deviceDetails(fixture("nmcli-details-wired.txt")), {
        ip: "192.168.1.7",
        gateway: "192.168.1.1",
        dns: "192.168.1.1",
        speed: 1000
    });
});

test("details of a device with nothing: empty, speed 0", () => {
    assert.deepEqual(N.deviceDetails(fixture("nmcli-details-down.txt")), { ip: "", gateway: "", dns: "", speed: 0 });
    assert.deepEqual(N.deviceDetails(""), { ip: "", gateway: "", dns: "", speed: 0 });
});

test("speed labels", () => {
    assert.equal(N.speedLabel(1000), "1 Gb/s");
    assert.equal(N.speedLabel(2500), "2.5 Gb/s");
    assert.equal(N.speedLabel(100), "100 Mb/s");
    assert.equal(N.speedLabel(0), "");
});
