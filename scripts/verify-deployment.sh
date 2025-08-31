#!/bin/bash

# Verification Script for Netania De Laiya Deployment
# This script verifies all environments and their crawling status

set -e

echo "🔍 Verifying Netania De Laiya Deployment Status"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

# Test URLs
PROD_FRONTEND="https://www.netaniadelaiya.com"
PROD_API="https://api.netaniadelaiya.com"
UAT_FRONTEND="https://uat.netaniadelaiya.com"
UAT_API="https://uat-api.netaniadelaiya.com"

print_header "=== ENVIRONMENT STATUS ==="

# 1. Check if all environments are accessible
print_status "Checking environment accessibility..."

# Production Frontend
if curl -s -o /dev/null -w "%{http_code}" "$PROD_FRONTEND" | grep -q "200"; then
    print_status "✅ Production Frontend is accessible"
else
    print_error "❌ Production Frontend is not accessible"
fi

# Production API
if curl -s -o /dev/null -w "%{http_code}" "$PROD_API" | grep -q "200"; then
    print_status "✅ Production API is accessible"
else
    print_error "❌ Production API is not accessible"
fi

# UAT Frontend
if curl -s -o /dev/null -w "%{http_code}" "$UAT_FRONTEND" | grep -q "200"; then
    print_status "✅ UAT Frontend is accessible"
else
    print_error "❌ UAT Frontend is not accessible"
fi

# UAT API
if curl -s -o /dev/null -w "%{http_code}" "$UAT_API" | grep -q "200"; then
    print_status "✅ UAT API is accessible"
else
    print_error "❌ UAT API is not accessible"
fi

print_header "=== CRAWLING PREVENTION VERIFICATION ==="

# 2. Check robots.txt files
print_status "Checking robots.txt configurations..."

# Production Frontend robots.txt (should allow crawling)
PROD_FRONTEND_ROBOTS=$(curl -s "$PROD_FRONTEND/robots.txt")
if echo "$PROD_FRONTEND_ROBOTS" | grep -q "Allow: /"; then
    print_status "✅ Production Frontend robots.txt allows crawling"
else
    print_error "❌ Production Frontend robots.txt does not allow crawling"
    echo "Current content:"
    echo "$PROD_FRONTEND_ROBOTS"
fi

# Production API robots.txt (should block crawling)
PROD_API_ROBOTS=$(curl -s "$PROD_API/robots.txt")
if echo "$PROD_API_ROBOTS" | grep -q "Disallow: /"; then
    print_status "✅ Production API robots.txt blocks crawling"
else
    print_error "❌ Production API robots.txt does not block crawling"
    echo "Current content:"
    echo "$PROD_API_ROBOTS"
fi

# UAT Frontend robots.txt (should block crawling)
UAT_FRONTEND_ROBOTS=$(curl -s "$UAT_FRONTEND/robots.txt")
if echo "$UAT_FRONTEND_ROBOTS" | grep -q "Disallow: /"; then
    print_status "✅ UAT Frontend robots.txt blocks crawling"
else
    print_error "❌ UAT Frontend robots.txt does not block crawling"
    echo "Current content:"
    echo "$UAT_FRONTEND_ROBOTS"
fi

# UAT API robots.txt (should block crawling)
UAT_API_ROBOTS=$(curl -s "$UAT_API/robots.txt")
if echo "$UAT_API_ROBOTS" | grep -q "Disallow: /"; then
    print_status "✅ UAT API robots.txt blocks crawling"
else
    print_error "❌ UAT API robots.txt does not block crawling"
    echo "Current content:"
    echo "$UAT_API_ROBOTS"
fi

print_header "=== BRANDING VERIFICATION ==="

# 3. Check branding on production frontend
print_status "Checking production branding..."
PROD_HTML=$(curl -s "$PROD_FRONTEND")

if echo "$PROD_HTML" | grep -q "Netania De Laiya"; then
    print_status "✅ Production shows 'Netania De Laiya' branding"
else
    print_error "❌ Production does not show 'Netania De Laiya' branding"
fi

if echo "$PROD_HTML" | grep -q "CloudHaven"; then
    print_error "❌ Production still shows 'CloudHaven' branding"
else
    print_status "✅ Production does not show 'CloudHaven' branding"
fi

print_header "=== DOCKER CONTAINER STATUS ==="

# 4. Check Docker container status
print_status "Checking Docker container status..."

# Check if we're in the right directory
if [ -f "prod/docker-compose.yml" ]; then
    cd prod
    print_status "Production containers:"
    docker-compose ps
    
    cd ../uat
    print_status "UAT containers:"
    docker-compose -f docker-compose.uat.yml ps
else
    print_warning "⚠️  Please run this script from the infra directory"
fi

print_header "=== SUMMARY ==="

print_status "Deployment verification completed!"
print_status "Expected behavior:"
echo "   ✅ Production Frontend (www.netaniadelaiya.com) - Should be crawled"
echo "   ❌ Production API (api.netaniadelaiya.com) - Should NOT be crawled"
echo "   ❌ UAT Frontend (uat.netaniadelaiya.com) - Should NOT be crawled"
echo "   ❌ UAT API (uat-api.netaniadelaiya.com) - Should NOT be crawled"

print_warning "If any issues are found:"
echo "   1. Run ./scripts/quick-deploy-prod.sh to fix production"
echo "   2. Run ./scripts/deploy-uat.sh to fix UAT"
echo "   3. Check nginx configuration if robots.txt issues persist"
