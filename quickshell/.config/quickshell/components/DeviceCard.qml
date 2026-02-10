pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config

Rectangle {
    id: root

    // --- Required Properties ---
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property string statusText: ""

    // --- States ---
    property bool active: false
    property bool connecting: false
    property bool secured: false

    // --- Menu ---
    property bool showMenu: false
    property var menuModel: []

    // --- Signals ---
    signal clicked
    signal menuAction(string actionId)

    // --- Layout ---
    width: ListView.view ? ListView.view.width : 300
    height: 60
    radius: Config.radiusLarge

    // Colored border based on state
    border.width: 1
    border.color: {
        if (root.active)
            return Config.accentColor;
        if (root.connecting)
            return Config.warningColor;
        return "transparent";
    }

    // Background color with hover
    color: {
        if (mouseArea.containsMouse)
            return Config.surface1Color;
        return Qt.alpha(Config.surface1Color, 0.4);
    }
    Behavior on color {
        ColorAnimation {
            duration: Config.animDurationShort
        }
    }

    // Main Click
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15

        // Circle with Icon
        Rectangle {
            implicitWidth: 36
            implicitHeight: 36
            radius: Config.radiusLarge
            color: {
                if (root.active)
                    return Config.accentColor;
                if (root.connecting)
                    return Config.warningColor;
                return Config.surface2Color;
            }

            Item {
                anchors.fill: parent

                // Text (Icon)
                Text {
                    anchors.centerIn: parent
                    visible: !root.connecting
                    text: root.icon
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIcon
                    color: root.active ? Config.textReverseColor : Config.textColor
                }

                // Spinner
                Spinner {
                    anchors.centerIn: parent
                    running: root.connecting
                    color: Config.textReverseColor
                    size: Config.fontSizeIcon
                }
            }
        }

        // Information (Text)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.title
                color: Config.textColor
                font.family: Config.font
                font.bold: true
                font.pixelSize: Config.fontSizeNormal
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 5

                // Subtitle
                Text {
                    visible: root.subtitle !== ""
                    text: root.subtitle
                    color: Config.textColor
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    elide: Text.ElideRight
                }

                // Separator dot (only if there is subtitle AND status)
                Text {
                    visible: root.subtitle !== "" && root.statusText !== ""
                    text: "•"
                    color: Config.textColor
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                }

                // Status (Connected, Paired...)
                Text {
                    text: root.statusText
                    font.family: Config.font
                    color: {
                        if (root.active)
                            return Config.accentColor;
                        if (root.connecting)
                            return Config.warningColor;
                        return Config.subtextColor;
                    }
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: root.active
                }
            }
        }

        // Lock Icon (Wi-Fi only)
        Text {
            visible: root.secured && !root.active && !root.connecting
            text: ""
            font.family: Config.font
            color: Config.subtextColor
            font.pixelSize: Config.fontSizeSmall
        }

        // Menu button ---
        Rectangle {
            id: menuButton
            visible: root.showMenu && !root.connecting
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: menuMouse.containsMouse || menuPopup.opened ? Config.surface2Color : "transparent"

            Text {
                anchors.centerIn: parent
                text: "" // 3 vertical dots icon (mdi-dots-vertical)
                font.family: Config.font
                color: Config.textColor
                font.pixelSize: Config.fontSizeNormal
            }

            MouseArea {
                id: menuMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: menuPopup.open()
            }

            // --- Menu popup ---
            Popup {
                id: menuPopup
                x: -width + 30 // Align to the right of the button
                y: 35 // Opens downward
                width: 140
                height: menuColumn.implicitHeight + 10

                padding: 0

                background: Rectangle {
                    color: Config.surface0Color
                    border.color: Config.surface2Color
                    border.width: 1
                    radius: Config.radius
                }

                ColumnLayout {
                    id: menuColumn
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 2

                    Repeater {
                        model: root.menuModel
                        delegate: Rectangle {
                            id: menuItem

                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: Config.radiusSmall
                            color: itemMouse.containsMouse ? Config.surface1Color : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 10

                                Text {
                                    visible: modelData.icon !== undefined
                                    text: modelData.icon || ""
                                    font.family: Config.font
                                    color: modelData.iconColor ?? Config.textColor
                                }

                                Text {
                                    text: modelData.text
                                    color: modelData.textColor ?? Config.textColor
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeSmall
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    menuPopup.close();
                                    root.menuAction(modelData.action);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
