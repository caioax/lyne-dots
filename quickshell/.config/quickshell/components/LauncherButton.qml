pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.config
import qs.services

// Bar button that opens the launcher. Shows the lyne-dots logo (or the
// distro's Nerd Font glyph) in one of three styles:
//   logo    — no background at rest, a pill the size of the logo on hover
//   pill    — a soft accent pill that is always there
//   compact — a round button
// With `bar.launcher.animate` the dot hops on hover and grows while the
// launcher is open. Right and middle click run the configured actions
BarButton {
    id: root

    property string style: Config.barLauncherStyle
    property string icon: Config.barLauncherIcon
    property bool animate: Config.barLauncherAnimate
    // Previews in Settings draw a static button (no service, no input)
    property bool live: true
    // Draws the hover background without the pointer (previews)
    property bool showLit: false

    readonly property bool lit: hovered || active || showLit

    // 0–1 progress of the hover/open background, animated as a number so the
    // colors themselves still switch at once on theme changes
    property real litProgress: lit ? 1 : 0
    Behavior on litProgress {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    active: live && LauncherService.visible
    enabled: live
    contentItem: content
    animateColor: false
    implicitWidth: style === "compact" ? implicitHeight : content.implicitWidth + Config.padding * 3
    color: {
        if (style === "pill")
            return Qt.alpha(Config.accentColor, 0.14 + 0.12 * litProgress);
        return Qt.alpha(Config.surface1Color, litProgress);
    }

    onClicked: LauncherService.toggle()
    onRightClicked: run(Config.barLauncherRightClick)
    onMiddleClicked: run(Config.barLauncherMiddleClick)

    function run(action: string) {
        switch (action) {
        case "actions":
        case "clipboard":
            LauncherService.toggleMode(action);
            break;
        case "settings":
            SettingsService.toggle();
            break;
        case "power":
            PowerService.toggle();
            break;
        }
    }

    // --- MOTION ---
    // hop: 0 → 1 → 0 once per hover; grow: 1 while the launcher is open
    property real hop: 0
    property real grow: animate && active ? 1 : 0

    Behavior on grow {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 3
        }
    }

    onHoveredChanged: {
        if (hovered && animate)
            hopAnim.restart();
    }

    SequentialAnimation {
        id: hopAnim

        NumberAnimation {
            target: root
            property: "hop"
            to: 1
            duration: Config.animDurationShort
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "hop"
            to: 0
            duration: Config.animDuration
            easing.type: Easing.OutBounce
        }
    }

    // --- DISTRO GLYPH ---
    // Nerd Font glyph for the distro in /etc/os-release (ID, then ID_LIKE),
    // Tux when it has none
    readonly property var distroGlyphs: ({
            "almalinux": "\u{f31d}",
            "alpine": "\u{f300}",
            "arch": "\u{f303}",
            "archcraft": "\u{f345}",
            "arcolinux": "\u{f346}",
            "artix": "\u{f31f}",
            "cachyos": "\u{f385}",
            "centos": "\u{f304}",
            "debian": "\u{f306}",
            "deepin": "\u{f321}",
            "devuan": "\u{f307}",
            "elementary": "\u{f309}",
            "endeavouros": "\u{f322}",
            "fedora": "\u{f30a}",
            "garuda": "\u{f337}",
            "gentoo": "\u{f30d}",
            "kali": "\u{f327}",
            "linuxmint": "\u{f30e}",
            "manjaro": "\u{f312}",
            "mx": "\u{f33f}",
            "nixos": "\u{f313}",
            "nobara": "\u{f380}",
            "opensuse": "\u{f314}",
            "opensuse-leap": "\u{f37e}",
            "opensuse-tumbleweed": "\u{f37d}",
            "pop": "\u{f32a}",
            "rhel": "\u{f316}",
            "rocky": "\u{f32b}",
            "slackware": "\u{f318}",
            "solus": "\u{f32d}",
            "suse": "\u{f314}",
            "ubuntu": "\u{f31b}",
            "void": "\u{f32e}",
            "zorin": "\u{f32f}"
        })
    readonly property string tuxGlyph: "\u{f31a}"

    property string distroGlyph: tuxGlyph

    FileView {
        path: root.icon === "distro" ? "/etc/os-release" : ""
        onLoaded: {
            const fields = {};
            for (const line of text().split("\n")) {
                const eq = line.indexOf("=");
                if (eq > 0)
                    fields[line.slice(0, eq)] = line.slice(eq + 1).replace(/^["']|["']$/g, "");
            }
            const ids = [fields.ID ?? ""].concat((fields.ID_LIKE ?? "").split(" "));
            const id = ids.find(i => root.distroGlyphs[i] !== undefined);
            root.distroGlyph = id !== undefined ? root.distroGlyphs[id] : root.tuxGlyph;
        }
    }

    Item {
        id: content

        anchors.centerIn: parent
        implicitWidth: root.icon === "distro" ? glyph.implicitWidth : logo.implicitWidth
        implicitHeight: Config.fontSizeNormal

        LyneLogo {
            id: logo
            anchors.centerIn: parent
            height: Config.fontSizeNormal
            visible: root.icon !== "distro"
            dotLift: root.hop * 0.2
            dotScale: 1 + root.grow * 0.3
        }

        Text {
            id: glyph
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -root.hop * Config.fontSizeNormal * 0.2
            visible: root.icon === "distro"
            text: root.distroGlyph
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            color: Config.accentColor
            scale: 1 + root.grow * 0.12
        }
    }
}
