pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../quickSettings/"
import "../../../components/"
import "../../notifications/"

Item {
    id: root

    // Height the page may use; the notification list scrolls within what's left
    property real availableHeight: 0
    readonly property bool hasNotifications: NotificationService.count > 0

    signal closeWindow

    // Brightness slider: every monitor (brightness.quickSettings "all"), or
    // one at a time, starting at the one the keys adjust
    readonly property bool allMonitors: Config.brightnessQuickSettings === "all"
    // Picked with the chip until the window closes
    property var pickedMonitor: null
    readonly property var brightnessMonitor: pickedMonitor?.available ? pickedMonitor : BrightnessService.primary

    function nextBrightnessMonitor() {
        const list = BrightnessService.controllable;
        pickedMonitor = list[(list.indexOf(brightnessMonitor) + 1) % list.length] ?? null;
    }

    // md-laptop / md-monitor
    function monitorIcon(monitor: var): string {
        return monitor.internal ? "\u{f0322}" : "\u{f0379}";
    }

    Layout.fillWidth: true
    implicitHeight: main.implicitHeight + (hasNotifications ? notifList.anchors.topMargin + notifList.implicitHeight : 0)

    ColumnLayout {
        id: main
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Config.spacing

        ProfileCard {
            Layout.fillWidth: true
            onCloseWindow: root.closeWindow()
        }

        // ========== TOGGLES ==========
        Card {
            Layout.fillWidth: true

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Config.spacing
                rowSpacing: Config.spacing

                Repeater {
                    model: QuickSettingsService.tiles

                    QuickSettingsTile {
                        required property var modelData

                        icon: modelData.icon
                        label: modelData.label
                        subLabel: modelData.status
                        active: modelData.active
                        hasDetails: modelData.page !== ""
                        onToggled: modelData.toggle()
                        onOpenDetails: QuickSettingsService.showPage(modelData.page)
                    }
                }
            }
        }

        // ========== SOUND & DISPLAY ==========
        Card {
            Layout.fillWidth: true

            CardHeader {
                icon: "󰓃"
                title: "Output"
                subtitle: AudioService.deviceName(AudioService.sink)

                ActionButton {
                    size: Config.fontSizeNormal + Config.padding * 2
                    icon: "󰅂"
                    iconSize: Config.fontSizeNormal
                    textColor: Config.subtextColor
                    hoverTextColor: Config.accentColor
                    onClicked: QuickSettingsService.showPage("sound")
                }
            }

            QsSlider {
                icon: AudioService.systemIcon
                value: AudioService.volume
                to: AudioService.maxVolume
                stepSize: AudioService.volumeStep
                fillColor: AudioService.muted ? Config.surface3Color : Config.accentColor
                onMoved: val => AudioService.setVolume(val)
                onIconClicked: AudioService.toggleMute()
            }

            QsSlider {
                visible: AudioService.sourceReady
                icon: AudioService.sourceIcon
                value: AudioService.sourceVolume
                fillColor: AudioService.sourceMuted ? Config.surface3Color : Config.accentColor
                onMoved: val => AudioService.setSourceVolume(val)
                onIconClicked: AudioService.toggleSourceMute()
            }

            // Brightness (brightness.quickSettings): the focused monitor with
            // a chip that cycles through the others, or one slider per
            // monitor, named when there's more than one
            Repeater {
                // One fixed row while switching, so it animates instead of being rebuilt
                model: root.allMonitors ? BrightnessService.controllable : root.brightnessMonitor ? 1 : 0

                ColumnLayout {
                    id: monitorBrightness

                    required property var modelData
                    readonly property var monitor: root.allMonitors ? modelData : root.brightnessMonitor

                    Layout.fillWidth: true
                    spacing: Math.round(Config.spacing / 2)

                    RowLayout {
                        visible: root.allMonitors && BrightnessService.controllable.length > 1
                        Layout.fillWidth: true
                        Layout.leftMargin: Math.round(Config.padding / 2)
                        spacing: Config.spacing

                        Text {
                            text: root.monitorIcon(monitorBrightness.monitor)
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.subtextColor
                        }

                        Text {
                            Layout.fillWidth: true
                            text: monitorBrightness.monitor.label
                            elide: Text.ElideRight
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.subtextColor
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Config.spacing

                        QsSlider {
                            icon: BrightnessService.iconFor(value)
                            value: monitorBrightness.monitor.brightness
                            stepSize: Config.brightnessStep
                            // With the chip, the percentage sits inside it
                            showPercentage: !monitorChip.visible
                            onMoved: val => monitorBrightness.monitor.set(val)
                            onIconClicked: monitorBrightness.monitor.toggle()
                        }

                        // Percentage and next monitor; hovering shows the
                        // current one's name
                        Rectangle {
                            id: monitorChip

                            readonly property bool hovered: chipMouse.containsMouse

                            visible: !root.allMonitors && BrightnessService.controllable.length > 1
                            Layout.preferredHeight: Config.fontSizeIconSmall * 2
                            Layout.preferredWidth: chipRow.implicitWidth + Config.padding * 2
                            radius: Config.radiusLarge
                            color: hovered ? Config.surface2Color : Config.surface1Color

                            Behavior on color {
                                enabled: !Config.themeTransitioning
                                ColorAnimation {
                                    duration: Config.animDurationShort
                                }
                            }

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: Math.round(Config.padding / 2)

                                Text {
                                    text: root.monitorIcon(monitorBrightness.monitor)
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeNormal
                                    color: Config.textColor
                                }

                                Text {
                                    Layout.preferredWidth: monitorChip.hovered ? Math.min(implicitWidth, Config.fontSizeSmall * 12) : 0
                                    text: monitorBrightness.monitor.label
                                    // Clipped while it slides open, elided only when too long
                                    elide: nameAnim.running ? Text.ElideNone : Text.ElideRight
                                    clip: true
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeSmall
                                    font.bold: true
                                    color: Config.textColor

                                    Behavior on Layout.preferredWidth {
                                        NumberAnimation {
                                            id: nameAnim
                                            duration: Config.animDurationShort
                                            easing.type: Easing.OutQuad
                                        }
                                    }
                                }

                                Text {
                                    // Fixed width so the chip doesn't jump between values
                                    Layout.preferredWidth: percentMetrics.width
                                    horizontalAlignment: Text.AlignRight
                                    text: Math.round(monitorBrightness.monitor.brightness * 100) + "%"
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeSmall
                                    font.bold: true
                                    color: Config.subtextColor

                                    TextMetrics {
                                        id: percentMetrics
                                        font.family: Config.font
                                        font.pixelSize: Config.fontSizeSmall
                                        font.bold: true
                                        text: "100%"
                                    }
                                }

                                // md-chevron_right
                                Text {
                                    text: "\u{f0142}"
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeNormal
                                    color: Config.subtextColor
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.nextBrightnessMonitor()
                            }
                        }
                    }
                }
            }
        }
    }

    // ========== NOTIFICATIONS ==========
    // Newest apps only; "See all" opens the notifications page
    NotificationList {
        id: notifList
        visible: root.hasNotifications
        anchors.top: main.bottom
        anchors.topMargin: main.spacing
        width: parent.width
        preview: true
        maxHeight: root.availableHeight - main.implicitHeight - anchors.topMargin
        onActionTriggered: root.closeWindow()
        onOpenPageRequested: QuickSettingsService.showPage("notifications")
    }
}
