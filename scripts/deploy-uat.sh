#!/bin/bash

# UAT Deployment Script for Netania De Laiya
# This script ensures UAT is properly configured to prevent crawling

set -e

echo "🚀 Starting UAT Deployment for Netania De Laiya..."

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

# 1. Rebuild and redeploy UAT Docker containers
print_status "Rebuilding UAT Docker containers..."
cd uat

# Zero-downtime deployment approach
print_status "Starting zero-downtime UAT deployment..."

# Avoid removing images up-front; build will replace as needed (prevents gaps)
print_status "Preparing to build updated UAT images without removing existing ones..."

# Rebuild containers (no-cache)
print_status "Rebuilding UAT containers..."
docker compose -f docker-compose.uat.yml build --no-cache

# Start/replace containers with updated images (no force recreate)
print_status "Starting UAT containers with updated images..."
docker compose -f docker-compose.uat.yml up -d

# Wait for new containers to be ready
print_status "Waiting for new UAT containers to be healthy..."
sleep 10

# 2. Reload nginx proxy (graceful, avoids 502) to apply any config changes
print_status "Reloading nginx proxy to apply any config changes..."
cd ../proxy
if [ -f "docker-compose.proxy.yml" ]; then
    if docker exec nginx-proxy nginx -s reload 2>/dev/null; then
        print_status "✅ Nginx proxy reloaded"
    else
        print_warning "⚠️  Direct reload failed, attempting HUP signal via compose"
        docker compose -f docker-compose.proxy.yml kill -s HUP nginx-proxy || print_warning "⚠️  Could not signal nginx-proxy; ensure it is running"
    fi
else
    print_warning "⚠️  Nginx proxy docker-compose.proxy.yml not found. Skipping reload."
fi

# 3. Verify UAT deployment
print_status "Verifying UAT deployment..."
sleep 10

cd ../
# Check if containers are running
if docker compose -f uat/docker-compose.uat.yml ps | grep -q "Up"; then
    print_status "✅ UAT containers are running successfully"
else
    print_error "❌ Some UAT containers failed to start"
    docker compose -f uat/docker-compose.uat.yml ps
    exit 1
fi

# 4. Run database migrations
print_status "Running UAT database migrations..."
if docker exec backend-uat php artisan migrate --force; then
    print_status "✅ UAT database migrations completed successfully"
else
    print_error "❌ UAT database migrations failed"
    exit 1
fi

# 4.5. Create storage link
print_status "Creating UAT storage link..."
if docker exec backend-uat php artisan storage:link; then
    print_status "✅ UAT storage link created successfully"
else
    print_warning "⚠️  UAT storage link already exists or failed (this is usually OK)"
fi

# 4.6. Fix storage permissions
print_status "Fixing UAT storage permissions..."
if docker exec backend-uat bash -c 'mkdir -p storage/logs storage/framework/{cache,data,sessions,testing,views} bootstrap/cache && chown -R www-data:www-data storage bootstrap/cache && chmod -R 775 storage bootstrap/cache'; then
    print_status "✅ UAT storage permissions fixed successfully"
else
    print_warning "⚠️  UAT storage permissions fix failed (this might cause logging issues)"
fi

# 5. Test UAT endpoints
print_status "Testing UAT endpoints..."
UAT_URL="https://uat.netaniadelaiya.com"
UAT_API_URL="https://uat-api.netaniadelaiya.com"

# Test UAT frontend
if curl -s -o /dev/null -w "%{http_code}" "$UAT_URL" | grep -q "200"; then
    print_status "✅ UAT frontend is accessible"
else
    print_error "❌ UAT frontend is not accessible"
fi

# Test UAT API
if curl -s -o /dev/null -w "%{http_code}" "$UAT_API_URL" | grep -q "200"; then
    print_status "✅ UAT API is accessible"
else
    print_error "❌ UAT API is not accessible"
fi

# 6. Verify robots.txt blocking
print_status "Verifying robots.txt blocking for UAT..."

# Test UAT frontend robots.txt
UAT_ROBOTS=$(curl -s "$UAT_URL/robots.txt")
if echo "$UAT_ROBOTS" | grep -q "Disallow: /"; then
    print_status "✅ UAT frontend robots.txt is blocking crawling"
else
    print_error "❌ UAT frontend robots.txt is not properly blocking crawling"
    echo "Current robots.txt content:"
    echo "$UAT_ROBOTS"
fi

# Test UAT API robots.txt
UAT_API_ROBOTS=$(curl -s "$UAT_API_URL/robots.txt")
if echo "$UAT_API_ROBOTS" | grep -q "Disallow: /"; then
    print_status "✅ UAT API robots.txt is blocking crawling"
else
    print_error "❌ UAT API robots.txt is not properly blocking crawling"
    echo "Current robots.txt content:"
    echo "$UAT_API_ROBOTS"
fi

# 6. Add noindex meta tags verification
print_status "Verifying noindex meta tags..."
UAT_HTML=$(curl -s "$UAT_URL")
if echo "$UAT_HTML" | grep -q "noindex"; then
    print_status "✅ UAT has noindex meta tags"
else
    print_warning "⚠️  UAT might not have noindex meta tags. Consider adding them."
fi

# 7. Test search engine blocking
print_status "Testing search engine blocking..."
print_status "Please manually verify the following:"
echo "   1. Visit https://uat.netaniadelaiya.com/robots.txt"
echo "   2. Verify it shows 'Disallow: /' for all user agents"
echo "   3. Visit https://uat-api.netaniadelaiya.com/robots.txt"
echo "   4. Verify it shows 'Disallow: /' for all user agents"

# 8. Additional security measures
print_status "Additional UAT security measures:"
echo "   - UAT should not be indexed by search engines"
echo "   - UAT should not appear in search results"
echo "   - UAT should not be cached by CDNs"
echo "   - UAT should not be accessible to the general public"

print_status "🎉 UAT deployment completed!"
print_status "UAT environment is now properly configured to prevent crawling."
print_warning "Remember: UAT is for testing only and should not be publicly accessible or indexed."
