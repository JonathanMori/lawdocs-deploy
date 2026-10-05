#!/usr/bin/env bash
# Envia uma mensagem no Telegram (config/telegram.env: TELEGRAM_TOKEN e TELEGRAM_CHAT_ID).
# Sem Telegram configurado, só registra no log.   uso: avisar.sh "mensagem"
set -uo pipefail
ENV=/opt/lawdocs/config/telegram.env
msg="[LawDocs] $*"
echo "$(date '+%F %T') $msg" >> /opt/lawdocs/backups/avisos.log
[ -f "$ENV" ] || exit 0
# shellcheck disable=SC1090
. "$ENV"
[ -n "${TELEGRAM_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ] || exit 0
curl -fsS -m 20 "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" --data-urlencode "text=${msg}" >/dev/null
