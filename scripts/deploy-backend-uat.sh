#!/bin/bash

# Backend-Only UAT Deployment Script for Netania De Laiya
# This script deploys only the backend services for UAT environment

set -e

echo "🚀 Starting Backend-Only UAT Deployment for Netania De Laiya..."

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

# 1. Navigate to UAT directory
print_status "Navigating to UAT infrastructure directory..."
cd uat

# 2. Build new UAT backend image alongside running containers (zero-downtime)
print_status "Building new UAT backend image alongside running containers..."
docker compose -f docker-compose.uat.yml build --no-cache backend-uat

# 3. Create new UAT backend container with temporary name
print_status "Creating new UAT backend container for zero-downtime deployment..."
NEW_BACKEND_NAME="backend-uat-new"

# Get the current backend-uat container ID before scaling down
CURRENT_BACKEND_ID=$(docker compose -f docker-compose.uat.yml ps -q backend-uat)

if [ -n "$CURRENT_BACKEND_ID" ]; then
    print_status "Current backend-uat container ID: $CURRENT_BACKEND_ID"
    # Scale down to 0
    docker compose -f docker-compose.uat.yml up -d --scale backend-uat=0
    
    # Create new container with volumes from the old one
    docker run -d \
      --name $NEW_BACKEND_NAME \
      --network global-web-network \
      --env-file ./env/uat.backend.env \
      --volumes-from $CURRENT_BACKEND_ID \
      cloud-haven-api:uat
else
    print_status "No existing backend-uat container found, creating new one..."
    # Create new container without volumes-from
    docker run -d \
      --name $NEW_BACKEND_NAME \
      --network global-web-network \
      --env-file ./env/uat.backend.env \
      cloud-haven-api:uat
fi

# 4. Wait for new container to be healthy
print_status "Waiting for new UAT backend container to be healthy..."
sleep 15

# 5. Health check for new UAT backend container
print_status "Performing health check on new UAT backend container..."
if docker exec $NEW_BACKEND_NAME php artisan tinker --execute="echo 'Health check passed';"; then
    print_status "✅ New UAT backend container is healthy"
else
    print_error "❌ New UAT backend container health check failed"
    print_status "Rolling back - removing failed container..."
    docker stop $NEW_BACKEND_NAME
    docker rm $NEW_BACKEND_NAME
    docker compose -f docker-compose.uat.yml up -d backend-uat
    exit 1
fi

# 6. Stop old UAT backend container and rename new one
print_status "Switching traffic to new UAT backend container..."
if [ -n "$CURRENT_BACKEND_ID" ]; then
    docker stop $CURRENT_BACKEND_ID 2>/dev/null || true
    docker rm $CURRENT_BACKEND_ID 2>/dev/null || true
fi

# 7. Start UAT backend services with new image
print_status "Starting UAT backend services with new image..."
# The new container is already running with the temporary name, so we just need to start the other services
docker compose -f docker-compose.uat.yml up -d queue-uat scheduler-uat

# 8. Rename the new container to the proper name
print_status "Renaming new container to backend-uat..."
docker rename $NEW_BACKEND_NAME backend-uat

# 6. Wait for services to be ready
print_status "Waiting for UAT backend services to be healthy..."
sleep 15

# 7. Run database migrations
print_status "Running UAT database migrations..."
if docker exec backend-uat php artisan migrate --force; then
    print_status "✅ UAT database migrations completed successfully"
else
    print_error "❌ UAT database migrations failed"
    exit 1
fi

# 8. Clear Laravel caches
print_status "Clearing UAT Laravel caches..."
docker exec backend-uat php artisan cache:clear
docker exec backend-uat php artisan config:clear
docker exec backend-uat php artisan route:clear
docker exec backend-uat php artisan view:clear

# 9. Restart queue and scheduler
print_status "Restarting UAT queue and scheduler services..."
docker compose -f docker-compose.uat.yml restart queue-uat scheduler-uat

# 10. Verify UAT backend deployment
print_status "Verifying UAT backend deployment..."

# Check if backend containers are running
if docker compose -f docker-compose.uat.yml ps | grep -E "(backend-uat|queue-uat|scheduler-uat|mysql-uat|redis-uat)" | grep -q "Up"; then
    print_status "✅ UAT backend containers are running successfully"
else
    print_error "❌ Some UAT backend containers failed to start"
    docker compose -f docker-compose.uat.yml ps | grep -E "(backend-uat|queue-uat|scheduler-uat|mysql-uat|redis-uat)"
    exit 1
fi

# 11. Test UAT backend API endpoint
print_status "Testing UAT backend API endpoint..."
UAT_API_URL="https://uat-api.netaniadelaiya.com"

if curl -s -o /dev/null -w "%{http_code}" "$UAT_API_URL" | grep -q "200"; then
    print_status "✅ UAT API is accessible"
else
    print_error "❌ UAT API is not accessible"
fi

# 12. Test database connection
print_status "Testing UAT database connection..."
if docker exec backend-uat php artisan tinker --execute="DB::connection()->getPdo(); echo 'UAT Database connected successfully';"; then
    print_status "✅ UAT database connection is working"
else
    print_error "❌ UAT database connection failed"
fi

# 13. Test Redis connection
print_status "Testing UAT Redis connection..."
if docker exec backend-uat php artisan tinker --execute="Redis::ping(); echo 'UAT Redis connected successfully';"; then
    print_status "✅ UAT Redis connection is working"
else
    print_error "❌ UAT Redis connection failed"
fi

# 14. Check queue status
print_status "Checking UAT queue status..."
QUEUE_STATUS=$(docker exec queue-uat php artisan queue:monitor 2>/dev/null || echo "UAT Queue monitor not available")
print_status "UAT Queue status: $QUEUE_STATUS"

# 15. Verify robots.txt blocking for UAT API
print_status "Verifying robots.txt blocking for UAT API..."
UAT_API_ROBOTS=$(curl -s "$UAT_API_URL/robots.txt")
if echo "$UAT_API_ROBOTS" | grep -q "Disallow: /"; then
    print_status "✅ UAT API robots.txt is blocking crawling"
else
    print_error "❌ UAT API robots.txt is not properly blocking crawling"
    echo "Current robots.txt content:"
    echo "$UAT_API_ROBOTS"
fi

print_status "🎉 Backend-only UAT deployment completed!"
print_status "UAT backend services deployed:"
echo "   ✅ API (backend-uat)"
echo "   ✅ Queue Worker (queue-uat)"
echo "   ✅ Scheduler (scheduler-uat)"
echo "   ✅ MySQL Database (mysql-uat)"
echo "   ✅ Redis Cache (redis-uat)"

print_warning "Note: Frontend services were not affected by this deployment."
print_status "UAT Backend API is now available at: $UAT_API_URL"
print_warning "Remember: UAT is for testing only and should not be publicly accessible or indexed."
