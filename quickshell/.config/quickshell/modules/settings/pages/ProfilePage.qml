pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

ColumnLayout {
    id: root

    readonly property int avatarSize: Config.fontSizeLarge * 4

    spacing: Config.spacing * 3

    SettingsGroup {
        title: "Profile"

        SettingRow {
            id: avatarRow

            label: Quickshell.env("USER")
            description: ProfileService.avatar !== "" ? "Custom picture" : "Distro logo"
            path: "profile.avatar"

            ActionButton {
                icon: "\u{f11e3}"
                text: "Choose picture"
                baseColor: avatarRow.controlColor
                onClicked: ProfileService.pickAvatar()
            }

            leading: ClippingRectangle {
                implicitWidth: root.avatarSize
                implicitHeight: root.avatarSize
                radius: width / 2
                color: Config.surface1Color

                Image {
                    id: avatarImage
                    anchors.fill: parent
                    visible: status === Image.Ready
                    source: ProfileService.avatar !== "" ? "file://" + ProfileService.avatar : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(root.avatarSize * 2, root.avatarSize * 2)
                    asynchronous: true
                }

                // md-arch
                Text {
                    anchors.centerIn: parent
                    visible: !avatarImage.visible
                    text: "\u{f08c7}"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconLarge
                    color: Config.accentColor
                }
            }
        }
    }

    SettingsGroup {
        title: "Weather"

        TextFieldRow {
            label: "City"
            description: "Leave empty to detect it from your IP address"
            path: "weather.city"
            placeholder: "Detect automatically"
        }

        SettingRow {
            id: weatherRow

            label: {
                if (WeatherService.loading)
                    return "Updating…";
                if (WeatherService.error !== "")
                    return WeatherService.error;
                return WeatherService.location !== "" ? WeatherService.location : "Weather unavailable";
            }
            description: WeatherService.available ? Math.round(WeatherService.current.temp) + "° now, feels like " + Math.round(WeatherService.current.feelsLike) + "°" : "Forecast from Open-Meteo"

            Text {
                visible: WeatherService.available && !WeatherService.loading
                text: WeatherService.available ? WeatherService.icon(WeatherService.current.code, WeatherService.current.isDay) : ""
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: Config.accentColor
            }

            Spinner {
                running: WeatherService.loading
                size: Config.fontSizeIconSmall
                color: Config.subtextColor
            }

            // md-refresh
            ActionButton {
                icon: "\u{f0450}"
                baseColor: weatherRow.controlColor
                onClicked: WeatherService.refresh(true)
            }
        }
    }

    SettingsGroup {
        title: "Apps"

        TextFieldRow {
            label: "Editor"
            description: "Command used by lyne state to open the settings file"
            path: "system.editor"
            placeholder: "nvim"
        }

        SelectRow {
            label: "AUR helper"
            description: "Used by the installer and the all-update shell function"
            path: "system.aurHelper"
            options: [
                {
                    label: "yay",
                    value: "yay"
                },
                {
                    label: "paru",
                    value: "paru"
                }
            ]
        }
    }
}
