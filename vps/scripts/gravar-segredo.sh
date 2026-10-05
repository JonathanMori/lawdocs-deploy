#!/usr/bin/env bash
# Grava um segredo colado pelo usuário sem mostrá-lo na tela.
#   ssh -t lawdocs-vps /opt/lawdocs/scripts/gravar-segredo.sh gdrive|telegram
set -euo pipefail
umask 077
case "${1:-}" in
  gdrive)   destino=/opt/lawdocs/config/.gdrive-token.json; rotulo="Token do Google (código que o rclone mostrou)" ;;
  telegram) destino=/opt/lawdocs/config/telegram.env;       rotulo="Token do bot do Telegram" ;;
  *) echo "uso: $0 gdrive|telegram"; exit 1 ;;
esac
read -rsp "$rotulo: " valor; echo
[ -n "$valor" ] || { echo "Nada foi colado. Tente de novo."; exit 1; }
if [ "$1" = gdrive ]; then
  # Aceita o JSON do token ou o código base64 que o rclone novo imprime.
  token=$(printf "%s" "$valor" | python3 -c '
import base64, json, sys
v = sys.stdin.read().strip()
def achar(d):
    if isinstance(d, dict):
        if d.get("refresh_token"): return d
        for x in d.values():
            r = achar(x if not isinstance(x, str) else carregar(x))
            if r: return r
    return None
def carregar(t):
    try: return json.loads(t)
    except Exception: pass
    try: return json.loads(base64.urlsafe_b64decode(t + "=" * (-len(t) % 4)))
    except Exception: return None
d = achar(carregar(v))
if not d: sys.exit(1)
print(json.dumps(d))
') || { echo "Não reconheci o token do Google (nem JSON nem base64 do rclone). Nada foi gravado."; exit 1; }
  printf "%s
" "$token" > "$destino"
else
  [[ "$valor" =~ ^[0-9]+:[A-Za-z0-9_-]{30,}$ ]] || { echo "Isso não parece um token de bot (123456:ABC...). Nada foi gravado."; exit 1; }
  printf "TELEGRAM_TOKEN=%s\n" "$valor" > "$destino"
fi
echo "Gravado com sucesso em $destino"
