#!/bin/bash

# Emergency script to restart nginx proxy after configuration fix
# This should restore UAT and PROD sites

echo "🚨 Emergency nginx proxy restart..."
echo "📍 Current directory: $(pwd)"

# Check if we're in the right directory
if [ ! -f "proxy/docker-compose.proxy.yml" ]; then
    echo "❌ Error: Not in the correct directory. Please run from infra/ directory"
    exit 1
fi

# Test nginx configuration first
echo "🔍 Testing nginx configuration..."
docker-compose -f proxy/docker-compose.proxy.yml exec proxy nginx -t

if [ $? -ne 0 ]; then
    echo "❌ Nginx configuration test failed!"
    echo "Please check the configuration file for syntax errors."
    exit 1
fi

echo "✅ Nginx configuration test passed!"

# Restart the proxy container
echo "🔄 Restarting nginx proxy container..."
docker-compose -f proxy/docker-compose.proxy.yml restart proxy

if [ $? -eq 0 ]; then
    echo "✅ Nginx proxy restarted successfully!"
    echo "🌐 Your sites should be back online now:"
    echo "   - Production: https://www.netaniadelaiya.com"
    echo "   - UAT: https://uat.netaniadelaiya.com"
    echo "   - API: https://api.netaniadelaiya.com"
else
    echo "❌ Failed to restart nginx proxy!"
    echo "Please check the logs: docker-compose -f proxy/docker-compose.proxy.yml logs proxy"
fi
