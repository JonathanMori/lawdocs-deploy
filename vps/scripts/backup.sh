#!/usr/bin/env bash
# Backup diário (cron): dump do banco + arquivos (storage) + config, enviados
# CRIPTOGRAFADOS ao Google Drive (remote rclone "backup:"). Guarda 30 dias no Drive
# e 7 dias na VPS. Avisa no Telegram se falhar.
set -euo pipefail
cd /opt/lawdocs
DIR=backups/diario
STAMP=$(date +%Y%m%d-%H%M)
mkdir -p "$DIR"
trap 'scripts/avisar.sh "❌ Backup FALHOU ($STAMP). Veja /opt/lawdocs/backups/backup.log"' ERR

docker compose exec -T mysql sh -c \
  'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers lawdocs 2>/dev/null' \
  </dev/null | gzip > "$DIR/lawdocs-$STAMP.sql.gz"
# dump vazio/truncado = falha (o dump completo termina com "Dump completed")
gunzip -c "$DIR/lawdocs-$STAMP.sql.gz" | tail -1 | grep -q "Dump completed"

docker run --rm -v lawdocs_api_storage:/s:ro alpine tar -czf - -C /s . > "$DIR/storage-$STAMP.tar.gz"
tar -czf "$DIR/config-$STAMP.tar.gz" .env config

rclone copy "$DIR" backup:diario --include "*-$STAMP.*"
rclone delete backup:diario --min-age 30d
find "$DIR" -type f -mtime +7 -delete

echo "$(date '+%F %T') backup OK $STAMP ($(du -ch "$DIR"/*-"$STAMP".* | tail -1 | cut -f1))"
