#!/bin/bash

# Frontend-Only Production Deployment Script for Netania De Laiya
# This script deploys only the frontend service for production

set -e

echo "🚀 Starting Frontend-Only Production Deployment for Netania De Laiya..."

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

# 2. Stop only frontend container
print_status "Stopping frontend container..."
docker compose stop frontend-prod 2>/dev/null || true

# 3. Remove old frontend images to force rebuild
print_status "Removing old frontend images..."
docker rmi cloud-haven-web:prod 2>/dev/null || true

# 4. Rebuild only frontend container
print_status "Rebuilding frontend container..."
docker compose build --no-cache frontend-prod

# 5. Start frontend service
print_status "Starting frontend service..."
docker compose up -d frontend-prod

# 6. Wait for service to be ready
print_status "Waiting for frontend service to be healthy..."
sleep 10

# 7. Restart nginx proxy to apply new configurations
print_status "Restarting nginx proxy to apply new configurations..."
cd ../proxy
if [ -f "docker-compose.proxy.yml" ]; then
    docker compose -f docker-compose.proxy.yml restart nginx-proxy
    print_status "✅ Nginx proxy restarted"
else
    print_warning "⚠️  Nginx proxy docker-compose.proxy.yml not found. Please restart nginx manually."
fi

# 8. Verify frontend deployment
print_status "Verifying frontend deployment..."

cd ../prod
# Check if frontend container is running
if docker compose ps | grep "frontend-prod" | grep -q "Up"; then
    print_status "✅ Frontend container is running successfully"
else
    print_error "❌ Frontend container failed to start"
    docker compose ps | grep "frontend-prod"
    exit 1
fi

# 9. Test frontend endpoint
print_status "Testing frontend endpoint..."
PROD_URL="https://www.netaniadelaiya.com"

if curl -s -o /dev/null -w "%{http_code}" "$PROD_URL" | grep -q "200"; then
    print_status "✅ Production frontend is accessible"
else
    print_error "❌ Production frontend is not accessible"
fi

# 10. Test frontend content
print_status "Testing frontend content..."
FRONTEND_HTML=$(curl -s "$PROD_URL")
if echo "$FRONTEND_HTML" | grep -q "Netania De Laiya"; then
    print_status "✅ Frontend shows correct branding (Netania De Laiya)"
else
    print_warning "⚠️  Frontend might not show correct branding. Please verify manually."
fi

# 11. Check for noindex meta tags (should NOT be present in production)
print_status "Checking for noindex meta tags (should NOT be present in production)..."
if echo "$FRONTEND_HTML" | grep -q "noindex"; then
    print_error "❌ Production frontend has noindex meta tags - this should NOT happen!"
else
    print_status "✅ Production frontend does not have noindex meta tags (correct)"
fi

# 12. Verify robots.txt allows crawling
print_status "Verifying robots.txt allows crawling for production..."
PROD_ROBOTS=$(curl -s "$PROD_URL/robots.txt")
if echo "$PROD_ROBOTS" | grep -q "Disallow: /"; then
    print_error "❌ Production robots.txt is blocking crawling - this should NOT happen!"
    echo "Current robots.txt content:"
    echo "$PROD_ROBOTS"
else
    print_status "✅ Production robots.txt allows crawling (correct)"
fi

# 13. Clear CDN caches (if using Cloudflare)
print_status "If you're using Cloudflare or any CDN, please clear cache:"
echo "   - Cloudflare: Dashboard > Caching > Configuration > Purge Everything"
echo "   - Other CDNs: Check your CDN provider's cache clearing options"

# 14. Submit sitemap to search engines
print_status "Submitting sitemap to search engines..."
SITEMAP_URL="$PROD_URL/sitemap.xml"

# Google
curl -s "https://www.google.com/ping?sitemap=$SITEMAP_URL" > /dev/null && print_status "✅ Sitemap submitted to Google"

# Bing
curl -s "https://www.bing.com/ping?sitemap=$SITEMAP_URL" > /dev/null && print_status "✅ Sitemap submitted to Bing"

print_status "🎉 Frontend-only production deployment completed!"
print_status "Frontend service deployed:"
echo "   ✅ Frontend (frontend-prod)"

print_warning "Note: Backend services were not affected by this deployment."
print_status "Production frontend is now available at: $PROD_URL"

print_status "Please verify the following:"
echo "   1. Website shows 'Netania De Laiya' instead of 'CloudHaven'"
echo "   2. All branding is updated correctly"
echo "   3. No noindex meta tags are present"
echo "   4. robots.txt allows crawling"
echo "   5. Production is properly indexed"

print_warning "If the website still shows old content, wait 5-10 minutes for DNS propagation and try again."
