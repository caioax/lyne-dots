# Neovim

The leader is `Space`: `<leader>ff` means Space, then `f`, then `f`. Plugins come from lazy.nvim, language servers and formatters from Mason.

> **Not sure what comes next?** Press Space (or `g`, `]`, `z`) and wait: which-key lists the keys that follow. **Every key, searchable:** `<leader>fk` or `:Shortcuts` (Neovim's and tmux's; `C-Space ?` in tmux). This guide: `C-Space N` in tmux.

## Move around

| Keys | Does |
| :--- | :--- |
| `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | Focus the split on the left / below / above / on the right, then tmux's panes |
| `<M-h>` / `<M-j>` / `<M-k>` / `<M-l>` | Grow or shrink the split |
| `<leader>e` | File tree (open / close) |
| `<C-/>` | Floating terminal (open / close) |

## Find

| Keys | Does |
| :--- | :--- |
| `<leader>ff` | A file by name |
| `<leader>fg` | Text in every file |
| `<leader>fb` | An open buffer |
| `<leader>fk` | A shortcut |
| `<leader>fP` | A project or tmux session (switches tmux to it) |
| `<leader>"` | A register, to paste it |

## Copy and paste

`y` and `p` go through the system clipboard. Register 0 keeps the last thing you copied, safe from what you delete since.

| Keys | Does |
| :--- | :--- |
| `y` / `p` / `P` | Copy / paste after / paste before (system clipboard) |
| `<leader>y` / `<leader>p` | Copy / paste with the safe register (0) |
| `<leader>dp` | Paste what you deleted last (`dd`, `x`) |
| `<leader>yc` | Send a register to the system clipboard |

## Code

With a language server (Mason installs them):

| Keys | Does |
| :--- | :--- |
| `K` | Documentation of what's under the cursor |
| `gd` | Go to the definition |
| `grr` | References |
| `<leader>rn` | Rename everywhere |
| `<leader>ca` | Code actions (fixes, imports) |
| `]d` / `[d` | Next / previous diagnostic |
| `gl` | The line's diagnostics in a float |
| `<leader>mp` | Format (also happens on save) |

The completion menu: `Tab` / `Shift+Tab` move through it, `Enter` picks, `Ctrl+Space` opens it.

## Git

| Keys | Does |
| :--- | :--- |
| `]c` / `[c` | Next / previous change |
| `<leader>gp` | Preview the change |
| `<leader>gb` | Who changed the line (toggle) |
| `<leader>gd` | Diff of the file |
| `<leader>lg` | Lazygit |
| `<leader>gl` | Lazygit's log of the file |

## Sessions and notes

Sessions are saved per folder (and git branch) once a file is open: when you quit, write a file or leave the pane. When tmux brings a pane back, its Neovim reopens with that session.

| Keys | Does |
| :--- | :--- |
| `<leader>qs` | Restore this folder's session |
| `<leader>ql` | Restore the last session |
| `<leader>qd` | Don't save this session |
| `<leader>sf` | Scratch buffer (open / close) |
| `<leader>S` | Pick a scratch buffer |

## Change the config

- **Folders:** `lua/config` (options, keys, the shortcut search), `lua/plugins` (one file per plugin), `lua/lyne` (the colorscheme, which follows the shell's theme).
- **A plugin:** a file in `lua/plugins/` returning its spec; lazy.nvim installs it the next time Neovim starts. `:Lazy` shows updates.
- **A language:** `:Mason` to install the server or formatter, then add it to `ensure_installed` in `lua/plugins/lsp.lua` (servers) or the formatter to `lua/plugins/formatting.lua`.
- **A key:** give it a `desc`; which-key and the search show it.
