pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Glyphs for the status indicators; the battery drawn with its level in a
// tinted capsule of its own
RowLayout {
    id: root

    required property QsIndicatorsModel model
    // Tone "normal" (the button tints it while Quick Settings is open)
    property color iconColor: Config.textColor

    spacing: Config.spacing

    Repeater {
        model: root.model.order

        Loader {
            id: slot

            required property string modelData

            visible: root.model.indicators[modelData].shown
            Layout.alignment: Qt.AlignVCenter
            sourceComponent: modelData === "battery" ? capsule : glyph

            Component {
                id: glyph
                IndicatorGlyph {
                    model: root.model
                    indicatorId: slot.modelData
                    iconColor: root.iconColor
                }
            }

            Component {
                id: capsule
                Capsule {}
            }
        }
    }

    component Capsule: Rectangle {
        id: capsuleRect

        readonly property var battery: root.model.indicators.battery
        readonly property color levelColor: root.model.toneColor(battery.tone, root.iconColor)

        implicitHeight: Config.barButtonHeight - Config.padding
        implicitWidth: content.implicitWidth + Math.round(Config.padding * 1.5) * 2
        radius: height / 2
        color: Qt.alpha(levelColor, 0.14)

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration
            }
        }

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: Math.round(Config.spacing / 2)

            BatteryGauge {
                percentage: capsuleRect.battery.percentage
                charging: capsuleRect.battery.charging
                frameColor: root.iconColor
                fillColor: capsuleRect.levelColor
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                visible: root.model.batteryPercent
                text: capsuleRect.battery.percentage + "%"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: capsuleRect.levelColor
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
