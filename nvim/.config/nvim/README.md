# 📖 Manual do Neovim

| Informação      | Valor                    |
| :-------------- | :----------------------- |
| **Tema**        | `Tokyo Night (Night)`    |
| **Fonte**       | Caskaydia Cove Nerd Font |
| **Leader Key**  | `Space` (Espaço)         |
| **Gerenciador** | `Lazy.nvim`              |

---

## 🧭 Navegação Imersiva (Nvim 🤝 Tmux)

Graças ao plugin `vim-tmux-navigator`, a fronteira entre o editor e o terminal não existe mais.

| Atalho       | Contexto    | Ação                                        |
| :----------- | :---------- | :------------------------------------------ |
| `<Ctrl> + h` | ⬅️ Esquerda | Move o foco para o split/painel da esquerda |
| `<Ctrl> + j` | ⬇️ Baixo    | Move o foco para o split/painel de baixo    |
| `<Ctrl> + k` | ⬆️ Cima     | Move o foco para o split/painel de cima     |
| `<Ctrl> + l` | ➡️ Direita  | Move o foco para o split/painel da direita  |

---

## ⌨️ Cheat Sheet de Atalhos

### 📂 Arquivos e Buffers

| Atalho        | Comando                | Descrição                                      |
| :------------ | :--------------------- | :--------------------------------------------- |
| `<Leader> ff` | `Telescope find_files` | Busca arquivos (ignora pastas na visualização) |
| `<Leader> fg` | `Telescope live_grep`  | Busca por palavras dentro de todos os arquivos |
| `<Leader> fb` | `Telescope buffers`    | Lista arquivos abertos na memória              |
| `<Leader> e`  | `NeoTree toggle`       | Abre/Fecha a árvore lateral de arquivos        |
| `:Delete`     | `User Command`         | **Perigo:** Apaga o arquivo atual do disco     |

### 🧠 Inteligência (LSP) & Código

| Atalho          | Descrição                                                   |
| :-------------- | :---------------------------------------------------------- |
| `K`             | **Hover:** Mostra a documentação da função sob o cursor     |
| `gd`            | **Go Definition:** Pula para onde a função foi criada       |
| `<Leader> rn`   | **Rename:** Renomeia a variável no projeto todo (Refactor)  |
| `<Leader> ca`   | **Code Action:** Menu de correções rápidas (Imports, Fixes) |
| `<Leader> mp`   | **Format:** Formata o código manualmente (Prettier/Stylua)  |
| `Tab` / `S-Tab` | Navega nas sugestões do Autocomplete (CMP)                  |

### 🛠️ Utilitários & Terminais

O `Snacks.nvim` fornece ferramentas poderosas embutidas:

| Atalho        | Ferramenta        | O que faz?                                     |
| :------------ | :---------------- | :--------------------------------------------- |
| `<Leader> lg` | **LazyGit**       | Abre uma interface gráfica completa para Git   |
| `<Leader> gl` | **Git Log**       | Mostra o histórico de commits do arquivo atual |
| `<Leader> sf` | **Scratchpad**    | Abre um bloco de notas temporário flutuante    |
| `<Ctrl> + /`  | **Terminal**      | Abre/Fecha um terminal flutuante rápido        |
| `<Leader> un` | **Notifications** | Limpa todas as notificações da tela            |

### 💾 Sessões (Persistence)

O Neovim lembra onde você parou.

| Atalho        | Ação                                        |
| :------------ | :------------------------------------------ |
| `<Leader> qs` | Restaura a sessão da pasta atual            |
| `<Leader> ql` | Restaura a **última** sessão usada (global) |
| `<Leader> qd` | Desativa a gravação de sessão atual         |

---

## 🎨 Personalização Visual

### Temas

O sistema carrega o **Tokyo Night** por padrão. Para mudar, edite `lua/plugins/theme.lua`:

```lua
vim.cmd.colorscheme("tokyonight-night")
-- Opções: catppuccin, gruvbox-material, kanagawa, rose-pine
```

### Git Signs (Barra Lateral)

- `▎` (Azul/Verde): Linha adicionada ou modificada.
- `` (Vermelho): Linha deletada.
- **Preview:** Use `<Leader>gp` para ver o que foi alterado na linha sem abrir o git.

---

## ⚙️ Estrutura de Diretórios

Entenda onde mexer para não quebrar nada:

```text
~/.config/nvim/
├── init.lua             # 🧠 Cérebro: Carrega os módulos
├── lazy-lock.json       # 🔒 Trava versões dos plugins (NÃO MEXA)
├── lua/
│   ├── config/          # ⚙️ Configurações Base
│   │   ├── options.lua  # Tabs, Números, Clipboard
│   │   ├── keymaps.lua  # Seus atalhos manuais
│   │   ├── lazy.lua     # Boot do gerenciador
│   │   └── commands.lua # Comandos customizados (:Delete)
│   └── plugins/         # 🧩 Módulos (Adicione novos aqui)
│       ├── lsp.lua      # Linguagens (JS, Lua, Python...)
│       ├── editor.lua   # Telescope, Neo-tree
│       ├── snacks.lua   # Dashboard, Terminal, Git
│       └── ...
```

## 📦 Como instalar coisas novas?

### Adicionar um Plugin

1. Crie um arquivo em `lua/plugins/nome-do-plugin.lua`.
2. Cole o código `return { "usuario/repo", ... }`.
3. Reinicie o Neovim.

### Adicionar uma Linguagem (LSP/Formatter)

1. Digite `:Mason`.
2. Use `/` para buscar (ex: `python`, `gopls`).
3. Aperte `i` para instalar.
4. **Nota:** Se quiser que fique salvo na config, adicione na lista `ensure_installed` em `lua/plugins/lsp.lua` ou `formatting.lua`.
