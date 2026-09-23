pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../../components/"

// Default output (sink) and input (source) device selection
Item {
    id: root

    signal backRequested

    Layout.fillWidth: true
    implicitHeight: main.implicitHeight

    function deviceIcon(node, isSink: bool): string {
        const name = AudioService.deviceName(node).toLowerCase();
        if (!isSink)
            return "󰍬";
        if (name.includes("hdmi") || name.includes("displayport"))
            return "󰍹";
        if (name.includes("headphone") || name.includes("headset") || name.includes("bluez"))
            return "󰋋";
        return "󰓃";
    }

    ColumnLayout {
        id: main
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Config.spacing

        PageHeader {
            Layout.bottomMargin: Config.padding
            icon: AudioService.systemIcon
            title: "Sound"
            subtitle: AudioService.deviceName(AudioService.sink)
            onBackClicked: root.backRequested()
        }

        DeviceSection {
            icon: "󰓃"
            title: "Output"
            devices: AudioService.sinks
            current: AudioService.sink
            isSink: true
        }

        DeviceSection {
            icon: "󰍬"
            title: "Input"
            devices: AudioService.sources
            current: AudioService.source
            isSink: false
        }
    }

    component DeviceSection: Card {
        id: section

        required property string icon
        required property string title
        required property var devices
        required property var current
        required property bool isSink

        Layout.fillWidth: true

        CardHeader {
            icon: section.icon
            title: section.title
            subtitle: section.devices.length + (section.devices.length === 1 ? " device" : " devices")
        }

        Text {
            visible: section.devices.length === 0
            text: "No devices"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }

        Repeater {
            model: section.devices

            DeviceRow {
                required property var modelData
                readonly property bool isCurrent: section.current !== null && modelData.id === section.current.id

                Layout.leftMargin: Config.padding
                Layout.rightMargin: Config.padding
                title: AudioService.deviceName(modelData)
                subtitle: isCurrent ? "In use" : ""
                icon: root.deviceIcon(modelData, section.isSink)
                active: isCurrent
                onClicked: {
                    if (section.isSink)
                        AudioService.setDefaultSink(modelData);
                    else
                        AudioService.setDefaultSource(modelData);
                }
            }
        }
    }
}
