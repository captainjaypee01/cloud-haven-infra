#!/bin/bash

# Production Deployment Script for Netania De Laiya
# This script helps clear caches and ensure proper deployment

set -e

echo "🚀 Starting Production Deployment for Netania De Laiya..."

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

# 1. Clear any existing caches
print_status "Clearing caches..."
print_status "Note: Production is deployed on Digital Ocean using Docker"

# 2. Clear DNS Cache
print_status "Clearing DNS cache..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux - Handle different distributions
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        sudo systemctl restart systemd-resolved
        print_status "✅ systemd-resolved restarted"
    else
        print_warning "⚠️  systemd-resolved not found, skipping DNS cache clear"
    fi
    
    if systemctl is-active --quiet NetworkManager 2>/dev/null; then
        sudo systemctl restart NetworkManager
        print_status "✅ NetworkManager restarted"
    else
        print_warning "⚠️  NetworkManager not found, skipping network cache clear"
    fi
else
    print_warning "Unknown OS type. Please clear DNS cache manually."
fi

# 3. Clear Browser Caches (instructions)
print_status "Please clear browser caches manually:"
echo "   - Chrome: Ctrl+Shift+Delete (Windows) or Cmd+Shift+Delete (Mac)"
echo "   - Firefox: Ctrl+Shift+Delete (Windows) or Cmd+Shift+Delete (Mac)"
echo "   - Safari: Cmd+Option+E (Mac)"

# 4. Rebuild and redeploy Docker containers
print_status "Rebuilding Docker containers..."
cd infra/prod

# Zero-downtime deployment approach
print_status "Starting zero-downtime production deployment..."

# Remove old images to force rebuild
print_status "Removing old images..."
docker rmi cloud-haven-api:prod cloud-haven-web:prod 2>/dev/null || true

# Rebuild containers
print_status "Rebuilding containers..."
docker compose build --no-cache

# Start new containers with new images (zero-downtime)
print_status "Starting new containers with updated images..."
docker compose up -d --force-recreate

# Wait for new containers to be ready
print_status "Waiting for new containers to be healthy..."
sleep 10

# Restart nginx proxy to apply new configurations
print_status "Restarting nginx proxy to apply new configurations..."
cd ../proxy
if [ -f "docker-compose.proxy.yml" ]; then
    docker compose -f docker-compose.proxy.yml restart nginx-proxy
    print_status "✅ Nginx proxy restarted"
else
    print_warning "⚠️  Nginx proxy docker-compose.proxy.yml not found. Please restart nginx manually."
fi

# 5. Verify deployment
print_status "Verifying deployment..."
sleep 10

# Check if containers are running
if docker compose ps | grep -q "Up"; then
    print_status "✅ Containers are running successfully"
else
    print_error "❌ Some containers failed to start"
    docker compose ps
    exit 1
fi

# 6. Test endpoints
print_status "Testing endpoints..."
PROD_URL="https://www.netaniadelaiya.com"
API_URL="https://api.netaniadelaiya.com"

# Test production frontend
if curl -s -o /dev/null -w "%{http_code}" "$PROD_URL" | grep -q "200"; then
    print_status "✅ Production frontend is accessible"
else
    print_error "❌ Production frontend is not accessible"
fi

# Test production API
if curl -s -o /dev/null -w "%{http_code}" "$API_URL" | grep -q "200"; then
    print_status "✅ Production API is accessible"
else
    print_error "❌ Production API is not accessible"
fi

# 7. Clear CDN caches (if using Cloudflare)
print_status "If you're using Cloudflare or any CDN, please clear cache:"
echo "   - Cloudflare: Dashboard > Caching > Configuration > Purge Everything"
echo "   - Other CDNs: Check your CDN provider's cache clearing options"

# 8. Submit sitemap to search engines
print_status "Submitting sitemap to search engines..."
SITEMAP_URL="$PROD_URL/sitemap.xml"

# Google
curl -s "https://www.google.com/ping?sitemap=$SITEMAP_URL" > /dev/null && print_status "✅ Sitemap submitted to Google"

# Bing
curl -s "https://www.bing.com/ping?sitemap=$SITEMAP_URL" > /dev/null && print_status "✅ Sitemap submitted to Bing"

print_status "🎉 Production deployment completed!"
print_status "Please verify the following:"
echo "   1. Website shows 'Netania De Laiya' instead of 'CloudHaven'"
echo "   2. All branding is updated correctly"
echo "   3. UAT environments are not being crawled"
echo "   4. Production is properly indexed"

print_warning "If the website still shows old content, wait 5-10 minutes for DNS propagation and try again."
