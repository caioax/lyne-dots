# Tests

```sh
tests/run.sh            # everything
tests/run.sh js lint    # some sections
```

| Section | What | Needs |
|---|---|---|
| `js` | The shell's JavaScript libraries (`quickshell/.config/quickshell/services/*.js`) in node, and its translations | `nodejs` (and `lua` for one monitors test) |
| `bash` | lyne CLI, migrations and installer, with bats | `bats bats-assert bats-support` |
| `lint` | shellcheck over every script (settings in `.shellcheckrc`) | `shellcheck` |
| `qml` | qmllint over the shell; only warnings missing from `tests/qml/lint-baseline.txt` fail | `qt6-declarative` |
| `smoke` | The whole shell in a nested Hyprland: every window and page opened, no QML errors | a running Hyprland session |
| `nvim` | Neovim with the repo's config inside tmux with the repo's tmux.conf: Ctrl/Alt + h/j/k/l between splits and panes, smart-splits' health check; the config with the LSP on, nothing deprecated | `tmux`, `neovim`, `git`, the plugins lazy.nvim and Mason installed |

A missing tool fails its section with the package to install; nothing is skipped silently.

GitHub Actions (`.github/workflows/tests.yml`) runs `js bash lint` on every push and pull request, in an Arch Linux container as a regular user. `qml` and `smoke` need Quickshell and a Hyprland session, so they run only here, like `nvim` (the plugins live in your Neovim data folder).

## JavaScript tests

`tests/js/<lib>.test.js` uses node's built-in runner (`node:test`, no packages). `load.js` loads a `.pragma library` file and returns its top-level functions, so the libraries need no changes to be tested:

```js
const { load, fixture } = require("./load");
const M = load("services/monitors.js");
const monitors = JSON.parse(fixture("monitors.json"));
```

One file: `node --test tests/js/fuzzy.test.js`. One test: add `--test-name-pattern "ranking"`.

Fixtures in `tests/js/fixtures/` are trimmed copies of real output (`hyprctl -j`, `evdev.lst`); keep serial numbers and other personal details out of them.

`LYNE_TEST_SHELL=<dir>` runs the tests against another copy of the shell config, handy to check that a test fails when the code is broken on purpose.

`i18n.test.js` covers the translations ([i18n/README.md](../quickshell/.config/quickshell/i18n/README.md)): `services/i18n.js` (plural rules, language resolution, the pseudo-language), `tools/i18n.js` on small throwaway shells, and the real files: every `I18n` call with literal arguments, `pt_BR.json` complete and in step with the code (`node tools/i18n.js extract` after changing strings), placeholders matching, no piece of a sentence as a key, and no UI string left outside `I18n` (`node tools/i18n.js lint --list` shows them; `// i18n-ignore` marks a line that isn't for people).

## Bash tests

`tests/bash/<name>.bats` uses [bats](https://bats-core.readthedocs.io) with bats-assert. Start each file with `load helpers` and call `lyne_setup` from `setup()`. Then every test has:

- a throwaway `$HOME` (`$DOTS_DIR` inside it) and no `XDG_*` variables, so nothing reaches your real files;
- no `WAYLAND_DISPLAY`, `DISPLAY` or Hyprland signature, and stand-ins (`tests/bash/stubs`) first in `PATH`: `hyprctl` and `pgrep` answer that nothing runs, so no test ever reaches your session; `pacman`, `systemctl`, `udevadm`, `mkinitcpio`, `yay`, `stow`, `gsettings`, `modprobe`... log every call to `$STUB_LOG`, and pacman works on a fake package list (`pkgs nvidia-utils linux-headers=6.17-1` adds packages to it);
- a `sudo` that only runs the stand-ins and file commands on paths inside the test's temp dir: anything else (a write to `/etc`, a real tool) is logged as `sudo-refused` and skipped;
- `in_lyne LIB... -- 'code'`, which runs code the way the lyne CLI does: `state.sh` and `log.sh` sourced, then each `.data/lyne-cli/lib/<LIB>.sh` sourced inside a function;
- `fx_gpu`, which builds a fake sysfs for the GPU libraries (`LYNE_SYSFS`), with `fixtures/pci.ids` standing in for hwdata's.

- `fake_dots`, for code that reads `$DOTS_DIR`: the repo seen through links, with its own `state.json` (from `defaults.json`, linked from `~/.config/quickshell`). Call `repo_unchanged` in `teardown`: it fails the test when anything was written into the repo through those links. `snapshot` lists every file of the fake HOME with a hash, to compare before and after (the migrations' second run must change nothing).

`migrations.bats` runs every migration twice on a fresh install and the whole chain on an old one; `installer.bats` runs `install.sh --dry-run --answers` (the installer's own stand-ins) on a fake sysfs. A new migration is covered by the first automatically; give it a line in `legacy_home` when it converts something old.

The libraries read their system paths from `LYNE_*` variables (listed at the top of each one), and the tests point those at files in `$BATS_TEST_TMPDIR`.

One file: `bats tests/bash/nvidia.bats`. One test: `bats -f "Kepler" tests/bash/nvidia.bats`. `LYNE_TEST_LIB=<dir>` runs them against another copy of the libraries.

## QML

`tests/qml/lint.sh` runs Qt 6's qmllint (`/usr/lib/qt6/bin/qmllint`; `/usr/bin/qmllint` is Qt 5's) with `qs.config`/`qs.services` mapped. qmllint doesn't know Quickshell well, so today's warnings sit in `lint-baseline.txt` without line numbers and only new ones fail. After fixing some, or when a new warning is really Quickshell's noise, `tests/qml/lint.sh --update` rewrites the baseline (review the diff).

`tests/qml/smoke.sh` starts a nested Hyprland through yours, in a hidden special workspace and without focus (nothing shows, nothing moves), and runs the real `shell.qml` in it with a throwaway HOME, runtime dir and session bus. It opens every Settings page, dashboard tab, Quick Settings page and launcher mode, the notifications, power menu, wallpaper picker, OSD, welcome and what's new windows, locks and unlocks, switches themes, all in pt_BR, then searches Settings in both languages and switches the language live (en, pt_BR, en), and fails on any warning or error the shell logs. `tests/qml/allowed.txt` lists the lines the sandbox itself causes (no PipeWire, no portal); a QML error never goes there. A new window or page is opened automatically when it's in `SettingsService.pages`, `DashboardService.allTabs`, `QuickSettingsService.pages` or `LauncherService.modes`; anything else gets a `step` line in `run_steps`.

Commands with effects outside the sandbox (nmcli, rfkill, brightness, systemctl, systemd-inhibit, pkill, kitty, nvim, zenity...) are stand-ins logging to `$SB/calls.log`, the Bluetooth agent is a stand-in (the real one registers on the system bus), and battery rules, update checks and idle are off in its state. It also fails when your `state.json` or the repo changed. `SMOKE_KEEP=1` keeps the sandbox (path printed) with `qs.log`, `hyprland.log` and `calls.log`; `SMOKE_WAIT` sets the pause after each step (0.6 s).

## Neovim and tmux

`tests/nvim/nav.sh` starts a tmux server of its own (its own socket, the repo's `tmux.conf` without TPM, so no plugin runs and continuum never saves over your session) with a shell pane and Neovim with the repo's config, split in two, then types the keys through a client attached in a pty (`send-keys -K` goes through tmux's key tables like typing does). It checks Ctrl + h/j/k/l between Neovim's windows and tmux's panes, copy mode, Alt + l resizing, and `:checkhealth smart-splits` (no errors, the tmux backend in use). It opens no file, so nothing that installs (Mason, Treesitter parsers) starts.

`tests/nvim/config.sh` opens a Lua file with a diagnostic and a git change (in a throwaway repo) in headless Neovim, waits for lua_ls and gitsigns, and uses the keys that call into Neovim and the plugins (yank, `]d`/`[d`, `]c`/`[c`, format, typing a bracket). Then `:checkhealth vim.deprecated` must be clean (it only lists what was called), no message may mention something deprecated, a list of old names (the plugins' deprecations that don't warn) must be gone from the config, servers must get nvim-cmp's capabilities, stylua must not run as a server, and `grr` must be the references key.

Both use the sandbox in `tests/nvim/lib.sh`: Neovim's state and cache in a temp folder, its data folder a link to yours (the plugins and Mason's servers already installed). `LYNE_TEST_NVIM=<dir>` and `LYNE_TEST_TMUX_CONF=<file>` run them against copies (to break them on purpose); `NAV_DEBUG=1` / `CONFIG_DEBUG=1` print the health report.
