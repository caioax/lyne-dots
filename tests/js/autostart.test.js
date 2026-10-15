const test = require("node:test");
const assert = require("node:assert/strict");
const { load } = require("./load");

const A = load("services/autostart.js");

test("parseDesktop reads only [Desktop Entry], first value wins, no localized keys", () => {
    const keys = A.parseDesktop(`# comment
[Desktop Entry]
Name=Syncthing
Name[pt]=Sincronizar
Exec=syncthing serve
Exec=other
Hidden = true

[Desktop Action New]
Name=Other`);
    assert.deepEqual(keys, { Name: "Syncthing", Exec: "syncthing serve", Hidden: "true" });
});

test("skipReason: OnlyShowIn, NotShowIn, X-systemd-skip, Type", () => {
    assert.equal(A.skipReason({}, "Hyprland"), "");
    assert.equal(A.skipReason({ OnlyShowIn: "KDE;" }, "Hyprland"), "desktop");
    assert.equal(A.skipReason({ OnlyShowIn: "KDE;Hyprland;" }, "uwsm:Hyprland"), "");
    assert.equal(A.skipReason({ NotShowIn: "Hyprland" }, "Hyprland"), "desktop");
    assert.equal(A.skipReason({ "X-systemd-skip": "true" }, "Hyprland"), "skip");
    assert.equal(A.skipReason({ Type: "Link" }, "Hyprland"), "type");
});

test("entries: a user file hides the system file; our override keeps the system values", () => {
    const system = [
        { path: "/etc/xdg/autostart/geoclue.desktop", text: "[Desktop Entry]\nName=Geoclue\nExec=/usr/lib/geoclue-demo-agent" },
        { path: "/etc/xdg/autostart/kde.desktop", text: "[Desktop Entry]\nName=KDE thing\nOnlyShowIn=KDE;" }
    ];
    const user = [
        { path: "/home/u/.config/autostart/geoclue.desktop", text: "[Desktop Entry]\nHidden=true\nX-Lyne-Override=true" },
        { path: "/home/u/.config/autostart/discord.desktop", text: "[Desktop Entry]\nExec=discord --start-minimized" },
        { path: "/home/u/.config/autostart/notes.txt", text: "" }
    ];
    const list = A.entries(user, system, "Hyprland");
    assert.deepEqual(list.map(e => e.id), ["discord.desktop", "geoclue.desktop", "kde.desktop"]);
    const [discord, geoclue, kde] = list;
    assert.equal(discord.name, "discord");
    assert.equal(discord.source, "user");
    assert.equal(geoclue.override, true);
    assert.equal(geoclue.enabled, false);
    assert.equal(geoclue.name, "Geoclue");
    assert.equal(geoclue.exec, "/usr/lib/geoclue-demo-agent");
    assert.equal(geoclue.path, "/home/u/.config/autostart/geoclue.desktop");
    assert.equal(kde.reason, "desktop");
    assert.equal(kde.meantFor, "KDE");
});

test("parseUnits + unitStatus", () => {
    const units = A.parseUnits(`Id=app-a@autostart.service
SourcePath=/a.desktop
ActiveState=active
SubState=running
Result=success

Id=app-b@autostart.service
SourcePath=/b.desktop
ActiveState=failed
SubState=failed
Result=exit-code

Id=app-c@autostart.service
SourcePath=/c.desktop
ActiveState=inactive
SubState=dead
Result=success`);
    assert.equal(A.unitStatus(units["/a.desktop"]), "running");
    assert.equal(A.unitStatus(units["/b.desktop"]), "failed");
    assert.equal(A.unitStatus(units["/c.desktop"]), "exited");
    assert.equal(A.unitStatus(undefined), "");
});

test("parseList splits the records of scripts/autostart.sh", () => {
    const out = A.parseList("\x1euser\t/u/a.desktop\n[Desktop Entry]\nName=A\n\x1esystem\t/s/b.desktop\nX\n\x1eunits\nId=x\n\x1etarget\nactive\n");
    assert.deepEqual(out.user, [{ path: "/u/a.desktop", text: "[Desktop Entry]\nName=A\n" }]);
    assert.equal(out.system.length, 1);
    assert.equal(out.units, "Id=x\n");
    assert.equal(out.target, "active");
});

test("programOf: last command, env vars and interpreters skipped", () => {
    assert.equal(A.programOf("sleep 2 && /usr/bin/discord --start-minimized"), "discord");
    assert.equal(A.programOf("env GDK_BACKEND=x11 FOO=1 zoom"), "zoom");
    assert.equal(A.programOf("python3 /home/u/bin/fan.py --quiet"), "fan.py");
    assert.equal(A.programOf("bash -c 'x'"), "bash");
    assert.equal(A.programOf(""), "");
});

test("runningPrograms/isRunning: scripts count as themselves", () => {
    const running = A.runningPrograms("/usr/bin/discord --type=renderer\npython3 -u /home/u/bin/fan.py\n\n");
    assert.equal(A.isRunning("discord --start-minimized", running), true);
    assert.equal(A.isRunning("python3 ~/bin/fan.py", running), true);
    assert.equal(A.isRunning("spotify", running), false);
});
