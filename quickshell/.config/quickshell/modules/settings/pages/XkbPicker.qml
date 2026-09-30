pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import "../../../components/"

// Searchable list for the Keyboard page: layouts and variants, keyboard
// models, or xkb options (several at once, in groups).
// `items`: [{ key, label, detail, header? }]; headers group the rows after
// them and are kept while one of those rows matches the search
Popup {
    id: root

    property string title
    property string placeholder: "Search"
    property var items: []
    // Keys marked as chosen
    property var selected: []
    // Several keys can be on (options): rows toggle instead of closing
    property bool multi: false
    property string query: ""

    signal picked(var item)
    signal toggled(var item, bool on)

    function _matches(item, words) {
        const hay = (item.label + " " + item.detail + " " + item.key).toLowerCase();
        return words.every(w => hay.includes(w));
    }

    readonly property var shown: {
        const words = query.toLowerCase().split(/\s+/).filter(w => w !== "");
        if (words.length === 0)
            return items;
        const out = [];
        let header = null;
        for (const item of items) {
            if (item.header) {
                header = item;
                continue;
            }
            if (!_matches(item, words))
                continue;
            if (header) {
                out.push(header);
                header = null;
            }
            out.push(item);
        }
        return out;
    }

    function openWith(initialQuery: string) {
        search.text = initialQuery ?? "";
        query = search.text;
        open();
        search.forceActiveFocus();
        // Show the current choice
        const i = shown.findIndex(it => !it.header && selected.includes(it.key));
        list.positionViewAtIndex(Math.max(0, i), ListView.Center);
    }

    function choose(item) {
        if (item.header)
            return;
        if (multi) {
            toggled(item, !selected.includes(item.key));
            return;
        }
        picked(item);
        close();
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - Config.spacing * 8, Config.fontSizeNormal * 38)
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
                        const first = root.shown.find(it => !it.header);
                        if (first)
                            root.choose(first);
                    }

                    Text {
                        visible: search.text === ""
                        text: root.placeholder
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
            readonly property real headerHeight: Config.fontSizeSmall * 2 + Config.padding

            Layout.fillWidth: true
            Layout.preferredHeight: rowHeight * 7
            clip: true
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            model: root.shown

            ScrollBar.vertical: QsScrollBar {}

            delegate: Item {
                id: row

                required property var modelData
                readonly property bool isHeader: modelData.header === true
                readonly property bool current: !isHeader && root.selected.includes(modelData.key)
                readonly property color hoverTint: Config.surface2Color

                width: list.width
                height: isHeader ? list.headerHeight : list.rowHeight

                Text {
                    visible: row.isHeader
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Config.padding * 2
                    anchors.bottomMargin: Config.padding / 2
                    text: row.modelData.label.toUpperCase()
                    elide: Text.ElideRight
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: Config.accentColor
                }

                Rectangle {
                    visible: !row.isHeader
                    anchors.fill: parent
                    radius: Config.radius
                    color: row.current ? Qt.alpha(Config.accentColor, 0.15) : rowMouse.containsMouse ? row.hoverTint : Qt.alpha(row.hoverTint, 0)

                    Behavior on color {
                        enabled: !Config.themeTransitioning
                        ColorAnimation {
                            duration: Config.animDurationShort
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Config.padding * 2
                        anchors.rightMargin: Config.padding * 2
                        spacing: Config.spacing + Config.padding

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.label
                                elide: Text.ElideRight
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeNormal
                                color: Config.textColor
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: row.modelData.detail ?? ""
                                elide: Text.ElideRight
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                color: Config.subtextColor
                            }
                        }

                        // md-check
                        Text {
                            visible: row.current
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
                        onClicked: root.choose(row.modelData)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "Nothing matches \"" + root.query + "\""
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.spacing

            Item {
                Layout.fillWidth: true
            }

            ActionButton {
                text: root.multi ? "Done" : "Cancel"
                onClicked: root.close()
            }
        }
    }
}
