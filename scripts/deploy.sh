#!/usr/bin/env bash
set -euo pipefail


STACK=${1:-prod} # prod | uat
BASE_DIR=/opt/cloud-haven-infra


cd "$BASE_DIR"


# Ensure network exists
if ! docker network inspect global-web-network >/dev/null 2>&1; then
    docker network create global-web-network
fi


case "$STACK" in
    prod)
        cd prod
        docker compose -f docker-compose.prod.yml up -d --build
        docker compose -f docker-compose.prod.yml exec -T backend-prod php artisan migrate --force
        docker compose -f docker-compose.prod.yml exec -T backend-prod php artisan storage:link || true
        ;;
    uat)
        cd uat
        docker compose -f docker-compose.uat.yml up -d --build
        docker compose -f docker-compose.uat.yml exec -T backend-uat php artisan migrate --force
        docker compose -f docker-compose.uat.yml exec -T backend-uat php artisan storage:link || true
        ;;
    *) echo "Usage: $0 [prod|uat]"; exit 1;;


esac