#!/bin/bash

# 1. Pega o diretório. Se vazio, usa o atual.
ALVO="${1:-.}"
ARQUIVO_SAIDA="$(pwd)/output-packer.txt"

if [ ! -d "$ALVO" ]; then
  echo "Erro: Diretório '$ALVO' não existe."
  exit 1
fi

echo "--- Iniciando ---"
echo "Lendo: $ALVO"
echo "Saída: $ARQUIVO_SAIDA"
>"$ARQUIVO_SAIDA"

find "$ALVO" -type f \
  -not -path '*/.git/*' \
  -not -path '*/node_modules/*' \
  -not -path '*/build/*' \
  -not -name '.*' \
  -not -name 'package-lock.json' \
  -not -name 'output-packer.txt' \
  -not -name "$(basename "$0")" \
  -print0 | while IFS= read -r -d '' file; do

  # Debug: Mostra o que está sendo lido na tela
  echo "Processando: $file"

  # Verificação mais robusta se é arquivo de texto usando comando 'file'
  if file "$file" | grep -q "text"; then
    echo -e "\n\n==================================================" >>"$ARQUIVO_SAIDA"
    echo "ARQUIVO: $file" >>"$ARQUIVO_SAIDA"
    echo "==================================================" >>"$ARQUIVO_SAIDA"
    cat "$file" >>"$ARQUIVO_SAIDA"
  else
    echo " -> Ignorado (Binário): $file"
  fi
done

echo "--- Concluído ---"
