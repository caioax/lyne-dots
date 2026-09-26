import QtQuick
import Quickshell
import qs.config
import "workspaces"

// Bar workspace indicator: the monitor's workspace state (WorkspacesModel)
// drawn by a style, swapped for the special workspace badge while one is open.
Item {
    id: root

    // Read on the Item: the QsWindow attached property doesn't resolve on the
    // non-visual model
    readonly property var parentScreen: QsWindow.window?.screen ?? null

    WorkspacesModel {
        id: workspacesModel
        screen: root.parentScreen
    }

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

    PillsStyle {
        id: strip
        model: workspacesModel
        count: Config.barWorkspaceCount
        visible: !workspacesModel.specialActive
        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
    }
}
