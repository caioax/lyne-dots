# tmux

The prefix is `C-Space`: press Ctrl + Space, let go, then press the key (`C-Space |` means prefix, then `|`). The mouse clicks, scrolls and resizes; windows and panes count from 1.

> **Every key, searchable:** `C-Space ?` (tmux's and Neovim's). This guide: `C-Space T`; the Neovim one: `C-Space N`.

## Move around

| Keys | Does |
| :--- | :--- |
| `C-h` / `C-j` / `C-k` / `C-l` | Focus the pane on the left / below / above / on the right (inside Neovim, its splits first) |
| `C-M-h` / `C-M-l` | Previous / next window |
| `C-Space z` | Zoom the pane (again to bring the others back) |
| `C-Space P` | Projects and sessions: switch, or start a session in a project folder (`~/Dev`, lyne-dots) |
| `C-Space w` | Pick a window from a list |

## Split and arrange

| Keys | Does |
| :--- | :--- |
| `C-Space \|` | Split side by side (same folder) |
| `C-Space -` | Split top and bottom (same folder) |
| `M-h` / `M-j` / `M-k` / `M-l` | Grow or shrink the pane (inside Neovim, its splits first) |
| `C-S-h` / `C-S-j` / `C-S-k` / `C-S-l` | Swap places with the pane on that side |
| `C-Space x` | Close the pane |

## Floating

| Keys | Does |
| :--- | :--- |
| `C-Space S` | Scratch terminal: shows it, and from inside hides it again (it keeps running) |
| `C-Space G` | Lazygit in the pane's folder |
| `C-Space *` | New floating pane (the mouse moves and resizes it) |
| `C-Space @` | Float the pane, or put a floating one back in the layout |

## Windows (the tabs on top)

| Keys | Does |
| :--- | :--- |
| `C-Space c` | New window in the same folder |
| `C-Space 1` | Go to window 1 (any number) |
| `C-Space ,` | Rename the window (empty: back to the automatic name) |

## Copy text

| Keys | Does |
| :--- | :--- |
| `C-Space [` | Enter copy mode (scroll with the mouse or the Vim keys) |
| `v` | Start a selection |
| `y` | Copy the selection and leave |
| `Escape` | Leave without copying |

## Sessions

tmux keeps running after you close the terminal. Everything is saved every 15 minutes and when you log out, reboot or shut down from the shell's power menu; the first tmux after that brings it back, Neovim panes with their folder's session. From the shell, `tk` closes everything (it comes back next time) and `tkf` closes it and forgets the save.

| Keys | Does |
| :--- | :--- |
| `C-Space d` | Detach: leave tmux running in the background (`tmux a` comes back) |
| `C-Space C-s` / `C-Space C-r` | Save now / restore the last save (tmux-resurrect) |
| `C-Space X` | Close every session and forget the save: the next tmux starts empty (asks first) |

## Help and config

| Keys | Does |
| :--- | :--- |
| `C-Space ?` | Search every shortcut (tmux and Neovim) |
| `C-Space T` / `C-Space N` | This guide / the Neovim guide |
| `C-Space r` | Reload `~/.tmux.conf` |
| `C-Space I` / `C-Space U` | Install / update the plugins (TPM) |

A plugin: add `set -g @plugin 'user/plugin'` to `~/.tmux.conf`, then `C-Space I`. Project folders other than `~/Dev`: `LYNE_PROJECT_ROOTS` (colon separated) in your environment. A key of your own: give it a note (`bind -N "What it does" ...`) and the search lists it.
