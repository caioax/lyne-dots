pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell

// Minute precision: the only seconds shown (the dashboard's ClockCard) come
// from a SystemClock of their own
Singleton {
    readonly property date date: clock.date
    readonly property int hours: clock.hours
    readonly property int minutes: clock.minutes
    // Midnight of the current day; changes once a day (a string only notifies
    // when its value changes)
    readonly property string _day: Qt.formatDate(clock.date, "yyyy-MM-dd")
    readonly property date today: new Date(_day + "T00:00:00")

    function format(fmt: string): string {
        return Qt.formatDateTime(clock.date, fmt);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
