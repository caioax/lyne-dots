pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.services
import "../../components/"

Card {
    id: root

    readonly property date today: TimeService.date
    property int displayMonth: today.getMonth()
    property int displayYear: today.getFullYear()
    property date selectedDate: today

    readonly property bool showingCurrentMonth: displayMonth === today.getMonth() && displayYear === today.getFullYear()
    readonly property int cellSize: Config.fontSizeSmall * 2 + Config.padding

    readonly property var selectedHoliday: HolidayService.holiday(selectedDate.getFullYear(), selectedDate.getMonth() + 1, selectedDate.getDate())
    readonly property var nextHoliday: HolidayService.nextHoliday(today)

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function showMonth(year, month) {
        const direction = (year * 12 + month) - (displayYear * 12 + displayMonth);
        if (direction === 0)
            return;
        displayYear = year;
        displayMonth = month;
        slideIn.from = direction > 0 ? cellSize : -cellSize;
        slideAnim.restart();
    }

    function shiftMonth(delta) {
        const d = new Date(displayYear, displayMonth + delta, 1);
        showMonth(d.getFullYear(), d.getMonth());
    }

    function resetToToday() {
        showMonth(today.getFullYear(), today.getMonth());
        selectedDate = today;
    }

    // ==================== HEADER ====================
    RowLayout {
        Layout.fillWidth: true
        spacing: Config.padding / 2

        Text {
            Layout.fillWidth: true
            text: new Date(root.displayYear, root.displayMonth, 1).toLocaleDateString(Qt.locale(), "MMMM yyyy")
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            font.bold: true
            font.capitalization: Font.Capitalize
            color: Config.textColor
        }

        ActionButton {
            visible: !root.showingCurrentMonth
            icon: "󰃶"
            text: "Today"
            size: Config.fontSizeSmall * 2
            iconSize: Config.fontSizeSmall
            textColor: Config.accentColor
            onClicked: root.resetToToday()
        }

        NavButton {
            icon: "󰅁"
            onClicked: root.shiftMonth(-1)
        }

        NavButton {
            icon: "󰅂"
            onClicked: root.shiftMonth(1)
        }
    }

    // ==================== GRID ====================
    GridLayout {
        id: gridLayout
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Config.padding / 2
        rowSpacing: Config.padding / 2

        Item {
            implicitWidth: weekColumn.implicitWidth
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: grid.locale

            delegate: Text {
                required property var model
                horizontalAlignment: Text.AlignHCenter
                text: model.narrowName
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: (model.day === 0 || model.day === 6) ? Config.mutedColor : Config.subtextColor
            }
        }

        // Both the week column and the grid are pinned to 6 rows of cellSize
        // so their rows line up
        WeekNumberColumn {
            id: weekColumn
            Layout.preferredHeight: root.cellSize * 6
            month: root.displayMonth
            year: root.displayYear
            locale: grid.locale
            spacing: 0

            delegate: Text {
                required property var model
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: model.weekNumber
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.mutedColor
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.cellSize * 6
            clip: true

            // Scroll to change month; accumulate so touchpads don't skip months
            WheelHandler {
                property real accumulated: 0
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    accumulated += event.angleDelta.y;
                    if (Math.abs(accumulated) >= 120) {
                        root.shiftMonth(accumulated > 0 ? -1 : 1);
                        accumulated = 0;
                    }
                }
            }

            MonthGrid {
                id: grid
                width: parent.width
                height: parent.height
                month: root.displayMonth
                year: root.displayYear
                locale: Qt.locale()
                spacing: 0

                ParallelAnimation {
                    id: slideAnim

                    NumberAnimation {
                        id: slideIn
                        target: grid
                        property: "x"
                        to: 0
                        duration: Config.animDurationLong
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: grid
                        property: "opacity"
                        from: 0.2
                        to: 1
                        duration: Config.animDuration
                    }
                }

                delegate: Item {
                    id: cell
                    required property var model

                    readonly property date date: new Date(model.year, model.month, model.day)
                    readonly property bool inMonth: model.month === grid.month
                    readonly property bool isToday: model.today
                    readonly property bool isSelected: root.sameDay(date, root.selectedDate)
                    readonly property bool isWeekend: date.getDay() === 0 || date.getDay() === 6
                    readonly property var holiday: HolidayService.holiday(model.year, model.month + 1, model.day)

                    implicitWidth: root.cellSize
                    implicitHeight: root.cellSize

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.cellSize
                        height: width
                        radius: width / 2
                        color: {
                            if (cell.isToday)
                                return Config.accentColor;
                            if (cellMouse.containsMouse)
                                return Config.surface1Color;
                            return Qt.alpha(Config.surface1Color, 0);
                        }
                        border.width: cell.isSelected && !cell.isToday ? 1.5 : 0
                        border.color: Config.accentColor

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDurationShort
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.model.day
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: cell.isToday || cell.holiday !== null
                        opacity: cell.inMonth ? 1 : 0.3
                        color: {
                            if (cell.isToday)
                                return Config.textReverseColor;
                            if (cell.holiday && !cell.holiday.optional)
                                return Config.errorColor;
                            if (cell.isWeekend)
                                return Config.subtextColor;
                            return Config.textColor;
                        }
                    }

                    // Holiday marker
                    Rectangle {
                        visible: cell.holiday !== null && cell.inMonth
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        width: Config.padding - 2
                        height: width
                        radius: width / 2
                        color: {
                            if (cell.isToday)
                                return Config.textReverseColor;
                            return cell.holiday?.optional ? Config.warningColor : Config.errorColor;
                        }
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedDate = cell.date;
                            if (!cell.inMonth)
                                root.showMonth(cell.model.year, cell.model.month);
                        }
                    }
                }
            }
        }
    }

    // Keeps the grid at the top and the details at the bottom when the card
    // stretches to match the left column
    Item {
        Layout.fillHeight: true
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Config.surface1Color
    }

    // ==================== DAY DETAILS ====================
    RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing

        Rectangle {
            Layout.preferredWidth: Config.fontSizeNormal * 2 + Config.padding
            Layout.preferredHeight: Layout.preferredWidth
            radius: Config.radius
            color: root.selectedHoliday ? Qt.alpha(root.selectedHoliday.optional ? Config.warningColor : Config.errorColor, 0.15) : Qt.alpha(Config.accentColor, 0.15)

            Text {
                anchors.centerIn: parent
                text: root.selectedDate.getDate()
                font.family: Config.font
                font.pixelSize: Config.fontSizeLarge
                font.bold: true
                color: root.selectedHoliday ? (root.selectedHoliday.optional ? Config.warningColor : Config.errorColor) : Config.accentColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            // The day, and on the right whether it's a holiday or when the
            // next one is
            RowLayout {
                Layout.fillWidth: true
                spacing: Config.padding

                Text {
                    Layout.fillWidth: true
                    text: root.sameDay(root.selectedDate, root.today) ? "Today" : root.selectedDate.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    font.bold: true
                    font.capitalization: Font.Capitalize
                    color: Config.textColor
                    elide: Text.ElideRight
                }

                Text {
                    visible: text !== ""
                    text: {
                        const h = root.selectedHoliday;
                        if (h)
                            return h.optional ? "optional" : "holiday";
                        const n = root.nextHoliday;
                        return n ? "holiday in " + n.days + (n.days === 1 ? " day" : " days") : "";
                    }
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: root.selectedHoliday ? (root.selectedHoliday.optional ? Config.warningColor : Config.errorColor) : Config.accentColor
                }
            }

            // That holiday's name
            Text {
                Layout.fillWidth: true
                text: root.selectedHoliday?.name ?? root.nextHoliday?.name ?? "No holidays"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: root.selectedHoliday ? (root.selectedHoliday.optional ? Config.warningColor : Config.errorColor) : Config.subtextColor
                elide: Text.ElideRight
            }
        }
    }

    component NavButton: Rectangle {
        id: navButton

        required property string icon
        signal clicked

        implicitWidth: Config.fontSizeSmall * 2
        implicitHeight: implicitWidth
        radius: height / 2
        color: navMouse.containsMouse ? Config.surface1Color : Qt.alpha(Config.surface1Color, 0)

        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }

        Text {
            anchors.centerIn: parent
            text: navButton.icon
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: Config.subtextColor
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: navButton.clicked()
        }
    }
}
