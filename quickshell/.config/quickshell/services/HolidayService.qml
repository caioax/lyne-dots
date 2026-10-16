pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Brazilian national holidays, computed locally (no network).
// Movable dates are derived from Easter (Carnaval, Good Friday, Corpus Christi).
// dashboard.holidays: "auto" (Brazil's when the time zone is Brazilian or
// the shell is in Portuguese) | "none"
Singleton {
    id: root

    readonly property string setting: StateService.get("dashboard.holidays", "auto")
    readonly property bool enabled: setting === "auto" && (_brazilianZone || I18n.language.split("_")[0] === "pt")

    property bool _brazilianZone: false

    // year -> { "M-D": { name, optional } }; names in English (I18n.noop),
    // shown with I18n.translate
    property var _cache: ({})

    // optional = "ponto facultativo" / observance, not a mandatory day off
    function holidays(year) {
        if (_cache[year])
            return _cache[year];

        const result = {};
        const add = (date, name, optional) => result[(date.getMonth() + 1) + "-" + date.getDate()] = {
                name,
                optional
            };
        const fixed = (month, day, name) => add(new Date(year, month - 1, day), name, false);

        fixed(1, 1, I18n.noop("New Year's Day"));
        fixed(4, 21, I18n.noop("Tiradentes"));
        fixed(5, 1, I18n.noop("Labour Day"));
        fixed(9, 7, I18n.noop("Independence Day"));
        fixed(10, 12, I18n.noop("Our Lady of Aparecida"));
        fixed(11, 2, I18n.noop("All Souls' Day"));
        fixed(11, 15, I18n.noop("Republic Day"));
        if (year >= 2024)
            fixed(11, 20, I18n.noop("Black Consciousness Day"));
        fixed(12, 25, I18n.noop("Christmas"));

        const easter = _easter(year);
        const fromEaster = offset => new Date(year, easter.getMonth(), easter.getDate() + offset);

        add(fromEaster(-48), I18n.noop("Carnival"), true);
        add(fromEaster(-47), I18n.noop("Carnival"), true);
        add(fromEaster(-46), I18n.noop("Ash Wednesday"), true);
        add(fromEaster(-2), I18n.noop("Good Friday"), false);
        add(fromEaster(0), I18n.noop("Easter"), true);
        add(fromEaster(60), I18n.noop("Corpus Christi"), true);

        _cache[year] = result;
        return result;
    }

    // Holiday on a given date, or null. month is 1-based.
    function holiday(year, month, day) {
        if (!enabled)
            return null;
        return holidays(year)[month + "-" + day] ?? null;
    }

    // First mandatory holiday strictly after `from`: { date, name, days }
    function nextHoliday(from) {
        if (!enabled)
            return null;
        const start = new Date(from.getFullYear(), from.getMonth(), from.getDate());
        for (let i = 1; i <= 366; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            const h = holiday(d.getFullYear(), d.getMonth() + 1, d.getDate());
            if (h && !h.optional)
                return {
                    date: d,
                    name: h.name,
                    days: i
                };
        }
        return null;
    }

    // Anonymous Gregorian algorithm (Meeus/Jones/Butcher)
    function _easter(year) {
        const a = year % 19;
        const b = Math.floor(year / 100);
        const c = year % 100;
        const d = Math.floor(b / 4);
        const e = b % 4;
        const f = Math.floor((b + 8) / 25);
        const g = Math.floor((b - f + 1) / 3);
        const h = (19 * a + b - d - g + 15) % 30;
        const i = Math.floor(c / 4);
        const k = c % 4;
        const l = (32 + 2 * e + 2 * i - h - k) % 7;
        const m = Math.floor((a + 11 * h + 22 * l) / 451);
        const month = Math.floor((h + l - 7 * m + 114) / 31);
        const day = ((h + l - 7 * m + 114) % 31) + 1;
        return new Date(year, month - 1, day);
    }

    Process {
        running: true
        command: ["timedatectl", "show", "-p", "Timezone", "--value"]
        stdout: StdioCollector {
            onStreamFinished: root._brazilianZone = /^(America\/(Noronha|Belem|Fortaleza|Recife|Araguaina|Maceio|Bahia|Sao_Paulo|Campo_Grande|Cuiaba|Santarem|Porto_Velho|Boa_Vista|Manaus|Eirunepe|Rio_Branco)|Brazil\/.+)$/.test(text.trim())
        }
    }
}
