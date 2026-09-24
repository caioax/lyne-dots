pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import "../../../components/"

// Modal list of the installed font families, each name drawn in its own
// font, with search and a Nerd Fonts filter
Popup {
    id: root

    property string current

    signal picked(string family)

    readonly property var families: Qt.fontFamilies()
    property string query: ""
    property bool nerdOnly: false

    readonly property var filtered: {
        const q = query.toLowerCase();
        return families.filter(f => (!nerdOnly || /Nerd Font| NF[MP]?$/.test(f)) && (q === "" || f.toLowerCase().includes(q)));
    }

    // Fontconfig matches names loosely ("Caskaydia Cove" == "CaskaydiaCove")
    function _normalize(name: string): string {
        return name.toLowerCase().replace(/\s+/g, "");
    }

    function _isCurrent(family: string): bool {
        return _normalize(family) === _normalize(current);
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - Config.spacing * 8, Config.fontSizeNormal * 34)
    height: Math.min(parent.height - Config.spacing * 8, Config.fontSizeNormal * 40)
    modal: true
    focus: true
    padding: Config.padding * 2

    onOpened: {
        query = "";
        search.text = "";
        search.forceActiveFocus();
        list.positionViewAtIndex(Math.max(0, filtered.findIndex(f => _isCurrent(f))), ListView.Center);
    }

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
        spacing: Config.spacing

        // Search
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Config.fontSizeIconSmall * 2
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
                    font.pixelSize: Config.fontSizeLarge
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

                    Keys.onReturnPressed: {
                        if (root.filtered.length > 0)
                            root.picked(root.filtered[Math.max(0, list.currentIndex)]);
                    }
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onUpPressed: list.decrementCurrentIndex()

                    Text {
                        visible: search.text === ""
                        text: "Search " + root.families.length + " fonts"
                        font: search.font
                        color: Config.subtextColor
                    }
                }
            }
        }

        SegmentedControl {
            options: [
                {
                    label: "All"
                },
                {
                    label: "Nerd Fonts"
                }
            ]
            currentIndex: root.nerdOnly ? 1 : 0
            onSelected: index => root.nerdOnly = index === 1
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Math.round(Config.padding / 3)
            boundsBehavior: Flickable.StopAtBounds
            model: root.filtered
            currentIndex: 0
            highlightMoveDuration: 0

            ScrollBar.vertical: QsScrollBar {}

            delegate: Rectangle {
                id: item

                required property string modelData
                required property int index
                readonly property bool isCurrent: root._isCurrent(modelData)
                readonly property bool highlighted: ListView.isCurrentItem && search.text !== ""

                width: ListView.view.width
                implicitHeight: row.implicitHeight + Config.padding * 3
                radius: Config.radius
                color: isCurrent ? Qt.alpha(Config.accentColor, 0.15) : itemMouse.containsMouse || highlighted ? Config.surface1Color : "transparent"

                RowLayout {
                    id: row

                    anchors.fill: parent
                    anchors.leftMargin: Config.padding * 2
                    anchors.rightMargin: Config.padding * 2
                    spacing: Config.spacing

                    // The name in its own font; a small label in the UI font
                    // keeps it readable for symbol fonts
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: item.modelData
                            elide: Text.ElideRight
                            font.family: item.modelData
                            font.pixelSize: Config.fontSizeLarge
                            color: item.isCurrent ? Config.accentColor : Config.textColor
                        }

                        Text {
                            Layout.fillWidth: true
                            text: item.modelData
                            elide: Text.ElideRight
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.subtextColor
                        }
                    }

                    // md-check
                    Text {
                        visible: item.isCurrent
                        text: "\u{f012c}"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconSmall
                        color: Config.accentColor
                    }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(item.modelData)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.filtered.length === 0
                text: "No fonts match"
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: Config.subtextColor
            }
        }
    }
}
