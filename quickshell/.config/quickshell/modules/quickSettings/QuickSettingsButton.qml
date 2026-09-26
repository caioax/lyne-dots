pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services
import "../../components/"
import "../../components/quickSettings"

BarButton {
    id: root

    active: quickSettingsWindow.visible
    contentItem: style
    onClicked: toggleWindow()

    function toggleWindow() {
        quickSettingsWindow.visible = !quickSettingsWindow.visible;
    }
    onRightClicked: NotificationService.toggleDnd()

    // `qs ipc call notifications toggleWindow` opens it on the focused monitor only
    Connections {
        target: NotificationService

        function onWindowToggleRequested() {
            if (root.QsWindow.window?.screen?.name === Hyprland.focusedMonitor?.name)
                root.toggleWindow();
        }
    }

    QsIndicatorsModel {
        id: indicators
    }

    readonly property var styles: ({
            "icons": iconsStyle,
            "pill": pillStyle,
            "chips": chipsStyle,
            "minimal": minimalStyle
        })

    Loader {
        id: style
        anchors.centerIn: parent
        sourceComponent: root.styles[Config.barQsStyle] ?? iconsStyle

        property color iconColor: root.active ? Config.accentColor : Config.textColor

        Behavior on iconColor {
            ColorAnimation {
                duration: Config.animDuration
            }
        }
    }

    Component {
        id: iconsStyle
        IconsStyle {
            model: indicators
            iconColor: style.iconColor
        }
    }

    Component {
        id: pillStyle
        PillStyle {
            model: indicators
            iconColor: style.iconColor
        }
    }

    Component {
        id: chipsStyle
        ChipsStyle {
            model: indicators
            iconColor: style.iconColor
        }
    }

    Component {
        id: minimalStyle
        MinimalStyle {
            model: indicators
            iconColor: style.iconColor
        }
    }

    QuickSettingsWindow {
        id: quickSettingsWindow
        anchorItem: root
        visible: false
    }
}
