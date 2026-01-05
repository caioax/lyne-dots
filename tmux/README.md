# 🖥️ Manual do Tmux

> **Filosofia:** Um multiplexador de terminais moderno, focado em fluxo contínuo com o Neovim, persistência de sessões e estética limpa (_Transparent/TokyoNight_).

| Informação           | Valor                                |
| :------------------- | :----------------------------------- |
| **Prefixo (Leader)** | `Ctrl` + `Space` (Espaço)            |
| **Mouse**            | Ativado (Scroll e Redimensionamento) |
| **Gerenciador**      | TPM (Tmux Plugin Manager)            |
| **Persistência**     | Automática (Continuum)               |

---

## ⌨️ Atalhos Essenciais (Cheat Sheet)

> **Nota:** Todos os comandos abaixo (exceto navegação inteligente) exigem que você aperte o **Prefixo** (`Ctrl+Space`) antes.

### 🪟 Gestão de Janelas e Painéis (Splits)

|    Atalho (Pós-Prefixo)    | Ação                 | Detalhe                                            |
| :------------------------: | :------------------- | :------------------------------------------------- |
|            `\|`            | **Split Vertical**   | Divide a tela lado a lado (mantém a pasta atual)   |
|          `Enter`           | **Split Horizontal** | Divide a tela em cima/baixo (mantém a pasta atual) |
|            `c`             | **Create Window**    | Cria uma nova aba/janela limpa                     |
|            `x`             | **Close**            | Fecha o painel atual                               |
|         `1` a `9`          | **Go to Window**     | Pula direto para a janela pelo número              |
| `Ctrl` + `Shift` + `⬅️/➡️` | **Move Window**      | Troca a ordem das janelas (sem prefixo)            |

### 🧭 Navegação Inteligente (Sem Prefixo)

A integração com o Neovim permite navegar entre painéis como se fosse um único programa.

| Atalho       | Direção     | Comportamento                                |
| :----------- | :---------- | :------------------------------------------- |
| `<Ctrl> + h` | ⬅️ Esquerda | Vai para o painel da esquerda (ou vim split) |
| `<Ctrl> + j` | ⬇️ Baixo    | Vai para o painel de baixo (ou vim split)    |
| `<Ctrl> + k` | ⬆️ Cima     | Vai para o painel de cima (ou vim split)     |
| `<Ctrl> + l` | ➡️ Direita  | Vai para o painel da direita (ou vim split)  |

---

## 🚀 Funcionalidades Especiais

### 🆘 Popups de Ajuda

Não precisa sair do terminal para consultar seus manuais.

| Atalho (Pós-Prefixo) | Ação                                                           |
| :------------------: | :------------------------------------------------------------- |
|         `N`          | Abre o **README do Neovim** em modo leitura (popup flutuante)  |
|         `T`          | Abre este **README do Tmux** em modo leitura (popup flutuante) |

### 📋 Modo de Cópia (Estilo Vim)

Para rolar o terminal para cima ou copiar texto sem usar o mouse:

1. Aperte `Prefixo` + `[` para entrar no modo cópia.
2. Navegue com `h`, `j`, `k`, `l`.
3. Aperte `v` para começar a selecionar.
4. Aperte `y` para copiar (sai do modo automaticamente).
5. Cole onde quiser com `Ctrl+v` (ou `Prefixo + ]`).

---

## 💾 Sessões e Persistência

O sistema usa **Resurrect + Continuum** para que você nunca perca seu trabalho, mesmo se reiniciar o PC.

### Fluxo Automático

1. O Tmux **salva** o estado automaticamente a cada **5 minutos**.
2. Ao iniciar o computador e abrir o terminal, o Tmux **restaura** a última sessão sozinho.

### Comandos Manuais (Se precisar)

| Atalho (Pós-Prefixo) | Ação                                                           |
| :------------------: | :------------------------------------------------------------- |
|     `Ctrl` + `s`     | **Save:** Força o salvamento da sessão agora                   |
|     `Ctrl` + `r`     | **Restore:** Força a restauração do último save                |
|         `s`          | **Session Menu:** Abre uma árvore visual para trocar de sessão |
|         `d`          | **Detach:** Sai da sessão sem fechar (deixa rodando no fundo)  |

---

## 🛠️ Manutenção e Plugins

### Gerenciamento (TPM)

Os plugins ficam listados no final do arquivo `~/.tmux.conf`.

| Atalho (Pós-Prefixo) | Ação                                                            |
| :------------------: | :-------------------------------------------------------------- |
|    `I` (Shift+i)     | **Install:** Baixa e instala novos plugins adicionados          |
|    `U` (Shift+u)     | **Update:** Atualiza os plugins existentes                      |
|         `r`          | **Reload:** Recarrega o arquivo de configuração (sem reiniciar) |

### Estrutura Visual (Status Bar)

- **Esquerda:**
  - `❐` (Branco): Modo Normal.
  - `⌨` (Amarelo): Prefixo Pressionado (Aguardando comando).
  - Nome da Sessão atual.
- **Direita:**
  - Pasta atual (caminho inteligente, ex: `~/projetos/api`).

---

## ⚙️ Como adicionar novos plugins?

1. Edite o arquivo de configuração:

   ```bash
   nvim ~/.tmux.conf
   ```

2. Adicione a linha na seção de plugins:

   ```tmux
   set -g @plugin 'usuario/nome-do-plugin'
   ```

3. Salve e feche o arquivo.
4. Dentro do Tmux, pressione `Prefixo` + `I` para instalar.
