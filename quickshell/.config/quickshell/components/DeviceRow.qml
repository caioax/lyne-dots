pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config

// Compact device/network line for lists inside a Card: icon box, title,
// subtitle, optional lock and a ⋮ menu ({ text, icon, action, color })
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool connecting: false
    property bool secured: false
    property var menuModel: []

    signal clicked
    signal menuAction(string action)

    readonly property int boxSize: Config.fontSizeIconSmall * 2
    readonly property color stateColor: connecting ? Config.warningColor : Config.accentColor

    Layout.fillWidth: true
    implicitHeight: boxSize + Config.padding * 2

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Config.padding
        anchors.rightMargin: -Config.padding
        radius: Config.radiusLarge
        color: Config.surface1Color
        opacity: mouseArea.containsMouse || menuButton.hovered || menu.opened ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        spacing: Config.spacing + Config.padding

        Rectangle {
            implicitWidth: root.boxSize
            implicitHeight: root.boxSize
            radius: Config.radiusLarge
            color: root.active || root.connecting ? root.stateColor : Config.surface1Color

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !root.connecting
                text: root.icon
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconSmall
                color: root.active ? Config.textReverseColor : Config.textColor
            }

            Spinner {
                anchors.centerIn: parent
                running: root.connecting
                size: Config.fontSizeIconSmall
                color: Config.textReverseColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.title
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                font.bold: root.active
                color: Config.textColor
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.subtitle
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: root.active || root.connecting ? root.stateColor : Config.subtextColor
                elide: Text.ElideRight
            }
        }

        Text {
            visible: root.secured
            text: "󰌾"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
        }

        // ⋮ menu
        ActionButton {
            id: menuButton
            visible: root.menuModel.length > 0 && !root.connecting
            size: root.boxSize
            icon: ""
            baseColor: "transparent"
            hoverColor: Config.surface2Color
            textColor: Config.subtextColor
            hoverTextColor: Config.textColor
            onClicked: menu.opened ? menu.close() : menu.open()

            Popup {
                id: menu

                x: parent.width - width
                y: parent.height + Config.padding
                width: Math.max(menuColumn.implicitWidth, root.boxSize * 4) + Config.padding * 2
                padding: Config.padding

                background: Rectangle {
                    color: Config.cardColor
                    border.width: 1
                    border.color: Config.surface2Color
                    radius: Config.radius
                }

                contentItem: ColumnLayout {
                    id: menuColumn
                    spacing: Math.round(Config.padding / 3)

                    Repeater {
                        model: root.menuModel

                        Rectangle {
                            id: menuItem

                            required property var modelData
                            readonly property color itemColor: modelData.color ?? Config.textColor

                            Layout.fillWidth: true
                            implicitWidth: itemRow.implicitWidth + Config.spacing * 2
                            implicitHeight: Config.fontSizeSmall + Config.padding * 3
                            radius: Config.radiusSmall
                            color: itemMouse.containsMouse ? Config.surface1Color : "transparent"

                            RowLayout {
                                id: itemRow
                                anchors.fill: parent
                                anchors.leftMargin: Config.spacing
                                anchors.rightMargin: Config.spacing
                                spacing: Config.spacing

                                Text {
                                    text: menuItem.modelData.icon ?? ""
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeNormal
                                    color: menuItem.itemColor
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: menuItem.modelData.text
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeSmall
                                    color: menuItem.itemColor
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    menu.close();
                                    root.menuAction(menuItem.modelData.action);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
