pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import "../../components/"

// What's new: the notes of the releases an update brought (WhatsNewService),
// newest first, one card each, in the welcome screen's look. A regular window
// floated by a Hyprland rule, like the welcome screen
FloatingWindow {
    id: root

    readonly property int maxContentWidth: Config.fontSizeNormal * 44
    readonly property int buttonSize: Config.fontSizeIconSmall * 2
    // The size it opens at: the window rule in hypr/conf/rules.lua only
    // floats and centers it
    readonly property size defaultSize: Qt.size(680, 560)

    readonly property var releases: WhatsNewService.releases

    // Stays English: Hyprland window rules match the title
    title: "What's new" // i18n-ignore
    implicitWidth: defaultSize.width
    implicitHeight: defaultSize.height
    minimumSize: Qt.size(480, 360)
    color: Config.backgroundTransparentColor
    visible: true

    onVisibleChanged: {
        if (!visible)
            WhatsNewService.close();
    }

    Shortcut {
        sequence: "Escape"
        onActivated: WhatsNewService.close()
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
            contentHeight: Math.max(height, content.implicitHeight + Config.padding * 4)
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: QsScrollBar {}

            ColumnLayout {
                id: content

                x: Math.round((flick.width - width) / 2)
                y: Config.padding * 2
                width: Math.min(flick.width - Config.padding * 4, root.maxContentWidth)
                spacing: Config.spacing * 2

                // md-party_popper
                WelcomeHeader {
                    icon: "\u{f1056}"
                    title: I18n.tr("What's new")
                    description: {
                        if (WhatsNewService.loading)
                            return I18n.tr("Reading the release notes…");
                        if (root.releases.length === 0)
                            return I18n.tr("This release has no notes");
                        if (root.releases.length === 1)
                            return I18n.tr("In lyne-dots %1", root.releases[0].version);
                        return I18n.trn("%n release, %1 to %2", "%n releases, %1 to %2", root.releases.length, root.releases[root.releases.length - 1].version, root.releases[0].version);
                    }
                }

                Repeater {
                    model: root.releases

                    Card {
                        id: card

                        required property var modelData
                        property string html: ""

                        Layout.fillWidth: true
                        spacing: Config.spacing

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Config.spacing

                            // md-tag
                            Text {
                                text: "\u{f04f9}  " + card.modelData.version
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeLarge
                                font.bold: true
                                color: Config.accentColor
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: card.modelData.date
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                color: Config.subtextColor
                            }
                        }

                        // Markdown to HTML through a hidden TextEdit (switching it
                        // to rich text serializes the document): linkColor doesn't
                        // reach the links of Text.MarkdownText, and here they take
                        // the accent. The body's font (Sans Serif 9pt) goes, so the
                        // Text's applies
                        TextEdit {
                            visible: false
                            textFormat: TextEdit.MarkdownText
                            text: card.modelData.notes
                            Component.onCompleted: {
                                textFormat = TextEdit.RichText;
                                card.html = text.replace(/<body[^>]*>/, "<body>");
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            // Links come out as <a><span style="… color:#…">
                            text: card.html.replace(/(<a [^>]*><span style="[^"]*color:)#[0-9a-fA-F]{6}/g, "$1" + Config.accentColor)
                            textFormat: Text.RichText
                            wrapMode: Text.WordWrap
                            lineHeight: 1.15
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            color: Config.textColor
                            onLinkActivated: link => Qt.openUrlExternally(link)

                            HoverHandler {
                                cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                        }
                    }
                }
            }
        }

        // ================= FOOTER =================
        Item {
            Layout.fillWidth: true
            implicitHeight: root.buttonSize

            // md-github
            ActionButton {
                anchors.left: parent.left
                size: root.buttonSize
                icon: "\u{f02a4}"
                text: I18n.tr("All releases")
                baseColor: Qt.alpha(Config.surface2Color, 0)
                textColor: Config.subtextColor
                hoverTextColor: Config.textColor
                onClicked: Qt.openUrlExternally(WhatsNewService.releasesUrl)
            }

            // md-check
            ActionButton {
                anchors.right: parent.right
                size: root.buttonSize
                icon: "\u{f012c}"
                text: I18n.tr("Done")
                baseColor: Config.accentColor
                hoverColor: Qt.lighter(Config.accentColor, 1.1)
                textColor: Config.textReverseColor
                onClicked: WhatsNewService.close()
            }
        }
    }
}
