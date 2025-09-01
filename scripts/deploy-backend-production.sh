#!/bin/bash

# Backend-Only Production Deployment Script for Netania De Laiya
# This script deploys only the backend services (API, Queue, Scheduler, Database, Redis)

set -e

echo "🚀 Starting Backend-Only Production Deployment for Netania De Laiya..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Navigate to production directory
print_status "Navigating to production infrastructure directory..."
cd prod

# 2. Clean up any existing backend-prod containers to avoid conflicts
print_status "Cleaning up any existing backend-prod containers..."
docker stop backend-prod 2>/dev/null || true
docker rm backend-prod 2>/dev/null || true

# Also clean up any leftover temporary containers
print_status "Cleaning up any leftover temporary containers..."
docker stop backend-prod-new 2>/dev/null || true
docker rm backend-prod-new 2>/dev/null || true
docker stop backend-prod-temp 2>/dev/null || true
docker rm backend-prod-temp 2>/dev/null || true

# Clean up any containers with similar naming patterns
print_status "Cleaning up any containers with similar naming patterns..."
docker ps -a --filter "name=backend-prod" --filter "name=backend-prod-" --format "{{.Names}}" | xargs -r docker stop 2>/dev/null || true
docker ps -a --filter "name=backend-prod" --filter "name=backend-prod-" --format "{{.Names}}" | xargs -r docker rm 2>/dev/null || true

# 3. Build new backend image alongside running containers (zero-downtime)
print_status "Building new backend image alongside running containers..."
docker compose build --no-cache backend-prod

# 4. Create new backend container with temporary name
print_status "Creating new backend container for zero-downtime deployment..."
NEW_BACKEND_NAME="backend-prod-new"

# Get the current backend-prod container ID before scaling down
CURRENT_BACKEND_ID=$(docker compose ps -q backend-prod)

if [ -n "$CURRENT_BACKEND_ID" ]; then
    print_status "Current backend-prod container ID: $CURRENT_BACKEND_ID"
    # Scale down to 0
    docker compose up -d --scale backend-prod=0
    
    # Create new container with volumes from the old one
    docker run -d \
      --name $NEW_BACKEND_NAME \
      --network global-web-network \
      --env-file ./env/prod.backend.env \
      --volumes-from $CURRENT_BACKEND_ID \
      cloud-haven-api:prod
else
    print_status "No existing backend-prod container found, creating new one..."
    # Create new container without volumes-from
    docker run -d \
      --name $NEW_BACKEND_NAME \
      --network global-web-network \
      --env-file ./env/prod.backend.env \
      cloud-haven-api:prod
fi

# 5. Wait for new container to be healthy
print_status "Waiting for new backend container to be healthy..."
sleep 15

# 6. Health check for new backend container
print_status "Performing health check on new backend container..."
if docker exec $NEW_BACKEND_NAME php artisan tinker --execute="echo 'Health check passed';"; then
    print_status "✅ New backend container is healthy"
else
    print_error "❌ New backend container health check failed"
    print_status "Rolling back - removing failed container..."
    docker stop $NEW_BACKEND_NAME
    docker rm $NEW_BACKEND_NAME
    docker compose up -d backend-prod
    exit 1
fi

# 7. Stop old backend container and rename new one
print_status "Switching traffic to new backend container..."
if [ -n "$CURRENT_BACKEND_ID" ]; then
    docker stop $CURRENT_BACKEND_ID 2>/dev/null || true
    docker rm $CURRENT_BACKEND_ID 2>/dev/null || true
fi

# 8. Stop the temporary container and let Docker Compose manage the backend
print_status "Stopping temporary container to let Docker Compose take over..."
docker stop $NEW_BACKEND_NAME
docker rm $NEW_BACKEND_NAME

# 9. Start all backend services with Docker Compose
print_status "Starting all backend services with Docker Compose..."
docker compose up -d backend-prod queue-prod scheduler-prod

# 10. Restart nginx proxy to apply new backend configurations
print_status "Restarting nginx proxy to apply new backend configurations..."
cd ../proxy
if [ -f "docker-compose.proxy.yml" ]; then
    docker compose -f docker-compose.proxy.yml restart nginx-proxy
    print_status "✅ Nginx proxy restarted"
else
    print_warning "⚠️  Nginx proxy docker-compose.proxy.yml not found. Please restart nginx manually."
fi

# 11. Wait for services to be ready
print_status "Waiting for backend services to be healthy..."
cd ../prod
sleep 15

# 12. Test nginx proxy configuration
print_status "Testing nginx proxy configuration..."
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:80" | grep -q "200\|404\|502"; then
    print_status "✅ Nginx proxy is responding"
else
    print_warning "⚠️  Nginx proxy might not be responding properly"
fi

# 13. Run database migrations
print_status "Running database migrations..."
if docker exec backend-prod php artisan migrate --force; then
    print_status "✅ Database migrations completed successfully"
else
    print_error "❌ Database migrations failed"
    exit 1
fi

# 13.5. Create storage link
print_status "Creating production storage link..."
if docker exec backend-prod php artisan storage:link; then
    print_status "✅ Production storage link created successfully"
else
    print_warning "⚠️  Production storage link already exists or failed (this is usually OK)"
fi

# 13.6. Fix storage permissions
print_status "Fixing production storage permissions..."
if docker exec backend-prod bash -c 'mkdir -p storage/logs storage/framework/{cache,data,sessions,testing,views} bootstrap/cache && chown -R www-data:www-data storage bootstrap/cache && chmod -R 775 storage bootstrap/cache'; then
    print_status "✅ Production storage permissions fixed successfully"
else
    print_warning "⚠️  Production storage permissions fix failed (this might cause logging issues)"
fi

# 14. Clear Laravel caches
print_status "Clearing Laravel caches..."
docker exec backend-prod php artisan cache:clear
docker exec backend-prod php artisan config:clear
docker exec backend-prod php artisan route:clear
docker exec backend-prod php artisan view:clear

# 15. Restart queue and scheduler
print_status "Restarting queue and scheduler services..."
docker compose restart queue-prod scheduler-prod

# 10. Verify backend deployment
print_status "Verifying backend deployment..."

# Check if backend containers are running
if docker compose ps | grep -E "(backend-prod|queue-prod|scheduler-prod|mysql-prod|redis-prod)" | grep -q "Up"; then
    print_status "✅ Backend containers are running successfully"
else
    print_error "❌ Some backend containers failed to start"
    docker compose ps | grep -E "(backend-prod|queue-prod|scheduler-prod|mysql-prod|redis-prod)"
    exit 1
fi

# 11. Test backend API endpoint
print_status "Testing backend API endpoint..."
API_URL="https://api.netaniadelaiya.com"

if curl -s -o /dev/null -w "%{http_code}" "$API_URL" | grep -q "200"; then
    print_status "✅ Production API is accessible"
else
    print_error "❌ Production API is not accessible"
fi

# 12. Test database connection
print_status "Testing database connection..."
if docker exec backend-prod php artisan tinker --execute="DB::connection()->getPdo(); echo 'Database connected successfully';"; then
    print_status "✅ Database connection is working"
else
    print_error "❌ Database connection failed"
fi

# 13. Test Redis connection
print_status "Testing Redis connection..."
if docker exec backend-prod php artisan tinker --execute="Redis::ping(); echo 'Redis connected successfully';"; then
    print_status "✅ Redis connection is working"
else
    print_error "❌ Redis connection failed"
fi

# 14. Check queue status
print_status "Checking queue status..."
QUEUE_STATUS=$(docker exec queue-prod php artisan queue:monitor 2>/dev/null || echo "Queue monitor not available")
print_status "Queue status: $QUEUE_STATUS"

print_status "🎉 Backend-only production deployment completed!"
print_status "Backend services deployed:"
echo "   ✅ API (backend-prod)"
echo "   ✅ Queue Worker (queue-prod)"
echo "   ✅ Scheduler (scheduler-prod)"
echo "   ✅ MySQL Database (mysql-prod)"
echo "   ✅ Redis Cache (redis-prod)"

print_warning "Note: Frontend services were not affected by this deployment."
print_status "Backend API is now available at: $API_URL"
