# Tests

```sh
tests/run.sh            # everything
tests/run.sh js lint    # some sections
```

| Section | What | Needs |
|---|---|---|
| `js` | The shell's JavaScript libraries (`quickshell/.config/quickshell/services/*.js`) in node | `nodejs` (and `lua` for one monitors test) |
| `bash` | lyne CLI, migrations and installer, with bats | `bats bats-assert bats-support` |
| `lint` | shellcheck over every script (settings in `.shellcheckrc`) | `shellcheck` |

A missing tool fails its section with the package to install; nothing is skipped silently.

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
