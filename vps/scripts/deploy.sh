#!/usr/bin/env bash
# Deploy do LawDocs na VPS a partir desta máquina (Git Bash).
#
#   bash lawdocs-deploy/vps/scripts/deploy.sh            # tudo
#   bash lawdocs-deploy/vps/scripts/deploy.sh api web    # só alguns serviços
#
# Envia o HEAD (código commitado) de cada repositório via `git archive`, faz dump
# do banco, rebuilda e sobe. Se a API não ficar saudável, volta as imagens anteriores.
set -euo pipefail

HOST="${LAWDOCS_HOST:-lawdocs-vps}"
REMOTE=/opt/lawdocs
VPS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$(cd "$VPS_DIR/../.." && pwd)"   # pasta que contém os repositórios

declare -A REPO=( [api]=lawdocs-api [web]=lawdocs-web [robos]=lawdocs-worker-bb )
SERVICOS=("$@"); [ ${#SERVICOS[@]} -eq 0 ] && SERVICOS=(api web robos)

echo "==> Conferindo repositórios"
for s in "${SERVICOS[@]}"; do
  r="${REPO[$s]:?serviço desconhecido: $s}"
  branch=$(git -C "$BASE/$r" rev-parse --abbrev-ref HEAD)
  [ "$branch" = main ] || { echo "ERRO: $r está na branch '$branch' (esperado main)"; exit 1; }
  if [ -n "$(git -C "$BASE/$r" status --porcelain --untracked-files=no)" ]; then
    echo "AVISO: $r tem alterações não commitadas (não serão enviadas)"
  fi
  echo "    $r @ $(git -C "$BASE/$r" log --oneline -1)"
done

echo "==> Enviando compose/nginx/scripts"
tar -C "$VPS_DIR" -cf - docker-compose.yml nginx scripts \
  | ssh "$HOST" "mkdir -p $REMOTE && tar -xf - -C $REMOTE"

for s in "${SERVICOS[@]}"; do
  r="${REPO[$s]}"
  echo "==> Enviando código: $r"
  git -C "$BASE/$r" -c core.autocrlf=false archive --format=tar HEAD \
    | ssh "$HOST" "rm -rf $REMOTE/build/$r.new && mkdir -p $REMOTE/build/$r.new && tar -xf - -C $REMOTE/build/$r.new && rm -rf $REMOTE/build/$r && mv $REMOTE/build/$r.new $REMOTE/build/$r"
done

# Atenção: o script remoto chega pelo stdin; todo comando lá dentro que lê stdin
# (docker compose exec/run) precisa de </dev/null, senão "engole" o resto do script.
ssh "$HOST" "REMOTE=$REMOTE SERVICOS='${SERVICOS[*]}' bash -s" <<'EOF'
set -euo pipefail
cd "$REMOTE"
mkdir -p backups

if docker compose ps --status running mysql | grep -q mysql; then
  f="backups/pre-deploy-$(date +%Y%m%d-%H%M%S).sql.gz"
  echo "==> Backup do banco: $f"
  docker compose exec -T mysql sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers lawdocs' </dev/null | gzip > "$f"
fi

for s in $SERVICOS; do
  docker image inspect "lawdocs-$s:latest" >/dev/null 2>&1 && docker tag "lawdocs-$s:latest" "lawdocs-$s:previous" || true
done

echo "==> Build: $SERVICOS"
docker compose build $SERVICOS </dev/null
docker compose up -d </dev/null

echo "==> Aguardando API"
for i in $(seq 1 40); do
  if docker compose exec -T proxy wget -qO- http://api:8080/actuator/health </dev/null 2>/dev/null | grep -q '"UP"'; then
    echo "API OK"; docker image prune -f >/dev/null; docker compose ps; exit 0
  fi
  sleep 5
done

echo "ERRO: API não ficou saudável. Voltando versão anterior."
docker compose logs --tail 80 api || true
for s in $SERVICOS; do
  docker image inspect "lawdocs-$s:previous" >/dev/null 2>&1 && docker tag "lawdocs-$s:previous" "lawdocs-$s:latest" || true
done
docker compose up -d
exit 1
EOF
