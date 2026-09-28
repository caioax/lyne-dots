pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import "../../../components/"

// Picks an installed app (.desktop entry), optionally narrowed to a category
// (the default apps of Settings › System › Apps), or a custom command
Popup {
    id: root

    property string title: "Pick an app"
    // .desktop category listed first ("" = every app)
    property string category: ""
    property string categoryLabel: "apps"
    // Entry id marked as the current choice
    property string currentId: ""
    property bool allowCustom: false
    property string customPlaceholder: ""

    property bool showAll: category === ""
    property string query: ""

    signal picked(var entry)
    signal customPicked(string command)

    readonly property var apps: {
        const all = DesktopEntries.applications.values;
        const base = showAll ? all : all.filter(e => e.categories.includes(category));
        const q = query.trim().toLowerCase();
        const seen = new Set();
        return base.filter(e => {
            if (seen.has(e.id))
                return false;
            seen.add(e.id);
            return q === "" || e.name.toLowerCase().includes(q) || e.id.toLowerCase().includes(q) || (e.genericName ?? "").toLowerCase().includes(q);
        }).sort((a, b) => a.name.localeCompare(b.name));
    }

    function openWith(command: string) {
        query = "";
        showAll = category === "";
        search.text = "";
        customField.text = command;
        open();
        search.forceActiveFocus();
    }

    function pick(entry) {
        picked(entry);
        close();
    }

    function useCustom() {
        const command = customField.text.trim();
        if (command === "")
            return;
        customPicked(command);
        close();
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - Config.spacing * 8, Config.fontSizeNormal * 34)
    modal: true
    // Escape is handled by the page
    closePolicy: Popup.CloseOnPressOutside
    padding: Config.padding * 3

    Overlay.modal: Rectangle {
        color: Qt.alpha(Config.backgroundColor, 0.6)
    }

    background: Rectangle {
        radius: Config.radiusLarge
        color: Config.surface0Color
        border.width: 1
        border.color: Config.surface1Color
    }

    contentItem: ColumnLayout {
        spacing: Config.spacing + Config.padding

        Text {
            text: root.title
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            font.bold: true
            color: Config.textColor
        }

        // ================= SEARCH =================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Config.fontSizeIconSmall + Config.padding * 3
            radius: Config.radius
            color: Config.surface1Color
            border.width: search.activeFocus ? 1 : 0
            border.color: Qt.alpha(Config.accentColor, 0.6)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Config.padding * 2
                anchors.rightMargin: Config.padding * 2
                spacing: Config.spacing

                // md-magnify
                Text {
                    text: "\u{f0349}"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.subtextColor
                }

                TextInput {
                    id: search

                    Layout.fillWidth: true
                    clip: true
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.textColor
                    selectionColor: Qt.alpha(Config.accentColor, 0.4)
                    onTextChanged: root.query = text
                    // Enter takes the first result
                    onAccepted: {
                        if (root.apps.length > 0)
                            root.pick(root.apps[0]);
                    }

                    Text {
                        visible: search.text === ""
                        text: "Search " + (root.showAll ? "apps" : root.categoryLabel)
                        font: search.font
                        color: Config.subtextColor
                    }
                }
            }
        }

        // ================= LIST =================
        ListView {
            id: list

            readonly property real rowHeight: Config.fontSizeIconSmall * 2 + Config.padding * 2

            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(1, Math.min(count, 6)) * rowHeight
            clip: true
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            model: root.apps

            ScrollBar.vertical: QsScrollBar {}

            delegate: Rectangle {
                id: appRow

                required property var modelData
                readonly property bool current: modelData.id === root.currentId
                readonly property color hoverTint: Config.surface2Color

                width: list.width
                height: list.rowHeight
                radius: Config.radius
                color: current ? Qt.alpha(Config.accentColor, 0.15) : rowMouse.containsMouse ? hoverTint : Qt.alpha(hoverTint, 0)

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animDurationShort
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Config.padding * 2
                    anchors.rightMargin: Config.padding * 2
                    spacing: Config.spacing + Config.padding

                    Image {
                        Layout.preferredWidth: Config.fontSizeIconSmall * 1.5
                        Layout.preferredHeight: Config.fontSizeIconSmall * 1.5
                        sourceSize.width: width
                        sourceSize.height: height
                        source: "image://icon/" + (appRow.modelData.icon || "application-x-executable")
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: appRow.modelData.name
                            elide: Text.ElideRight
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            color: Config.textColor
                        }

                        Text {
                            Layout.fillWidth: true
                            text: AppsService.commandOf(appRow.modelData) + (appRow.modelData.runInTerminal ? "  ·  in the terminal" : "")
                            elide: Text.ElideRight
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.subtextColor
                        }
                    }

                    // md-check
                    Text {
                        visible: appRow.current
                        text: "\u{f012c}"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconSmall
                        color: Config.accentColor
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pick(appRow.modelData)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: root.query !== "" ? "No apps match \"" + root.query + "\"" : "No " + root.categoryLabel + " installed"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
            }
        }

        // Category apps only / every app
        Text {
            visible: root.category !== ""
            text: root.showAll ? "Show only " + root.categoryLabel : "Show all apps"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.underline: toggleMouse.containsMouse
            color: Config.accentColor

            MouseArea {
                id: toggleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showAll = !root.showAll
            }
        }

        // ================= CUSTOM =================
        ColumnLayout {
            visible: root.allowCustom
            Layout.fillWidth: true
            spacing: Config.padding

            Text {
                text: "Custom command"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.subtextColor
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Config.spacing

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Config.fontSizeIconSmall + Config.padding * 3
                    radius: Config.radius
                    color: Config.surface1Color
                    border.width: customField.activeFocus ? 1 : 0
                    border.color: Qt.alpha(Config.accentColor, 0.6)

                    TextInput {
                        id: customField

                        anchors.fill: parent
                        anchors.leftMargin: Config.padding * 2
                        anchors.rightMargin: Config.padding * 2
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        color: Config.textColor
                        selectionColor: Qt.alpha(Config.accentColor, 0.4)
                        selectByMouse: true
                        onAccepted: root.useCustom()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            elide: Text.ElideRight
                            visible: customField.text === ""
                            text: root.customPlaceholder
                            font: customField.font
                            color: Config.subtextColor
                        }
                    }
                }

                ActionButton {
                    size: Config.fontSizeIconSmall + Config.padding * 3
                    icon: "\u{f012c}"
                    text: "Use"
                    opacity: customField.text.trim() !== "" ? 1 : 0.4
                    baseColor: Config.accentColor
                    hoverColor: Qt.lighter(Config.accentColor, 1.1)
                    textColor: Config.textReverseColor
                    onClicked: root.useCustom()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing

            Item {
                Layout.fillWidth: true
            }

            ActionButton {
                text: "Cancel"
                onClicked: root.close()
            }
        }
    }
}
