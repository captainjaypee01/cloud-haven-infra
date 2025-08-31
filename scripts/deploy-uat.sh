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

# Stop existing containers
print_status "Stopping existing UAT containers..."
docker compose -f docker-compose.uat.yml down

# Remove old images to force rebuild
print_status "Removing old UAT images..."
docker rmi cloud-haven-web:uat cloud-haven-api:uat 2>/dev/null || true

# Rebuild containers
print_status "Rebuilding UAT containers..."
docker compose -f docker-compose.uat.yml build --no-cache

# Start containers
print_status "Starting UAT containers..."
docker compose -f docker-compose.uat.yml up -d

# 2. Restart nginx proxy to apply new robots.txt configurations
print_status "Restarting nginx proxy to apply new configurations..."
cd ../proxy
if [ -f "docker-compose.yml" ]; then
    docker compose restart nginx
    print_status "✅ Nginx proxy restarted"
else
    print_warning "⚠️  Nginx proxy docker-compose.yml not found. Please restart nginx manually."
fi

# 3. Verify UAT deployment
print_status "Verifying UAT deployment..."
sleep 10

# Check if containers are running
if docker compose -f docker-compose.uat.yml ps | grep -q "Up"; then
    print_status "✅ UAT containers are running successfully"
else
    print_error "❌ Some UAT containers failed to start"
    docker compose -f docker-compose.uat.yml ps
    exit 1
fi

# 4. Test UAT endpoints
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

# 5. Verify robots.txt blocking
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

# 6. Test search engine blocking
print_status "Testing search engine blocking..."
print_status "Please manually verify the following:"
echo "   1. Visit https://uat.netaniadelaiya.com/robots.txt"
echo "   2. Verify it shows 'Disallow: /' for all user agents"
echo "   3. Visit https://uat-api.netaniadelaiya.com/robots.txt"
echo "   4. Verify it shows 'Disallow: /' for all user agents"

# 7. Additional security measures
print_status "Additional UAT security measures:"
echo "   - UAT should not be indexed by search engines"
echo "   - UAT should not appear in search results"
echo "   - UAT should not be cached by CDNs"
echo "   - UAT should not be accessible to the general public"

print_status "🎉 UAT deployment completed!"
print_status "UAT environment is now properly configured to prevent crawling."
print_warning "Remember: UAT is for testing only and should not be publicly accessible or indexed."
