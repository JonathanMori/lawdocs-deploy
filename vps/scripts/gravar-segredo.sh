#!/usr/bin/env bash
# Grava um segredo colado pelo usuário sem mostrá-lo na tela.
#   ssh -t lawdocs-vps /opt/lawdocs/scripts/gravar-segredo.sh gdrive|telegram
set -euo pipefail
umask 077
case "${1:-}" in
  gdrive)   destino=/opt/lawdocs/config/.gdrive-token.json; rotulo="Token do Google (linha {\"access_token\"...})" ;;
  telegram) destino=/opt/lawdocs/config/telegram.env;       rotulo="Token do bot do Telegram" ;;
  *) echo "uso: $0 gdrive|telegram"; exit 1 ;;
esac
read -rsp "$rotulo: " valor; echo
[ -n "$valor" ] || { echo "Nada foi colado. Tente de novo."; exit 1; }
if [ "$1" = gdrive ]; then
  printf "%s\n" "$valor" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get(\"refresh_token\")" 2>/dev/null \
    || { echo "Isso não parece o token do Google (JSON com refresh_token). Nada foi gravado."; exit 1; }
  printf "%s\n" "$valor" > "$destino"
else
  [[ "$valor" =~ ^[0-9]+:[A-Za-z0-9_-]{30,}$ ]] || { echo "Isso não parece um token de bot (123456:ABC...). Nada foi gravado."; exit 1; }
  printf "TELEGRAM_TOKEN=%s\n" "$valor" > "$destino"
fi
echo "Gravado com sucesso em $destino"
