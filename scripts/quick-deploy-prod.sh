#!/bin/bash

# Quick Production Deployment Script for Digital Ocean
# This script quickly rebuilds and deploys your production environment

set -e

echo "🚀 Quick Production Deployment for Netania De Laiya (Digital Ocean)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "prod/docker-compose.yml" ]; then
    print_error "Please run this script from the infra directory"
    exit 1
fi

print_status "Starting quick production deployment..."

# Navigate to production directory
cd prod

# Stop containers
print_status "Stopping production containers..."
docker compose down

# Remove old images to force rebuild
print_status "Removing old images..."
docker rmi cloud-haven-web:prod cloud-haven-api:prod 2>/dev/null || true

# Rebuild containers
print_status "Rebuilding containers..."
docker compose build --no-cache

# Start containers
print_status "Starting containers..."
docker compose up -d

# Restart nginx proxy to apply new configurations
print_status "Restarting nginx proxy to apply new configurations..."
cd ../proxy
if [ -f "docker-compose.yml" ]; then
    docker compose restart nginx
    print_status "✅ Nginx proxy restarted"
else
    print_warning "⚠️  Nginx proxy docker-compose.yml not found. Please restart nginx manually."
fi

# Wait for containers to be ready
print_status "Waiting for containers to be ready..."
sleep 15

# Check if containers are running
if docker-compose ps | grep -q "Up"; then
    print_status "✅ Production containers are running successfully"
else
    print_error "❌ Some production containers failed to start"
    docker-compose ps
    exit 1
fi

# Test endpoints
print_status "Testing endpoints..."
PROD_URL="https://www.netaniadelaiya.com"
API_URL="https://api.netaniadelaiya.com"

# Test production frontend
if curl -s -o /dev/null -w "%{http_code}" "$PROD_URL" | grep -q "200"; then
    print_status "✅ Production frontend is accessible"
else
    print_warning "⚠️  Production frontend might still be starting up"
fi

# Test production API
if curl -s -o /dev/null -w "%{http_code}" "$API_URL" | grep -q "200"; then
    print_status "✅ Production API is accessible"
else
    print_warning "⚠️  Production API might still be starting up"
fi

print_status "🎉 Quick deployment completed!"
print_status "Please verify:"
echo "   1. Visit https://www.netaniadelaiya.com"
echo "   2. Check that it shows 'Netania De Laiya' instead of 'CloudHaven'"
echo "   3. All branding should be updated"

print_warning "If you still see old content:"
echo "   1. Clear your browser cache (Ctrl+Shift+Delete)"
echo "   2. Try incognito/private browsing"
echo "   3. Wait 2-3 minutes for all services to fully start"

print_status "To view logs: docker-compose logs -f"
print_status "To check container status: docker-compose ps"
