pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import "../../components/"

// Welcome screen: the steps of WelcomeService one at a time, with Skip,
// Back and Next below. A regular window (floated by a Hyprland rule), like
// Settings, so it can be moved aside while the changes show up
FloatingWindow {
    id: root

    readonly property int maxContentWidth: Config.fontSizeNormal * 48
    readonly property int buttonSize: Config.fontSizeIconSmall * 2
    // Same as the size of the window rule in hypr/conf/rules.lua (which wins)
    readonly property size defaultSize: Qt.size(760, 600)

    // Step id (WelcomeService.steps) -> component
    readonly property var stepComponents: ({
            intro: introStep,
            keyboard: keyboardStep,
            done: doneStep
        })

    // 1 going forward, -1 going back: the side the new step slides in from
    property int _direction: 1
    property int _shownStep: -1

    function showStep() {
        const index = WelcomeService.currentStep;
        _direction = index >= _shownStep ? 1 : -1;
        _shownStep = index;
        flick.contentY = 0;
        stepLoader.sourceComponent = null;
        stepLoader.opacity = 0;
        stepLoader.sourceComponent = stepComponents[WelcomeService.currentEntry.id];
    }

    Component.onCompleted: showStep()

    Connections {
        target: WelcomeService

        function onCurrentStepChanged() {
            root.showStep();
        }
    }

    title: "Welcome"
    implicitWidth: defaultSize.width
    implicitHeight: defaultSize.height
    minimumSize: Qt.size(600, 480)
    color: Config.backgroundTransparentColor
    visible: true

    onVisibleChanged: {
        if (!visible)
            WelcomeService.close();
    }

    // Steps may use Escape first (close a popup) through an optional
    // handleEscape(): bool
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (stepLoader.item?.handleEscape?.())
                return;
            WelcomeService.close();
        }
    }

    Component {
        id: introStep
        WelcomeIntro {}
    }

    Component {
        id: keyboardStep
        WelcomeKeyboard {}
    }

    Component {
        id: doneStep
        WelcomeDone {}
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Config.padding * 2
        spacing: Config.spacing * 2

        Flickable {
            id: flick

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: Math.max(height, stepLoader.implicitHeight + Config.padding * 4)
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: QsScrollBar {}

            // Centered when shorter than the window
            Loader {
                id: stepLoader

                readonly property real restY: Math.max(Config.padding * 2, Math.round((flick.height - implicitHeight) / 2))

                x: Math.round((flick.width - width) / 2)
                width: Math.min(flick.width - Config.padding * 4, root.maxContentWidth)
                onLoaded: enterAnim.restart()
            }

            ParallelAnimation {
                id: enterAnim

                NumberAnimation {
                    target: stepLoader
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Config.animDuration
                }

                NumberAnimation {
                    target: stepLoader
                    property: "y"
                    from: stepLoader.restY + root._direction * Config.spacing * 3
                    to: stepLoader.restY
                    duration: Config.animDurationLong
                    easing.type: Easing.OutExpo
                }

                onFinished: stepLoader.y = Qt.binding(() => stepLoader.restY)
            }
        }

        // ================= FOOTER =================
        Item {
            Layout.fillWidth: true
            implicitHeight: root.buttonSize

            ActionButton {
                anchors.left: parent.left
                visible: !WelcomeService.isLast
                size: root.buttonSize
                text: "Skip"
                baseColor: Qt.alpha(Config.surface2Color, 0)
                textColor: Config.subtextColor
                hoverTextColor: Config.textColor
                onClicked: WelcomeService.close()
            }

            // Where you are: one dot per step, the current one stretched
            Row {
                anchors.centerIn: parent
                spacing: Config.padding

                Repeater {
                    model: WelcomeService.steps

                    Rectangle {
                        required property int index

                        readonly property bool current: index === WelcomeService.currentStep

                        anchors.verticalCenter: parent.verticalCenter
                        width: current ? Config.padding * 3 : Config.padding
                        height: Config.padding
                        radius: height / 2
                        color: current ? Config.accentColor : index < WelcomeService.currentStep ? Qt.alpha(Config.accentColor, 0.5) : Config.surface2Color

                        Behavior on width {
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on color {
                            enabled: !Config.themeTransitioning
                            ColorAnimation {
                                duration: Config.animDuration
                            }
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                spacing: Config.spacing

                // md-chevron_left
                ActionButton {
                    visible: !WelcomeService.isFirst
                    size: root.buttonSize
                    icon: "\u{f0141}"
                    text: "Back"
                    onClicked: WelcomeService.back()
                }

                // md-chevron_right / md-check
                ActionButton {
                    size: root.buttonSize
                    icon: WelcomeService.isLast ? "\u{f012c}" : "\u{f0142}"
                    text: WelcomeService.isFirst ? "Get started" : WelcomeService.isLast ? "Finish" : "Next"
                    baseColor: Config.accentColor
                    hoverColor: Qt.lighter(Config.accentColor, 1.1)
                    textColor: Config.textReverseColor
                    onClicked: WelcomeService.next()
                }
            }
        }
    }
}
