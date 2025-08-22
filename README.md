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
  -d app.netaniadelaiya.com -d api.netaniadelaiya.com \
  -d uat-app.netaniadelaiya.com -d uat-api.netaniadelaiya.com

# start proxy and reload
docker start nginx-proxy
docker exec -t nginx-proxy nginx -s reload
```
The proxy config already has the 80→443 redirects and `ssl_certificate` paths. After issuance, HTTPS should work immediately.

> **Auto‑renew:** create a monthly cron:
> ```bash
> (crontab -l 2>/dev/null; echo "0 3 * * 0 certbot renew --post-hook 'docker exec nginx-proxy nginx -s reload' >/var/log/certbot-renew.log 2>&1") | crontab -
> ```
