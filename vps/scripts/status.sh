#!/usr/bin/env bash
# Resumo do estado do LawDocs na VPS.   ssh lawdocs-vps /opt/lawdocs/scripts/status.sh
cd /opt/lawdocs
ok() { [ "$1" -eq 0 ] && echo "OK" || echo "FALHA"; }

curl -fsS -m 20 -o /dev/null https://sistema.gruposobrinhoadv.com.br/; echo "Site ............ $(ok $?)"
docker compose exec -T proxy wget -qO- -T 15 http://api:8080/actuator/health </dev/null 2>/dev/null | grep -q '"UP"'; echo "API ............. $(ok $?)"
docker compose exec -T proxy wget -qO- -T 15 http://robos:8100/health </dev/null 2>/dev/null | grep -q '"ok": true'; echo "Robô e-SAJ ...... $(ok $?)"
docker compose exec -T robos python - 2>/dev/null <<'EOF'
from patchright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.connect_over_cdp("http://127.0.0.1:9223")
    logado = any(c["name"] == "CASTGC" for c in b.contexts[0].cookies())
print("Sessão e-SAJ .... " + ("LOGADA" if logado else "DESLOGADA -> entre em https://sistema.gruposobrinhoadv.com.br/esaj"))
EOF
echo "Worker BB ....... $(docker compose exec -T robos supervisorctl status bb </dev/null 2>/dev/null | awk '{print $2}')"
echo "Último backup ... $(grep 'backup OK' backups/backup.log 2>/dev/null | tail -1 | cut -c1-19 || echo nenhum)"
echo "Disco ........... $(df -h / | awk 'NR==2 {print $5" usado ("$4" livres)"}')"
echo "Memória ......... $(free -h | awk '/Mem:/ {print $3" de "$2}')"
