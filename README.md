cd /opt/code/cloud-haven-infra/proxy

docker compose -f docker-compose.proxy.yml up -d


cd /opt/code/cloud-haven-infra/prod

# (A) Build backend & frontend images explicitly
docker compose -f docker-compose.yml build backend-prod frontend-prod


# (B) Bring up the whole stack
docker compose -f docker-compose.yml up -d