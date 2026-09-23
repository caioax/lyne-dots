pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Brazilian national holidays, computed locally (no network).
// Movable dates are derived from Easter (Carnaval, Good Friday, Corpus Christi).
Singleton {
    id: root

    // year -> { "M-D": { name, optional } }
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

        fixed(1, 1, "Confraternização Universal");
        fixed(4, 21, "Tiradentes");
        fixed(5, 1, "Dia do Trabalho");
        fixed(9, 7, "Independência do Brasil");
        fixed(10, 12, "Nossa Senhora Aparecida");
        fixed(11, 2, "Finados");
        fixed(11, 15, "Proclamação da República");
        if (year >= 2024)
            fixed(11, 20, "Dia da Consciência Negra");
        fixed(12, 25, "Natal");

        const easter = _easter(year);
        const fromEaster = offset => new Date(year, easter.getMonth(), easter.getDate() + offset);

        add(fromEaster(-48), "Carnaval", true);
        add(fromEaster(-47), "Carnaval", true);
        add(fromEaster(-46), "Quarta-feira de Cinzas", true);
        add(fromEaster(-2), "Sexta-feira Santa", false);
        add(fromEaster(0), "Páscoa", true);
        add(fromEaster(60), "Corpus Christi", true);

        _cache[year] = result;
        return result;
    }

    // Holiday on a given date, or null. month is 1-based.
    function holiday(year, month, day) {
        return holidays(year)[month + "-" + day] ?? null;
    }

    // First mandatory holiday strictly after `from`: { date, name, days }
    function nextHoliday(from) {
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
}
