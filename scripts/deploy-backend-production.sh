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

# 2. Stop only backend-related containers
print_status "Stopping backend-related containers..."
docker compose stop backend-prod queue-prod scheduler-prod mysql-prod redis-prod 2>/dev/null || true

# 3. Remove old backend images to force rebuild
print_status "Removing old backend images..."
docker rmi cloud-haven-api:prod 2>/dev/null || true

# 4. Rebuild only backend container
print_status "Rebuilding backend container..."
docker compose build --no-cache backend-prod

# 5. Start backend services
print_status "Starting backend services..."
docker compose up -d backend-prod queue-prod scheduler-prod mysql-prod redis-prod

# 6. Wait for services to be ready
print_status "Waiting for backend services to be healthy..."
sleep 15

# 7. Run database migrations
print_status "Running database migrations..."
if docker exec backend-prod php artisan migrate --force; then
    print_status "✅ Database migrations completed successfully"
else
    print_error "❌ Database migrations failed"
    exit 1
fi

# 8. Clear Laravel caches
print_status "Clearing Laravel caches..."
docker exec backend-prod php artisan cache:clear
docker exec backend-prod php artisan config:clear
docker exec backend-prod php artisan route:clear
docker exec backend-prod php artisan view:clear

# 9. Restart queue and scheduler
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
