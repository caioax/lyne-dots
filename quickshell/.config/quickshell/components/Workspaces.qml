import QtQuick
import Quickshell
import qs.config
import "workspaces"

// Bar workspace indicator: the monitor's workspace state (WorkspacesModel)
// drawn by the style picked in bar.workspaces.style, then the workspaces of
// a disconnected monitor staying here (GuestChips) and the special
// workspace badge, each sliding out beside it while there's one.
Item {
    id: root

    // Read on the Item: the QsWindow attached property doesn't resolve on the
    // non-visual model
    readonly property var parentScreen: QsWindow.window?.screen ?? null

    WorkspacesModel {
        id: workspacesModel
        screen: root.parentScreen
    }

    readonly property var styles: ({
            "pills": pillsStyle,
            "numbers": numbersStyle,
            "dots": dotsStyle,
            "groups": groupsStyle,
            "icons": iconsStyle
        })

    implicitWidth: strip.implicitWidth + guestSlot.width + badgeSlot.width
    implicitHeight: strip.implicitHeight

    // One workspace per notch; touchpads add up small deltas to a notch
    WheelHandler {
        property real accumulated: 0

        enabled: Config.barWorkspaceScroll
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            accumulated += event.angleDelta.y;
            if (Math.abs(accumulated) < 120)
                return;
            workspacesModel.step(accumulated > 0 ? -1 : 1);
            accumulated = 0;
        }
    }

    Loader {
        id: strip
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: root.styles[Config.barWorkspaceStyle] ?? pillsStyle
        // Steps back while the special workspace has the focus
        opacity: workspacesModel.specialActive ? 0.6 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
            }
        }
    }

    // Opens to the chips' width while this monitor holds guest workspaces
    Item {
        id: guestSlot
        readonly property int gap: Math.round(Config.padding * 2 / 3)

        x: strip.implicitWidth
        width: guests.shown ? gap + guests.implicitWidth : 0
        height: parent.height
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        GuestChips {
            id: guests
            model: workspacesModel
            x: guestSlot.gap
            anchors.verticalCenter: parent.verticalCenter
            opacity: shown ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.animDurationShort
                }
            }
        }
    }

    // Opens to the badge's width while a special workspace is shown
    Item {
        id: badgeSlot
        readonly property int gap: Math.round(Config.padding * 2 / 3)

        x: strip.implicitWidth + guestSlot.width
        width: badge.shown ? gap + badge.implicitWidth : 0
        height: parent.height

        Behavior on width {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        SpecialBadge {
            id: badge
            model: workspacesModel
            x: badgeSlot.gap
            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            height: implicitHeight
            // Grows out of the strip and shrinks back into it with the slot
            transformOrigin: Item.Left
            scale: shown ? 1 : 0.5
        }
    }

    Component {
        id: pillsStyle
        PillsStyle {
            model: workspacesModel
            count: Config.barWorkspaceCount
            hideEmpty: Config.barWorkspaceHideEmpty
        }
    }

    Component {
        id: numbersStyle
        NumbersStyle {
            model: workspacesModel
            count: Config.barWorkspaceCount
            hideEmpty: Config.barWorkspaceHideEmpty
        }
    }

    Component {
        id: dotsStyle
        DotsStyle {
            model: workspacesModel
            count: Config.barWorkspaceCount
            hideEmpty: Config.barWorkspaceHideEmpty
        }
    }

    Component {
        id: groupsStyle
        GroupsStyle {
            model: workspacesModel
            count: Config.barWorkspaceCount
            hideEmpty: Config.barWorkspaceHideEmpty
        }
    }

    Component {
        id: iconsStyle
        IconsStyle {
            model: workspacesModel
            count: Config.barWorkspaceCount
            hideEmpty: Config.barWorkspaceHideEmpty
        }
    }
}
