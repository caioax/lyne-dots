import QtQuick
import Quickshell
import qs.config
import "workspaces"

// Bar workspace indicator: the monitor's workspace state (WorkspacesModel)
// drawn by the style picked in bar.workspaces.style, with the special
// workspace badge sliding out beside it while one is open.
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

    implicitWidth: strip.implicitWidth + badgeSlot.width
    implicitHeight: strip.implicitHeight

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

    // Opens to the badge's width while a special workspace is shown
    Item {
        id: badgeSlot
        readonly property int gap: Math.round(Config.padding * 2 / 3)

        x: strip.implicitWidth
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
        }
    }

    Component {
        id: numbersStyle
        NumbersStyle {
            model: workspacesModel
            count: Config.barWorkspaceCount
        }
    }

    Component {
        id: dotsStyle
        DotsStyle {
            model: workspacesModel
            count: Config.barWorkspaceCount
        }
    }

    Component {
        id: groupsStyle
        GroupsStyle {
            model: workspacesModel
            count: Config.barWorkspaceCount
        }
    }

    Component {
        id: iconsStyle
        IconsStyle {
            model: workspacesModel
            count: Config.barWorkspaceCount
        }
    }
}
