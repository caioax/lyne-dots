pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../../components/"

// Power profile: one card per profile, why performance is held back and the
// apps holding a profile (PowerProfileService)
Item {
    id: root

    signal backRequested
    signal closeWindow

    readonly property string profile: PowerProfileService.profile

    Layout.fillWidth: true
    implicitHeight: main.implicitHeight

    ColumnLayout {
        id: main

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Config.spacing

        PageHeader {
            Layout.bottomMargin: Config.padding
            icon: PowerProfileService.icon(root.profile)
            iconColor: PowerProfileService.tone(root.profile)
            title: I18n.tr("Power profile")
            subtitle: {
                const name = PowerProfileService.label(root.profile);
                switch (PowerProfileService.autoReason) {
                case "lowBattery":
                    return I18n.tr("%1 · low battery, until you plug in", name);
                case "unplugged":
                    return I18n.tr("%1 · on battery, until you plug in", name);
                default:
                    return name;
                }
            }
            onBackClicked: root.backRequested()

            // md-cog
            ActionButton {
                size: Config.fontSizeIconSmall * 2
                icon: "\u{f0493}"
                onClicked: {
                    SettingsService.open("powerProfiles");
                    root.closeWindow();
                }
            }
        }

        // ========== PROFILES ==========
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing

            Repeater {
                model: PowerProfileService.profiles

                Rectangle {
                    id: option

                    required property string modelData
                    readonly property bool current: modelData === root.profile
                    readonly property color tone: PowerProfileService.tone(modelData)

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: optionColumn.implicitHeight + Config.padding * 4
                    radius: Config.radiusLarge
                    color: current ? Qt.alpha(tone, 0.12) : optionHover.hovered ? Config.surface1Color : Config.surface0Color
                    border.width: 1
                    border.color: Qt.alpha(tone, current ? 0.6 : 0)

                    Behavior on color {
                        enabled: !Config.themeTransitioning
                        ColorAnimation {
                            duration: Config.animDuration
                        }
                    }

                    Behavior on border.color {
                        enabled: !Config.themeTransitioning
                        ColorAnimation {
                            duration: Config.animDuration
                        }
                    }

                    ColumnLayout {
                        id: optionColumn

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Config.padding * 2
                        spacing: Config.padding

                        Text {
                            text: PowerProfileService.icon(option.modelData)
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeIconLarge
                            color: option.current ? option.tone : Config.subtextColor
                        }

                        Text {
                            Layout.fillWidth: true
                            text: PowerProfileService.label(option.modelData)
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            font.bold: true
                            color: Config.textColor
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: PowerProfileService.description(option.modelData)
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.subtextColor
                            wrapMode: Text.WordWrap
                        }
                    }

                    HoverHandler {
                        id: optionHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: PowerProfileService.setProfile(option.modelData)
                    }
                }
            }
        }

        // ========== DEGRADED ==========
        Card {
            Layout.fillWidth: true
            visible: PowerProfileService.degradation !== ""
            border.width: 1
            border.color: Qt.alpha(Config.warningColor, 0.6)

            // md-thermometer_alert
            CardHeader {
                icon: "\u{f0e01}"
                iconColor: Config.warningColor
                title: I18n.tr("Performance limited")
                subtitle: PowerProfileService.degradation
            }
        }

        // ========== HOLDS ==========
        Card {
            Layout.fillWidth: true
            visible: PowerProfileService.holds.length > 0

            // md-lock_clock
            CardHeader {
                icon: "\u{f097f}"
                title: I18n.tr("Held by apps")
                subtitle: I18n.tr("Picking a profile releases them")
            }

            Repeater {
                model: PowerProfileService.holds

                RowLayout {
                    id: holdRow

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Config.spacing

                    Text {
                        text: PowerProfileService.icon(holdRow.modelData.profile)
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconSmall
                        color: PowerProfileService.tone(holdRow.modelData.profile)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: holdRow.modelData.app || I18n.tr("An app")
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        color: Config.textColor
                        elide: Text.ElideRight
                    }

                    Text {
                        text: PowerProfileService.label(holdRow.modelData.profile)
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                    }
                }
            }
        }
    }
}
