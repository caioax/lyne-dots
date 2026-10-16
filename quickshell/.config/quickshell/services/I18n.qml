pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "i18n.js" as Lib

// Shell translations: English is the source and the key of every string,
// i18n/<code>.json holds the translations of each language and
// i18n/languages.json their names (node tools/i18n.js extract keeps both in
// sync with the code). Bindings that call tr() follow a language switch by
// themselves: they read `strings`.
//
//   I18n.tr("Open %1", name)              %1..%9
//   I18n.trn("%n update", "%n updates", n) %n = the count, the form follows
//                                          the language's plural rule
//   I18n.trc("power menu", "Lock")        same English, other meaning
//   I18n.noop("Theme")                    marks a string kept as data (the
//                                          page registry...), shown later
//                                          with I18n.translate(value)
//                                          (translateIn(ctx, value) for a
//                                          trc one)
//
// Arguments to tr/trn/trc/noop must be string literals (the extractor
// reads them from the source). LYNE_I18N=pseudo shows the pseudo-language
// (accented, ~40% longer, bracketed), LYNE_I18N=<code> forces a language.
Singleton {
    id: root

    readonly property string dir: Qt.resolvedUrl("../i18n/").toString().replace("file://", "")

    readonly property string override: Quickshell.env("LYNE_I18N") ?? ""
    readonly property bool pseudo: override === "pseudo"
    // general.language: "auto" (the system's) or a code from `languages`
    readonly property string setting: StateService.get("general.language", "auto")
    readonly property var systemWanted: ["LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"].map(v => Quickshell.env(v) ?? "")

    // Translations shipped: [{ code, name, translated (%) }], English first
    readonly property var languages: [
        {
            code: "en",
            name: "English"
        }
    ].concat(_index)
    // Read while loading (blockLoading), so the first frame is already in
    // the right language
    readonly property var _index: _parse(indexFile.text(), "languages.json") ?? []
    readonly property var codes: languages.map(l => l.code)

    // The language the shell shows: "en", "pt_BR"...
    readonly property string language: {
        if (pseudo)
            return "en";
        if (override !== "")
            return Lib.resolve(override, codes);
        return Lib.resolve(setting === "auto" ? systemWanted : setting, codes);
    }
    readonly property string systemLanguage: Lib.resolve(systemWanted, codes)
    readonly property string languageName: languages.find(l => l.code === language)?.name ?? "English"
    readonly property string systemLanguageName: languages.find(l => l.code === systemLanguage)?.name ?? "English"

    // Dates and numbers: the whole system locale on "auto", the shell
    // language's otherwise
    readonly property var locale: setting === "auto" && override === "" ? Qt.locale() : Qt.locale(language === "en" ? "en_US" : language)

    // The current language's file: { "English": "translation", "_context": {...} }
    readonly property var strings: languageFile.path !== "" ? _parse(languageFile.text(), language + ".json") ?? {} : {}

    // Options of a language picker (LanguageRow): Automatic with the
    // language the system gives, then each translation by its own name, the
    // partial ones with their translated share (from languages.json)
    readonly property var languageOptions: [
        {
            label: root.tr("Automatic"),
            detail: systemLanguageName,
            value: "auto"
        }
    ].concat(languages.map(l => ({
                label: l.name,
                detail: (l.translated ?? 100) < 100 ? root.tr("%1% translated", l.translated) : "",
                value: l.code
            })))

    function _show(template: string, args: var): string {
        return Lib.format(pseudo ? Lib.pseudo(template) : template, args);
    }

    function tr(text: string, ...args): string {
        const t = Lib.lookup(strings, text, "");
        return _show(typeof t === "string" ? t : text, args);
    }

    function trc(context: string, text: string, ...args): string {
        const t = Lib.lookup(strings, text, context);
        return _show(typeof t === "string" ? t : text, args);
    }

    function trn(singular: string, plural: string, n: real, ...args): string {
        const forms = Lib.lookup(strings, singular, "");
        const form = Array.isArray(forms) ? forms[Lib.pluralIndex(language, n)] : "";
        const template = form ? form : (n === 1 ? singular : plural);
        return _show(template, args).replace(/%n/g, number(n, Number.isInteger(n) ? 0 : 1));
    }

    function noop(text: string): string {
        return text;
    }

    // A string kept as data (marked with noop where it's written)
    function translate(text: string, ...args): string {
        const t = Lib.lookup(strings, text, "");
        return _show(typeof t === "string" ? t : text, args);
    }

    function translateIn(context: string, text: string, ...args): string {
        const t = Lib.lookup(strings, text, context);
        return _show(typeof t === "string" ? t : text, args);
    }

    function number(n: real, decimals: int): string {
        return Number(n).toLocaleString(locale, "f", decimals ?? 0);
    }

    function _parse(text: string, what: string): var {
        if (text === "")
            return null;
        try {
            return JSON.parse(text);
        } catch (e) {
            console.warn("[I18n] " + what + ":", e);
            return null;
        }
    }

    FileView {
        id: indexFile

        path: root.dir + "languages.json"
        blockLoading: true
        watchChanges: true

        onFileChanged: reload()
    }

    FileView {
        id: languageFile

        path: root.language !== "en" ? root.dir + root.language + ".json" : ""
        blockLoading: true
        watchChanges: true

        printErrors: false

        onFileChanged: reload()
    }
}
