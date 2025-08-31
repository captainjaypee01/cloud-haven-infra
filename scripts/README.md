# Deployment Scripts

This directory contains deployment scripts for Netania De Laiya infrastructure.

## Scripts Overview

### `verify-deployment.sh`
- **Purpose**: Verifies all environments and their crawling status
- **Usage**: `./scripts/verify-deployment.sh`
- **What it checks**:
  - Environment accessibility
  - Robots.txt configurations
  - Branding verification
  - Docker container status

### `quick-deploy-prod.sh`
- **Purpose**: Quick production deployment (Digital Ocean)
- **Usage**: `./scripts/quick-deploy-prod.sh`
- **What it does**:
  - Rebuilds production Docker containers
  - Tests endpoints
  - Verifies deployment

### `deploy-uat.sh`
- **Purpose**: Deploy UAT with crawling prevention
- **Usage**: `./scripts/deploy-uat.sh`
- **What it does**:
  - Rebuilds UAT containers
  - Verifies robots.txt blocking
  - Checks noindex meta tags

### `deploy-production.sh`
- **Purpose**: Full production deployment with cache clearing
- **Usage**: `./scripts/deploy-production.sh`
- **What it does**:
  - Complete production deployment
  - Cache clearing
  - Sitemap submission

## Usage on Droplet

1. **SSH into your droplet**:
   ```bash
   ssh root@your-droplet-ip
   ```

2. **Navigate to infra directory**:
   ```bash
   cd /path/to/your/infra
   ```

3. **Make scripts executable** (if needed):
   ```bash
   chmod +x scripts/*.sh
   ```

4. **Run scripts**:
   ```bash
   # Verify current status
   ./scripts/verify-deployment.sh
   
   # Deploy production
   ./scripts/quick-deploy-prod.sh
   
   # Deploy UAT
   ./scripts/deploy-uat.sh
   ```

## Environment Setup

- **Production**: `prod/docker-compose.yml`
- **UAT**: `uat/docker-compose.uat.yml`
- **Nginx**: `proxy/nginx/reverseproxy.dynamic.conf`

## Expected Behavior

| Environment | URL | Should be Crawled |
|-------------|-----|------------------|
| Production Frontend | www.netaniadelaiya.com | ✅ YES |
| Production API | api.netaniadelaiya.com | ❌ NO |
| UAT Frontend | uat.netaniadelaiya.com | ❌ NO |
| UAT API | uat-api.netaniadelaiya.com | ❌ NO |

## Troubleshooting

If scripts fail:
1. Check if you're in the correct directory (`infra/`)
2. Verify Docker is running: `docker ps`
3. Check container logs: `docker compose logs`
4. Ensure scripts are executable: `chmod +x scripts/*.sh`
