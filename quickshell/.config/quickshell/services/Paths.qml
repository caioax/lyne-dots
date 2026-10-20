pragma Singleton

import Quickshell

// Where the lyne-dots repo is: LYNE_DOTS (uwsm/env sets it from where the
// dotfiles really are), else ~/.lyne-dots. The scripts find it from their
// own path instead
Singleton {
    readonly property string dots: Quickshell.env("LYNE_DOTS") || Quickshell.env("HOME") + "/.lyne-dots"
}
