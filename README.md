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


## 9) Enable HTTPS with Let’s Encrypt (webroot + Docker proxy)

Renewals use **HTTP-01 via webroot** so `nginx-proxy` keeps port 80; no stopping the container for `certbot renew`.

### One-time: directories and permissions (as user `deploy`)

```bash
mkdir -p /home/deploy/acme-webroot \
         /home/deploy/letsencrypt/lib \
         /home/deploy/letsencrypt/log \
         /home/deploy/logs

# post-hook reloads Nginx in Docker — deploy must use the Docker socket without sudo
sudo usermod -aG docker deploy
# log out and back in (or `newgrp docker`)
```

If you **already have** certs under **`/etc/letsencrypt`** (from earlier `sudo certbot`), copy them into deploy’s tree so the compose mount matches (short maintenance window):

```bash
sudo rsync -a /etc/letsencrypt/ /home/deploy/letsencrypt/
sudo chown -R deploy:deploy /home/deploy/letsencrypt /home/deploy/acme-webroot
```

Old renewals may still reference **`standalone`**; after migrating, run **`certbot certonly --webroot ...`** once (same `-d` list as the cert) so `renewal/*.conf` switches to webroot. Only include **`-d` names that resolve to this host for HTTP** on port 80; if UAT subdomains are commented out in Nginx, either add ACME `location` blocks for those `listen 80` servers when you enable UAT or omit them from the certificate.

### Proxy compose volumes

`proxy/docker-compose.proxy.yml` mounts:

- `/home/deploy/letsencrypt` → `/etc/letsencrypt` inside the container (unchanged paths in `ssl_certificate` in Nginx).
- `/home/deploy/acme-webroot` → `/var/www/certbot` for `/.well-known/acme-challenge/`.

Bring the proxy up after editing compose:

```bash
cd /opt/code/cloud-haven-infra/proxy   # or your path
docker compose -f docker-compose.proxy.yml up -d
```

### Issue or re-issue a certificate (as `deploy`, adjust `-d` list to match your cert)

```bash
certbot certonly --webroot \
  -w /home/deploy/acme-webroot \
  --config-dir /home/deploy/letsencrypt \
  --work-dir /home/deploy/letsencrypt/lib \
  --logs-dir /home/deploy/letsencrypt/log \
  -d netaniadelaiya.com -d www.netaniadelaiya.com -d api.netaniadelaiya.com \
  -d uat.netaniadelaiya.com -d uat-api.netaniadelaiya.com

docker exec nginx-proxy nginx -s reload
```

Dry-run renewals:

```bash
certbot renew --dry-run \
  --config-dir /home/deploy/letsencrypt \
  --work-dir /home/deploy/letsencrypt/lib \
  --logs-dir /home/deploy/letsencrypt/log
```

### Auto-renew (crontab **as `deploy`**)

```bash
crontab -e
```

```cron
0 3 * * 0 certbot renew --config-dir /home/deploy/letsencrypt --work-dir /home/deploy/letsencrypt/lib --logs-dir /home/deploy/letsencrypt/log --post-hook 'docker exec nginx-proxy nginx -s reload' >> /home/deploy/logs/certbot-renew.log 2>&1
```


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

# validate config without starting the service (paths must match docker-compose.proxy.yml mounts)
docker run --rm \
  -v /opt/code/cloud-haven-infra/proxy/nginx/reverseproxy.prod.only.conf:/etc/nginx/conf.d/default.conf:ro \
  -v /home/deploy/letsencrypt:/etc/letsencrypt:ro \
  -v /home/deploy/acme-webroot:/var/www/certbot:ro \
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
