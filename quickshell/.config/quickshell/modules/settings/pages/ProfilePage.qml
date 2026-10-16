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
        title: I18n.tr("Profile")

        SettingRow {
            id: avatarRow

            label: Quickshell.env("USER")
            description: ProfileService.avatar !== "" ? I18n.tr("Custom picture") : I18n.tr("No picture")
            path: "profile.avatar"

            ActionButton {
                icon: "\u{f11e3}"
                text: I18n.tr("Choose picture")
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

                // md-account
                Text {
                    anchors.centerIn: parent
                    visible: !avatarImage.visible
                    text: "\u{f0004}"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconLarge
                    color: Config.subtextColor
                }
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("Region")

        LanguageRow {
            label: I18n.tr("Language")
            description: I18n.tr("Dates and numbers follow the language too")
        }
    }

    SettingsGroup {
        title: I18n.tr("Weather")

        TextFieldRow {
            label: I18n.tr("City")
            description: I18n.tr("Leave empty to detect it from your IP address (ipwho.is); the forecast comes from Open-Meteo")
            path: "weather.city"
            placeholder: I18n.tr("Detect automatically")
        }

        SettingRow {
            id: weatherRow

            label: {
                if (WeatherService.loading)
                    return I18n.tr("Updating…");
                if (WeatherService.error !== "")
                    return WeatherService.error;
                return WeatherService.location !== "" ? WeatherService.location : I18n.tr("Weather unavailable");
            }
            description: WeatherService.available ? I18n.tr("%1° now, feels like %2°", Math.round(WeatherService.current.temp), Math.round(WeatherService.current.feelsLike)) : I18n.tr("Forecast from Open-Meteo")

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

            // md-refresh (the spinner stands in while updating)
            ActionButton {
                visible: !WeatherService.loading
                icon: "\u{f0450}"
                baseColor: weatherRow.controlColor
                onClicked: WeatherService.refresh(true)
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("Packages")

        SelectRow {
            label: I18n.tr("AUR helper")
            description: I18n.tr("Used by the installer and the all-update shell function")
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
