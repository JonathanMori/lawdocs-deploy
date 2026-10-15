#!/usr/bin/env bash
# Monitoramento (cron a cada 5 min). Avisa no Telegram só quando o estado MUDA
# (caiu / voltou), para não repetir alerta a cada execução.
#   - site e API no ar      - sessão do e-SAJ (login ativo no e-SAJ; checada a cada 15 min)
#   - disco e memória
set -uo pipefail
cd /opt/lawdocs
ESTADO=backups/.monitor
mkdir -p "$ESTADO"

checar() {  # checar <nome> <ok:0|1> <mensagem de falha> <mensagem de volta>
  local f="$ESTADO/$1.falha"
  if [ "$2" -eq 0 ]; then
    [ -f "$f" ] && { rm -f "$f"; scripts/avisar.sh "✅ $4"; }
  else
    [ -f "$f" ] || { touch "$f"; scripts/avisar.sh "🚨 $3"; }
  fi
}

curl -fsS -m 20 -o /dev/null https://sistema.gruposobrinhoadv.com.br/; site=$?
checar site $site "Site fora do ar (https://sistema.gruposobrinhoadv.com.br)" "Site voltou ao ar"

docker compose exec -T proxy wget -qO- -T 15 http://api:8080/actuator/health </dev/null 2>/dev/null | grep -q '"UP"'; api=$?
checar api $api "API fora do ar (login e telas não funcionam). Ver: docker compose logs api" "API voltou ao ar"

uso=$(df --output=pcent / | tail -1 | tr -dc 0-9)
[ "$uso" -lt 85 ]; checar disco $? "Disco da VPS em ${uso}%" "Disco normalizado (${uso}%)"

mem=$(free | awk '/Mem:/ {printf "%d", ($3/$2)*100}')
[ "$mem" -lt 92 ]; checar memoria $? "Memória da VPS em ${mem}%" "Memória normalizada (${mem}%)"

# Sessão do e-SAJ: a cada 15 min. Pergunta ao robô, que confere no próprio e-SAJ se o
# login está ativo (o cookie CASTGC continua no navegador mesmo com a sessão expirada).
if [ $((10#$(date +%M) % 15)) -lt 5 ] || [ "${1:-}" = "--agora" ]; then
  docker compose exec -T robos curl -fsS -m 30 http://localhost:8100/sessao </dev/null 2>/dev/null | grep -q '"logado": true'
  checar esaj $? "Sessão do e-SAJ caiu: os robôs não conseguem ler a Pasta Digital. Faça login em https://sistema.gruposobrinhoadv.com.br/esaj" "Sessão do e-SAJ ativa de novo"
fi
exit 0
