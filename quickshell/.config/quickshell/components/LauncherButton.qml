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
// With `bar.launcher.animate` the logo comes alive (see MOTION). Right and
// middle click run the configured actions
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
    // Driven as numbers, the logo (or glyph) maps them to its shape:
    //   hover  — the dot bounces: squashes, leaps stretched, lands flat, rebounds
    //   open   — the dot rides the whole line as a comet and comes home bigger;
    //            closing rides it back
    //   open   — then it breathes slowly twice and rests, grown, until the
    //            launcher closes (a looping animation would keep every
    //            window rendering at the refresh rate)
    //   press  — the logo squeezes and pops back on release
    //   start  — the line draws itself once and the dot pops in
    property real lift: 0
    property real stretch: 0
    property real travel: 0
    property bool travelReverse: false
    property real grow: 0
    property real breath: 0
    property real press: animate && pressed ? 1 : 0
    property real draw: 1
    property real pop: 1

    readonly property bool motionOn: live && animate

    Behavior on press {
        NumberAnimation {
            duration: root.pressed ? Config.animDurationShort : Config.animDuration
            easing.type: root.pressed ? Easing.OutQuad : Easing.OutBack
            easing.overshoot: 4
        }
    }

    onHoveredChanged: {
        if (hovered && motionOn && !travelAnim.running)
            bounceAnim.restart();
    }

    onActiveChanged: {
        if (!motionOn)
            return;
        bounceAnim.stop();
        lift = 0;
        stretch = 0;
        travelAnim.stop();
        travelReverse = !active;
        travelAnim.from = active ? 0 : 1;
        travelAnim.to = active ? 1 : 0;
        // A close that interrupts the ride starts from where the dot is
        if (!active && travel > 0)
            travelAnim.from = travel;
        travelAnim.duration = Config.animDurationLong * (active ? 2 : 1.5);
        travelAnim.start();
        growAnim.to = active ? 1 : 0;
        growAnim.restart();
    }

    onMotionOnChanged: {
        if (motionOn)
            return;
        bounceAnim.stop();
        travelAnim.stop();
        lift = 0;
        stretch = 0;
        travel = 0;
        grow = 0;
    }

    NumberAnimation {
        id: travelAnim
        target: root
        property: "travel"
        easing.type: Easing.InOutCubic
        onStopped: root.travel = root.travel >= 1 ? 0 : root.travel
    }

    // The dot grows once it is home (the ride takes the first part)
    SequentialAnimation {
        id: growAnim

        property real to: 0

        PauseAnimation {
            duration: root.active && root.icon !== "distro" ? Config.animDurationLong * 2 : 0
        }
        NumberAnimation {
            target: root
            property: "grow"
            to: growAnim.to
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 4
        }
    }

    SequentialAnimation {
        running: root.motionOn && root.active && root.grow === 1
        loops: 2
        onRunningChanged: {
            if (!running)
                root.breath = 0;
        }

        NumberAnimation {
            target: root
            property: "breath"
            to: 1
            duration: Config.animDurationLong * 3
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "breath"
            to: 0
            duration: Config.animDurationLong * 3
            easing.type: Easing.InOutSine
        }
    }

    component Step: NumberAnimation {
        target: root
        duration: Config.animDurationShort
    }

    SequentialAnimation {
        id: bounceAnim

        // Anticipation: crouch
        Step {
            property: "stretch"
            to: -0.25
            easing.type: Easing.OutQuad
        }
        // Leap, stretched, easing into the apex
        ParallelAnimation {
            Step {
                property: "lift"
                to: 0.4
                duration: Config.animDuration
                easing.type: Easing.OutQuad
            }
            SequentialAnimation {
                Step {
                    property: "stretch"
                    to: 0.3
                    easing.type: Easing.OutQuad
                }
                Step {
                    property: "stretch"
                    to: 0
                    easing.type: Easing.InOutQuad
                }
            }
        }
        // Fall, stretching again
        ParallelAnimation {
            Step {
                property: "lift"
                to: 0
                duration: Config.animDuration
                easing.type: Easing.InQuad
            }
            Step {
                property: "stretch"
                to: 0.2
                duration: Config.animDuration
                easing.type: Easing.InQuad
            }
        }
        // Impact
        Step {
            property: "stretch"
            to: -0.35
            duration: Config.animDurationShort / 2
            easing.type: Easing.OutQuad
        }
        // Small rebound
        ParallelAnimation {
            Step {
                property: "lift"
                to: 0.1
                easing.type: Easing.OutQuad
            }
            Step {
                property: "stretch"
                to: 0.1
                easing.type: Easing.OutQuad
            }
        }
        Step {
            property: "lift"
            to: 0
            easing.type: Easing.InQuad
        }
        Step {
            property: "stretch"
            to: -0.12
            duration: Config.animDurationShort / 2
        }
        Step {
            property: "stretch"
            to: 0
            duration: Config.animDuration
            easing.type: Easing.OutBack
        }
    }

    // Line draws itself when the bar starts, then the dot pops in
    SequentialAnimation {
        id: startAnim

        Step {
            property: "draw"
            from: 0
            to: 1
            duration: Config.animDurationLong * 3
            easing.type: Easing.InOutCubic
        }
        Step {
            property: "pop"
            from: 0
            to: 1
            duration: Config.animDurationLong
            easing.type: Easing.OutBack
            easing.overshoot: 3
        }
    }

    Component.onCompleted: {
        if (!motionOn)
            return;
        draw = 0;
        pop = 0;
        startDelay.start();
    }

    // The bar is built before it shows up (the shell is still loading), so
    // the drawing waits a moment to be seen
    Timer {
        id: startDelay
        interval: Config.animDurationLong * 2
        onTriggered: startAnim.start()
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

        // Squeezed while pressed, around the center
        scale: 1 - root.press * 0.15

        LyneLogo {
            id: logo
            anchors.centerIn: parent
            height: Config.fontSizeNormal
            visible: root.icon !== "distro"
            dotLift: root.lift
            dotStretch: root.stretch
            dotScale: (1 + root.grow * (0.25 + root.breath * 0.12)) * root.pop
            lineDraw: root.draw
            travel: root.travel
            travelReverse: root.travelReverse
        }

        // The glyph can't split into line and dot, so it moves as a whole:
        // bounces with the same squash & stretch, grows and breathes
        Text {
            id: glyph
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -root.lift * Config.fontSizeNormal
            visible: root.icon === "distro"
            text: root.distroGlyph
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            color: Config.accentColor
            opacity: root.draw
            scale: (1 + root.grow * (0.1 + root.breath * 0.06)) * (0.5 + root.pop * 0.5)
            transform: Scale {
                origin.x: glyph.width / 2
                origin.y: glyph.height
                xScale: 1 - root.stretch * 0.6
                yScale: 1 + root.stretch
            }
        }
    }
}
