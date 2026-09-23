pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../../components/"

Item {
    id: root

    signal backRequested

    readonly property bool isOn: BrightnessService.nightLightEnabled
    readonly property int temperature: BrightnessService.nightLightTemperature
    readonly property color currentColor: BrightnessService.temperatureColor(temperature)
    readonly property int controlSize: Config.fontSizeIconSmall * 2

    // Warm → cool, the same direction as the slider
    readonly property var presets: [
        {
            "label": "Candle",
            "temp": 2500
        },
        {
            "label": "Warm",
            "temp": 3500
        },
        {
            "label": "Neutral",
            "temp": 4500
        },
        {
            "label": "Cool",
            "temp": 5500
        }
    ]
    readonly property string presetName: presets.find(p => p.temp === temperature)?.label ?? "Custom"

    Layout.fillWidth: true
    implicitHeight: main.implicitHeight

    ColumnLayout {
        id: main

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Config.spacing

        PageHeader {
            Layout.bottomMargin: Config.padding
            icon: BrightnessService.nightLightIcon
            iconColor: root.isOn ? Config.warningColor : Config.subtextColor
            title: "Night light"
            subtitle: root.isOn ? "On · " + root.temperature + "K" : "Off"
            onBackClicked: root.backRequested()

            QsSwitch {
                checked: root.isOn
                onToggled: BrightnessService.toggleNightLight()
            }
        }

        // ========== CURRENT TEMPERATURE ==========
        Card {
            Layout.fillWidth: true
            border.width: 1
            border.color: root.isOn ? Qt.alpha(Config.warningColor, 0.6) : "transparent"

            Behavior on border.color {
                ColorAnimation {
                    duration: Config.animDuration
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Config.spacing * 2

                // Swatch of the applied color, with a soft halo while on
                Item {
                    implicitWidth: Config.fontSizeIconLarge * 2
                    implicitHeight: implicitWidth

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: root.currentColor
                        opacity: root.isOn ? 0.25 : 0
                        scale: 1.2

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Config.animDuration
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: root.isOn ? root.currentColor : Config.surface1Color

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDuration
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: BrightnessService.nightLightIcon
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeIcon
                            color: root.isOn ? Config.textReverseColor : Config.subtextColor
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: root.temperature + "K"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconLarge
                        font.bold: true
                        color: root.isOn ? Config.textColor : Config.subtextColor
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.isOn ? root.presetName + " · less blue light" : "Off · turn on to reduce blue light"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ========== TEMPERATURE ==========
        Card {
            Layout.fillWidth: true
            spacing: Config.spacing + Config.padding

            CardHeader {
                icon: "󰔏"
                iconColor: Config.warningColor
                title: "Temperature"
                subtitle: root.presetName
            }

            // Gradient slider: warm on the left, cool on the right
            Item {
                id: slider

                readonly property real range: BrightnessService.nightLightMax - BrightnessService.nightLightMin
                readonly property real position: (root.temperature - BrightnessService.nightLightMin) / range
                readonly property int thumbSize: Config.fontSizeLarge + Config.padding

                function setFromX(x: real) {
                    const p = Math.max(0, Math.min(1, (x - thumbSize / 2) / (width - thumbSize)));
                    // Steps of 100K keep hyprsunset calls sane while dragging
                    BrightnessService.setNightLightTemperature(Math.round((BrightnessService.nightLightMin + p * range) / 100) * 100);
                }

                Layout.fillWidth: true
                implicitHeight: thumbSize

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: Config.padding * 2
                    radius: height / 2
                    opacity: root.isOn ? 1 : 0.5

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: BrightnessService.temperatureColor(BrightnessService.nightLightMin)
                        }
                        GradientStop {
                            position: 0.5
                            color: BrightnessService.temperatureColor(BrightnessService.nightLightMin + slider.range / 2)
                        }
                        GradientStop {
                            position: 1
                            color: BrightnessService.temperatureColor(BrightnessService.nightLightMax)
                        }
                    }
                }

                Rectangle {
                    x: slider.position * (slider.width - width)
                    anchors.verticalCenter: parent.verticalCenter
                    width: slider.thumbSize
                    height: width
                    radius: width / 2
                    color: root.currentColor
                    border.width: 2
                    border.color: Config.textColor
                    scale: sliderMouse.pressed ? 1.15 : 1

                    Behavior on x {
                        enabled: !sliderMouse.pressed
                        NumberAnimation {
                            duration: Config.animDurationShort
                            easing.type: Easing.OutQuad
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Config.animDurationShort
                        }
                    }
                }

                MouseArea {
                    id: sliderMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => slider.setFromX(mouse.x)
                    onPositionChanged: mouse => {
                        if (pressed)
                            slider.setFromX(mouse.x);
                    }
                    onWheel: wheel => BrightnessService.setNightLightTemperature(root.temperature + (wheel.angleDelta.y > 0 ? 100 : -100))
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Warmer · " + BrightnessService.nightLightMin + "K"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: BrightnessService.nightLightMax + "K · Cooler"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }
            }

            // Presets (turn night light on when picked)
            RowLayout {
                Layout.fillWidth: true
                spacing: Config.spacing

                Repeater {
                    model: root.presets

                    Rectangle {
                        id: preset

                        required property var modelData
                        readonly property bool selected: root.temperature === modelData.temp
                        readonly property color swatch: BrightnessService.temperatureColor(modelData.temp)

                        Layout.fillWidth: true
                        implicitHeight: root.controlSize
                        radius: Config.radius
                        color: {
                            if (selected)
                                return Qt.alpha(swatch, 0.18);
                            return presetMouse.containsMouse ? Config.surface2Color : Config.surface1Color;
                        }
                        border.width: selected ? 1 : 0
                        border.color: swatch

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDurationShort
                            }
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Config.padding

                            Rectangle {
                                implicitWidth: Config.padding * 2
                                implicitHeight: implicitWidth
                                radius: width / 2
                                color: preset.swatch
                            }

                            Text {
                                text: preset.modelData.label
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                font.bold: preset.selected
                                color: preset.selected ? Config.textColor : Config.subtextColor
                            }
                        }

                        MouseArea {
                            id: presetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                BrightnessService.setNightLightTemperature(preset.modelData.temp);
                                if (!root.isOn)
                                    BrightnessService.enableNightLight();
                            }
                        }
                    }
                }
            }
        }
    }
}
