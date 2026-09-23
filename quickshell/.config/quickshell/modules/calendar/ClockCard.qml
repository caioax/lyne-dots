pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

Card {
    id: root

    readonly property date now: TimeService.date

    // ISO 8601 week number
    readonly property int week: {
        const d = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()));
        const dow = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - dow);
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
    }
    readonly property int dayOfYear: Math.round((new Date(now.getFullYear(), now.getMonth(), now.getDate()) - new Date(now.getFullYear(), 0, 1)) / 86400000) + 1
    readonly property int daysInYear: new Date(now.getFullYear(), 1, 29).getMonth() === 1 ? 366 : 365

    RowLayout {
        spacing: Config.padding / 2

        Text {
            text: TimeService.format("hh:mm")
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconLarge * 2
            font.bold: true
            color: Config.textColor
        }

        Text {
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: Config.padding + Config.padding / 2
            text: TimeService.format("ss")
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            font.bold: true
            color: Config.accentColor
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: -Config.padding
        text: TimeService.format("dddd, d MMMM")
        font.family: Config.font
        font.pixelSize: Config.fontSizeNormal
        font.capitalization: Font.Capitalize
        color: Config.subtextColor
        elide: Text.ElideRight
    }

    RowLayout {
        spacing: Config.padding

        StatChip {
            icon: "󰸗"
            text: "Week " + root.week
            accent: Config.accentColor
        }

        StatChip {
            icon: "󰃭"
            text: "Day " + root.dayOfYear + "/" + root.daysInYear
        }
    }
}
