pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import "../../components/"

QsPopupWindow {
    id: root

    popupWidth: 680
    popupMaxHeight: 900
    anchorSide: "left"
    moduleName: "SystemMonitor"
    contentImplicitHeight: content.implicitHeight

    readonly property bool hasGpu: SystemMonitorService.gpuType !== "unknown"

    // Heavy collectors (GPU, processes, disk) only run while this is open
    onVisibleChanged: visible ? SystemMonitorService.acquire() : SystemMonitorService.release()

    ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: Config.spacing

        // ==================== HEADER ====================
        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: Config.radius
                color: Qt.alpha(Config.accentColor, 0.15)

                Text {
                    anchors.centerIn: parent
                    text: "󰍛"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    color: Config.accentColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: "System Monitor"
                    font.family: Config.font
                    font.bold: true
                    font.pixelSize: Config.fontSizeLarge
                    color: Config.textColor
                }

                Text {
                    Layout.fillWidth: true
                    text: SystemMonitorService.hostname + "  ·  " + SystemMonitorService.kernel
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                    elide: Text.ElideRight
                }
            }

            StatChip {
                icon: "󰅐"
                text: SystemMonitorService.uptime
                accent: Config.accentColor
            }

            // Hand off to Mission Center for per-process / per-device detail
            ActionButton {
                icon: "󰏌"
                text: "Mission Center"
                size: Config.fontSizeSmall * 2 + Config.padding
                iconSize: Config.fontSizeNormal
                textColor: Config.subtextColor
                hoverTextColor: Config.accentColor
                onClicked: {
                    root.closeWindow();
                    Quickshell.execDetached(["missioncenter"]);
                }
            }
        }

        // ==================== CARDS ====================
        RowLayout {
            Layout.fillWidth: true
            uniformCellSizes: true
            spacing: Config.spacing

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                spacing: Config.spacing

                CpuCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: !root.hasGpu
                }

                GpuCard {
                    visible: root.hasGpu
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                spacing: Config.spacing

                RowLayout {
                    Layout.fillWidth: true
                    uniformCellSizes: true
                    spacing: Config.spacing

                    MemoryCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    StorageCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }

                NetworkCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }

        ProcessCard {
            Layout.fillWidth: true
        }
    }
}
