pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import "../../../components/quickSettings/"

// The Quick Settings button over the current wallpaper with the real style,
// drawn from a fixed sample: Wi-Fi, a Bluetooth device, a microphone in use,
// the battery at 72% and two unread notifications. The indicators switched
// off in Settings stay off here too.
ClippingRectangle {
    id: root

    // Quick Settings style: "icons", "pill", "chips" or "minimal"
    property string value

    readonly property var styles: ({
            "icons": iconsStyle,
            "pill": pillStyle,
            "chips": chipsStyle,
            "minimal": minimalStyle
        })

    radius: Config.radius
    color: Config.surface2Color

    QsIndicatorsModel {
        id: sample
        live: false
        sampleIndicators: ({
                "network": {
                    shown: true,
                    icon: "󰤨",
                    tone: "normal",
                    alert: false
                },
                "bluetooth": {
                    shown: true,
                    icon: "󰂱",
                    tone: "normal",
                    alert: false,
                    count: 1
                },
                "volume": {
                    shown: false,
                    icon: "󰖁",
                    tone: "normal",
                    alert: false
                },
                "mic": {
                    shown: true,
                    icon: "󰍬",
                    tone: "warning",
                    alert: true
                },
                "battery": {
                    shown: true,
                    icon: "󰂀",
                    tone: "normal",
                    alert: false,
                    percentage: 72,
                    charging: false
                },
                "notifications": {
                    shown: true,
                    icon: "󰂚",
                    tone: "normal",
                    alert: false,
                    dnd: false,
                    count: 2
                }
            })
    }

    Image {
        anchors.fill: parent
        source: WallpaperService.currentWallpaper !== "" ? "file://" + WallpaperService.currentWallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width * 2, height * 2)
        asynchronous: true
    }

    // Below the selected tile's check (TemplateTile: padding inside the tile,
    // fontSizeLarge + padding tall) plus a small gap
    readonly property int checkClearance: Config.padding * 2 + Config.fontSizeLarge + Math.round(Config.padding / 2)

    // Bar piece at its real size, scaled down to fit the tile if needed,
    // centered across and low enough to clear the check in the corner
    Rectangle {
        id: bar

        readonly property real fit: Math.min(1, (root.width - Config.spacing * 2) / width, (root.height - root.checkClearance - Config.spacing) / height)

        anchors.horizontalCenter: parent.horizontalCenter
        // Scaling keeps the center, so the drawn top sits lower than y
        y: Math.max((root.height - height) / 2, root.checkClearance - height * (1 - fit) / 2)
        width: button.width + Config.padding * 2
        height: Config.barIslandHeight
        radius: height / 2
        color: Config.backgroundColor
        scale: fit

        // Like the BarButton around the real one
        Rectangle {
            id: button

            anchors.centerIn: parent
            width: (style.item?.implicitWidth ?? 0) + Config.padding * 2
            height: Config.barButtonHeight
            radius: height / 2
            color: Qt.alpha(Config.surface1Color, 0)

            Loader {
                id: style
                anchors.centerIn: parent
                sourceComponent: root.styles[root.value] ?? iconsStyle
            }
        }
    }

    Component {
        id: iconsStyle
        IconsStyle {
            model: sample
        }
    }

    Component {
        id: pillStyle
        PillStyle {
            model: sample
        }
    }

    Component {
        id: chipsStyle
        ChipsStyle {
            model: sample
        }
    }

    Component {
        id: minimalStyle
        MinimalStyle {
            model: sample
        }
    }
}
