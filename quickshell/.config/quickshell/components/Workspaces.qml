import QtQuick
import Quickshell
import qs.config
import "workspaces"

// Bar workspace indicator: the monitor's workspace state (WorkspacesModel)
// drawn by the style picked in bar.workspaces.style, swapped for the special
// workspace badge while one is open.
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
            "numbers": numbersStyle
        })

    implicitWidth: workspacesModel.specialActive ? badge.width : strip.implicitWidth
    implicitHeight: strip.implicitHeight

    SpecialBadge {
        id: badge
        model: workspacesModel
        anchors.centerIn: parent
        anchors.verticalCenterOffset: shown ? 0 : Config.padding
        width: implicitWidth
        height: implicitHeight

        Behavior on anchors.verticalCenterOffset {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    Loader {
        id: strip
        visible: !workspacesModel.specialActive
        anchors.centerIn: parent
        sourceComponent: root.styles[Config.barWorkspaceStyle] ?? pillsStyle
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
}
