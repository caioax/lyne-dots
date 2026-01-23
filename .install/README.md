# Installation Scripts

Scripts de instalação organizados para as dotfiles.

## Estrutura

```
.install/
├── packages/           # Listas de pacotes por categoria
│   ├── core.sh         # Hyprland, UWSM, portal
│   ├── terminal.sh     # Kitty, Zsh, Tmux
│   ├── editor.sh       # Neovim + ferramentas dev
│   ├── apps.sh         # Dolphin, Zen Browser, Spotify
│   ├── utils.sh        # Clipboard, audio, bluetooth
│   ├── fonts.sh        # Nerd Fonts, cursores, ícones
│   ├── quickshell.sh   # QuickShell bar
│   ├── theming.sh      # Qt/GTK theming
│   └── nvidia.sh       # Drivers NVIDIA (opcional)
└── setup/              # Scripts de configuração
    ├── stow.sh         # Cria symlinks com GNU Stow
    └── hyprland.sh     # Configura arquivos locais do Hyprland
```

## Uso

### Instalação completa (interativa)

```bash
./install.sh
```

### Apenas criar symlinks

```bash
./install.sh --stow-only
```

### Apenas configurar Hyprland

```bash
./install.sh --setup-only
```

### Instalar categoria específica

```bash
./install.sh --packages core
./install.sh --packages terminal
```

## Categorias de Pacotes

| Categoria   | Descrição                                    |
|-------------|----------------------------------------------|
| core        | Hyprland, UWSM, swww, portal (ESSENCIAL)     |
| terminal    | Kitty, Zsh, Tmux, Fastfetch                  |
| editor      | Neovim + ferramentas de desenvolvimento      |
| apps        | Dolphin, Zen Browser, Spotify, Rofi          |
| utils       | Clipboard, audio, bluetooth, brightnessctl   |
| fonts       | Nerd Fonts, Bibata cursor, Tela icons        |
| quickshell  | QuickShell bar/shell + Qt6                   |
| theming     | Qt5ct, Qt6ct, Kvantum, nwg-look              |
| nvidia      | Drivers NVIDIA (instalar apenas se necessário)|

## Templates

Os templates de configuração estão em `.data/hyprland/templates/`:

- `monitors.conf` - Configuração genérica de monitor
- `workspaces.conf` - Mapeamento de workspaces
- `extra_environment.conf` - Variáveis de ambiente locais
- `extra_environment_nvidia.conf` - Variáveis para NVIDIA
- `autostart.conf` - Autostart local
- `extra_keybinds.conf` - Keybinds locais

Os templates NVIDIA do UWSM estão em `.data/hyprland/uwsm/`:

- `global_hardware.sh` - Variáveis globais Wayland
- `hyprland_hardware.sh` - Configurações específicas Hyprland

## Diretórios de Stow

O script `stow.sh` cria symlinks para:

| Diretório   | Destino                        |
|-------------|--------------------------------|
| hyprland    | ~/.config/hypr                 |
| quickshell  | ~/.config/quickshell           |
| kitty       | ~/.config/kitty                |
| nvim        | ~/.config/nvim                 |
| zsh         | ~/.zshrc, ~/.p10k.zsh          |
| tmux        | ~/.tmux.conf                   |
| local       | ~/.local/scripts               |
| fastfetch   | ~/.config/fastfetch            |
| kde         | ~/.config/kdeglobals           |
