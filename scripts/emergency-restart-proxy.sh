#!/bin/bash

# Emergency script to restart nginx proxy after configuration fix
# This should restore UAT and PROD sites

set -e

echo "🚨 Emergency nginx proxy restart..."
echo "📍 Current directory: $(pwd)"

# Colors for output (following existing pattern)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output (following existing pattern)
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
if [ ! -f "proxy/docker-compose.proxy.yml" ]; then
    print_error "Not in the correct directory. Please run from infra/ directory"
    exit 1
fi

# Navigate to proxy directory (following existing pattern)
print_status "Navigating to proxy directory..."
cd proxy

# Test nginx configuration first
print_status "Testing nginx configuration..."
docker compose -f docker-compose.proxy.yml exec nginx-proxy nginx -t

if [ $? -ne 0 ]; then
    print_error "Nginx configuration test failed!"
    print_error "Please check the configuration file for syntax errors."
    exit 1
fi

print_status "✅ Nginx configuration test passed!"

# Restart the proxy container (following existing pattern)
print_status "Restarting nginx proxy container..."
docker compose -f docker-compose.proxy.yml restart nginx-proxy

if [ $? -eq 0 ]; then
    print_status "✅ Nginx proxy restarted successfully!"
    print_status "🌐 Your sites should be back online now:"
    echo "   - Production: https://www.netaniadelaiya.com"
    echo "   - UAT: https://uat.netaniadelaiya.com"
    echo "   - API: https://api.netaniadelaiya.com"
    
    # Wait a moment for services to be ready
    print_status "Waiting for services to be ready..."
    sleep 5
    
    # Test endpoints (following existing pattern)
    print_status "Testing endpoints..."
    
    # Test production frontend
    if curl -s -o /dev/null -w "%{http_code}" "https://www.netaniadelaiya.com" | grep -q "200"; then
        print_status "✅ Production frontend is accessible"
    else
        print_warning "⚠️  Production frontend might not be accessible yet"
    fi
    
    # Test production API
    if curl -s -o /dev/null -w "%{http_code}" "https://api.netaniadelaiya.com" | grep -q "200"; then
        print_status "✅ Production API is accessible"
    else
        print_warning "⚠️  Production API might not be accessible yet"
    fi
    
    print_status "🎉 Emergency restart completed!"
else
    print_error "Failed to restart nginx proxy!"
    print_error "Please check the logs: docker compose -f docker-compose.proxy.yml logs nginx-proxy"
    exit 1
fi
