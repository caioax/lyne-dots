pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services
import "../../components/"
import "../../components/quickSettings"

BarButton {
    id: root

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    active: QuickSettingsService.screen !== "" && QuickSettingsService.screen === screenName
    contentItem: style
    onClicked: QuickSettingsService.toggle("", screenName)
    onRightClicked: NotificationService.toggleDnd()

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
            enabled: !Config.themeTransitioning
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
        screen: root.QsWindow.window?.screen ?? null
        anchorItem: root
    }
}
