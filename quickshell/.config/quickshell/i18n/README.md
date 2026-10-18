# Translating lyne-dots

The shell (bar, Settings, Quick Settings, launcher, notifications, lock
screen…) is written in English, and every string it shows goes through
`I18n` (`services/I18n.qml`). The English text is the key; each language is
one JSON file here:

```
i18n/
├── languages.json     the list Settings shows (generated: don't edit)
└── pt_BR.json         one file per language
```

The language is picked in Settings › Profile & Region › Language (or on the
first page of the Welcome screen). "Automatic" follows `LANGUAGE`,
`LC_ALL`, `LC_MESSAGES` or `LANG`. Dates and numbers follow the language.

## Add a language

You need `node` (the tools are plain Node.js, no packages).

```sh
cd ~/.lyne-dots
node tools/i18n.js add de "Deutsch"   # code like de or pt_BR, and its own name
```

That creates `i18n/de.json` with every string and an empty translation:

```json
{
    "_meta": { "name": "Deutsch" },
    "Open Settings": "",
    "%n update": ["", ""],
    "_context": { "key hint": { "close": "" } }
}
```

Fill in the `""` values. Untranslated ones show in English, so a partial
file already works (Settings shows how much of it is done). Then:

```sh
node tools/i18n.js extract   # refresh languages.json (names, translated share)
node tools/i18n.js check     # placeholders, plural forms, files up to date
node tools/i18n.js stats     # translated share per language
```

To see it, pick the language in Settings, or force it for one run:

```sh
LYNE_I18N=de qs -p ~/.config/quickshell/shell.qml
```

The shell reloads the file when it changes, so edits show up live.

## Rules

- **Placeholders** `%1`…`%9` are values filled in by the shell (a name, a
  number). Keep every one of them; the order can change
  (`"%2 de %1"`). `check` fails when one is missing or extra.
- **Plurals**: a value that is a list (`"%n update": ["…", "…"]`) has one
  form per plural category of your language, `%n` being the count. English
  and Portuguese have two (1, the rest); Russian, Polish and Czech three;
  Japanese, Korean and Chinese one. The rules live in `services/i18n.js`
  (`PLURALS`): add your language there if it isn't listed.
- **Contexts** (`_context`) hold the same English word with another
  meaning: a short `"open"` key hint, `"Open"` for a Wi-Fi network without a
  password, date formats.
- **Date formats** (`_context` › `date format`) are Qt formats: `dddd` day
  name, `d` day, `MMMM` month name, `MMM` short month, `yyyy` year, text in
  single quotes (`"dddd, d 'de' MMMM"`).
- **Rich text**: keep `<b>`, `<br>` and the like as they are.
- **Proper names stay**: Hyprland, Quickshell, Zen Browser, NVIDIA, Wi-Fi,
  Bluetooth, key names (Super, Ctrl, Caps Lock, Print).
- Pick the words that come back everywhere (Settings, workspace, launcher,
  theme, wallpaper…) once and keep them the same in every string.

## The pseudo-language

`LYNE_I18N=pseudo` shows every string accented, about 40% longer and in
brackets (`[Šéţţîñĝš ~~~]`): English left in the UI, labels that get cut,
and sentences glued from pieces stand out at once.

## For code in the shell

```qml
text: I18n.tr("Open Settings")
text: I18n.tr("Use for %1", themeName)                // never "Use for " + name
text: I18n.trn("%n update", "%n updates", count)      // plurals
text: I18n.trc("key hint", "open")                    // same word, other meaning
label: I18n.noop("Theme")    // kept as data, shown later with I18n.translate(label)
```

- Arguments must be string literals (the extractor reads them from the
  source): `I18n.tr("a" + b)` or `I18n.tr(variable)` fail `check`.
- Whole sentences, not pieces: a key starting or ending with a space fails.
- After adding or changing strings: `node tools/i18n.js extract`, then
  translate the new `""` in `pt_BR.json` (the tests want pt_BR complete).
- Text that isn't for people (ids, commands, file contents, brand names)
  gets `// i18n-ignore` on its line; `node tools/i18n.js lint --list` shows
  any UI string left outside `I18n`, and the tests fail on it.
- Strings the shell shows from Hyprland's Lua (keybind groups and
  descriptions in `hypr/conf/keybinds.lua`, the system list in
  `hypr/conf/autostart.lua`) stay English there; the extractor reads them
  and the shell translates them.
