# Deployment Scripts Documentation

This directory contains specialized deployment scripts for the Netania De Laiya project. These scripts allow you to deploy only specific components (backend or frontend) to specific environments (production or UAT) without affecting other services.

## 🌐 Environment Context

These scripts are designed to work in two different environments:

1. **Local Development**: When running from the project root directory
2. **Production Droplet**: When running from `/opt/code/cloud-haven-infra/` on the Digital Ocean droplet

The scripts automatically detect and use the correct paths for each environment.

## Available Scripts

### Backend-Only Deployment Scripts

#### `deploy-backend-production.sh`
Deploys only the backend services to production:
- API (backend-prod)
- Queue Worker (queue-prod)
- Scheduler (scheduler-prod)
- MySQL Database (mysql-prod)
- Redis Cache (redis-prod)

**Usage:**
```bash
# From project root (local development)
./infra/scripts/deploy-backend-production.sh

# From droplet (/opt/code/cloud-haven-infra/)
./scripts/deploy-backend-production.sh
```

**What it does:**
1. Stops only backend-related containers
2. Rebuilds the backend container
3. Starts backend services
4. Runs database migrations
5. Creates storage link
6. **Fixes storage permissions** (prevents logging issues)
7. Clears Laravel caches
8. Restarts queue and scheduler
9. Verifies deployment and tests connections

#### `deploy-backend-uat.sh`
Deploys only the backend services to UAT:
- API (backend-uat)
- Queue Worker (queue-uat)
- Scheduler (scheduler-uat)
- MySQL Database (mysql-uat)
- Redis Cache (redis-uat)

**Usage:**
```bash
# From project root (local development)
./infra/scripts/deploy-backend-uat.sh

# From droplet (/opt/code/cloud-haven-infra/)
./scripts/deploy-backend-uat.sh
```

**What it does:**
1. Stops only backend-related UAT containers
2. Rebuilds the UAT backend container
3. Starts UAT backend services
4. Runs UAT database migrations
5. Creates UAT storage link
6. **Fixes UAT storage permissions** (prevents logging issues)
7. Clears UAT Laravel caches
8. Restarts UAT queue and scheduler
9. Verifies UAT deployment and tests connections
10. Verifies robots.txt blocking for UAT API

### Frontend-Only Deployment Scripts

#### `deploy-frontend-production.sh`
Deploys only the frontend service to production:
- Frontend (frontend-prod)

**Usage:**
```bash
# From project root (local development)
./infra/scripts/deploy-frontend-production.sh

# From droplet (/opt/code/cloud-haven-infra/)
./scripts/deploy-frontend-production.sh
```

**What it does:**
1. Stops only the frontend container
2. Rebuilds the frontend container
3. Starts the frontend service
4. Restarts nginx proxy
5. Verifies deployment and tests frontend
6. Checks branding and SEO settings
7. Submits sitemap to search engines

#### `deploy-frontend-uat.sh`
Deploys only the frontend service to UAT:
- Frontend (frontend-uat)

**Usage:**
```bash
# From project root (local development)
./infra/scripts/deploy-frontend-uat.sh

# From droplet (/opt/code/cloud-haven-infra/)
./scripts/deploy-frontend-uat.sh
```

**What it does:**
1. Stops only the UAT frontend container
2. Rebuilds the UAT frontend container
3. Starts the UAT frontend service
4. Restarts nginx proxy
5. Verifies UAT deployment and tests frontend
6. Verifies noindex meta tags and robots.txt blocking

## Benefits of Separate Scripts

### Efficiency
- **Faster deployments**: Only rebuild and restart the services you need
- **Zero-downtime deployments**: Services remain available during updates
- **Resource optimization**: Don't waste time building unnecessary containers

### Flexibility
- **Targeted updates**: Deploy only backend changes or only frontend changes
- **Environment-specific**: Choose between production and UAT deployments
- **Rollback capability**: If one component fails, others remain unaffected

### Safety
- **Isolated deployments**: Changes to one component don't affect others
- **Zero-downtime**: Services remain available during deployment
- **Automatic rollback**: Failed deployments automatically revert to previous version
- **Health checks**: New containers are verified before traffic switching
- **Better testing**: Test individual components in isolation

## When to Use Each Script

### Use Backend Scripts When:
- Making API changes
- Updating database migrations
- Modifying queue workers or schedulers
- Changing backend configuration
- Updating Laravel application code

### Use Frontend Scripts When:
- Making UI/UX changes
- Updating React components
- Changing styling or assets
- Modifying frontend configuration
- Updating build settings

### Use Production Scripts When:
- Deploying to live environment
- Making changes that affect end users
- Updating production configurations

### Use UAT Scripts When:
- Testing changes before production
- Validating new features
- Testing deployment processes
- Development and staging work

## Zero-Downtime Deployment Strategy

All deployment scripts now implement **zero-downtime deployment** using the following approach:

### Backend Deployment Process
1. **Build new image** alongside running containers
2. **Create new container** with temporary name (e.g., `backend-prod-new`)
3. **Health check** new container to ensure it's working
4. **Switch traffic** from old to new container
5. **Clean up** old container and rename new one
6. **Automatic rollback** if health check fails

### Frontend Deployment Process
1. **Build new image** alongside running containers
2. **Create new container** with temporary name (e.g., `frontend-prod-new`)
3. **Health check** new container to ensure it's working
4. **Switch traffic** from old to new container
5. **Clean up** old container and rename new one
6. **Automatic rollback** if health check fails

### Benefits of Zero-Downtime
- ✅ **No service interruption** during deployments
- ✅ **Automatic rollback** if new containers fail
- ✅ **Health verification** before traffic switching
- ✅ **Seamless updates** for end users
- ✅ **Reduced deployment risk**

## Prerequisites

1. **Docker**: Ensure Docker is installed and running
2. **Docker Compose**: Ensure Docker Compose is available
3. **Network**: Ensure the `global-web-network` exists
4. **Environment Files**: Ensure environment files are properly configured
5. **Permissions**: Scripts should be executable (`chmod +x`)

## Environment URLs

### Production
- Frontend: https://www.netaniadelaiya.com
- API: https://api.netaniadelaiya.com

### UAT
- Frontend: https://uat.netaniadelaiya.com
- API: https://uat-api.netaniadelaiya.com

## 🔧 Automatic Permission Fixes

All backend deployment scripts now automatically fix storage permissions to prevent common production logging issues:

**What gets fixed:**
- Creates necessary directories: `storage/logs`, `storage/framework/*`, `bootstrap/cache`
- Sets proper ownership: `www-data:www-data`
- Sets proper permissions: `775` for directories, `664` for files
- Runs automatically after storage link creation, before cache clearing

**Why this matters:**
- Prevents "Permission denied" errors when writing to log files
- Ensures Laravel can create cache files and sessions
- Fixes issues that commonly occur in Docker production environments
- Eliminates the need for manual permission fixes after deployment

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   # Local development
   chmod +x infra/scripts/deploy-*.sh
   
   # Production droplet
   chmod +x scripts/deploy-*.sh
   ```

2. **Docker Network Not Found**
   ```bash
   docker network create global-web-network
   ```

3. **Environment Files Missing**
   - Check that environment files exist in `infra/prod/env/` and `infra/uat/env/`
   - Ensure they have the correct configuration

4. **Container Build Failures**
   - Check Docker logs: `docker logs <container-name>`
   - Verify source code is up to date
   - Check for syntax errors in Dockerfiles

### Verification Commands

After deployment, you can verify services are running:

```bash
# Check all containers
docker ps

# Check specific environment
cd infra/prod && docker compose ps
cd infra/uat && docker compose -f docker-compose.uat.yml ps

# Check logs
docker logs backend-prod
docker logs frontend-prod
```

## Original Full Deployment Scripts

The original full deployment scripts are still available:
- `deploy-production.sh` - Deploys everything to production
- `deploy-uat.sh` - Deploys everything to UAT

Use these when you need to deploy all services at once or when setting up the environment for the first time.

## 🚀 Usage Examples

### Local Development (from project root)
```bash
# Deploy only backend changes to production
./infra/scripts/deploy-backend-production.sh

# Deploy only frontend changes to UAT
./infra/scripts/deploy-frontend-uat.sh

# Deploy only backend changes to UAT
./infra/scripts/deploy-backend-uat.sh

# Deploy only frontend changes to production
./infra/scripts/deploy-frontend-production.sh
```

### Production Droplet (/opt/code/cloud-haven-infra/)
```bash
# Deploy only backend changes to production
./scripts/deploy-backend-production.sh

# Deploy only frontend changes to UAT
./scripts/deploy-frontend-uat.sh

# Deploy only backend changes to UAT
./scripts/deploy-backend-uat.sh

# Deploy only frontend changes to production
./scripts/deploy-frontend-production.sh
```
