#!/usr/bin/env bash
# Roda na VPS (cron diário): renova o certificado Let's Encrypt se estiver perto de
# vencer e recarrega o nginx.
set -euo pipefail
cd /opt/lawdocs
docker compose run --rm certbot renew --quiet --webroot -w /var/www/certbot
docker compose exec -T proxy nginx -s reload
