```bash
cd /opt/code/cloud-haven-infra/proxy

docker compose -f docker-compose.proxy.yml up -d

```
```bash
cd /opt/code/cloud-haven-infra/prod

# (A) Build backend & frontend images explicitly
docker compose -f docker-compose.yml build backend-prod frontend-prod


# (B) Bring up the whole stack
docker compose -f docker-compose.yml up -d
```


## 9) Enable HTTPS with Let’s Encrypt
**Stop the proxy** to free port 80 for the challenge, request certs, then start proxy.
```bash
cd /opt/cloud-haven-infra/prod

# stop proxy temporarily
docker stop nginx-proxy

# obtain certs (adjust domains)
sudo apt-get install -y certbot
sudo certbot certonly --standalone \
  -d netaniadelaiya.com -d www.netaniadelaiya.com \
  -d api.netaniadelaiya.com -d uat.netaniadelaiya.com -d uat-api.netaniadelaiya.com

# start proxy and reload
docker start nginx-proxy
docker exec -t nginx-proxy nginx -s reload
```
The proxy config already has the 80→443 redirects and `ssl_certificate` paths. After issuance, HTTPS should work immediately.

> **Auto‑renew:** create a monthly cron:
> ```bash
> (crontab -l 2>/dev/null; echo "0 3 * * 0 certbot renew --post-hook 'docker exec nginx-proxy nginx -s reload' >/var/log/certbot-renew.log 2>&1") | crontab -
> ```


# ensure required dirs exist in the mounted volume and set correct owner (www-data uid=33)
```bash
cd /opt/code/cloud-haven-infra/prod

docker compose -f docker-compose.yml exec -T backend-prod bash -lc \
'mkdir -p storage/logs storage/framework/{cache,data,sessions,testing,views} bootstrap/cache \
 && chown -R www-data:www-data storage bootstrap/cache \
 && chmod -R 775 storage bootstrap/cache'

docker compose -f docker-compose.uat.yml exec -T backend-uat bash -lc \
'mkdir -p storage/logs storage/framework/{cache,data,sessions,testing,views} bootstrap/cache \
 && chown -R www-data:www-data storage bootstrap/cache \
 && chmod -R 775 storage bootstrap/cache'

# (optional) initialize volume from the host side too — persists even if the container is recreated
docker run --rm -v laravel-prod-storage:/data alpine sh -c "chown -R 33:33 /data && chmod -R 775 /data"
```

# Rebuild + restart the frontend image without cache so the new env is baked in:
```bash
cd /opt/code/cloud-haven-infra/prod
docker compose -f docker-compose.yml build frontend-prod --no-cache
docker compose -f docker-compose.yml up -d frontend-prod
docker exec -t nginx-proxy nginx -s reload
```

# How to see proxy errors quickly
```bash
# show why it exited
docker logs --tail=200 nginx-proxy

# run in foreground to watch it fail
cd /opt/code/cloud-haven-infra/proxy
docker compose -f docker-compose.proxy.yml up nginx-proxy

# validate config without starting the service
docker run --rm \
  -v /opt/code/cloud-haven-infra/proxy/nginx/reverseproxy.prod.only.conf:/etc/nginx/conf.d/default.conf:ro \
  -v /etc/letsencrypt:/etc/letsencrypt:ro \
  nginx:1.28-alpine nginx -t

```

# NGINX Test and Reload
```bash
docker exec nginx-proxy nginx -t && docker exec nginx-proxy nginx -s reload
```


## API

## Set APP_KEY the right way for Docker
Do not run php artisan key:generate to write into .env (there likely isn’t a .env in the container).
Instead, generate a key and put it in your compose env file.

```bash
# show a key (don’t write .env)
docker exec backend-prod php artisan key:generate --show
# copy output like: base64:xxxxxxxxxxxxxxxxxx
```
Open ./env/prod.backend.env and ensure you have:

```bash
docker compose up -d --force-recreate backend-prod queue-prod scheduler-prod

docker exec backend-prod printenv APP_KEY
docker exec backend-prod printenv DB_HOST
docker exec -it backend-uat bash
```

3) Run migrations (and storage link)
```bash
docker exec backend-prod php artisan migrate --force
docker exec backend-prod php artisan storage:link || true
```
