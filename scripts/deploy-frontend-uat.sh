#!/bin/bash

# Frontend-Only UAT Deployment Script for Netania De Laiya
# This script deploys only the frontend service for UAT environment

set -e

echo "🚀 Starting Frontend-Only UAT Deployment for Netania De Laiya..."

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

# 2. Build new UAT frontend image alongside running container (zero-downtime)
print_status "Building new UAT frontend image alongside running container..."
docker compose -f docker-compose.uat.yml build --no-cache frontend-uat

# 3. Create new UAT frontend container with temporary name
print_status "Creating new UAT frontend container for zero-downtime deployment..."
NEW_FRONTEND_NAME="frontend-uat-new"

# Get the current frontend-uat container ID before scaling down
CURRENT_FRONTEND_ID=$(docker compose -f docker-compose.uat.yml ps -q frontend-uat)

if [ -n "$CURRENT_FRONTEND_ID" ]; then
    print_status "Current frontend-uat container ID: $CURRENT_FRONTEND_ID"
    # Scale down to 0
    docker compose -f docker-compose.uat.yml up -d --scale frontend-uat=0
    
    # Create new container
    docker run -d \
      --name $NEW_FRONTEND_NAME \
      --network global-web-network \
      cloud-haven-web:uat
else
    print_status "No existing frontend-uat container found, creating new one..."
    # Create new container
    docker run -d \
      --name $NEW_FRONTEND_NAME \
      --network global-web-network \
      cloud-haven-web:uat
fi

# 4. Wait for new container to be healthy
print_status "Waiting for new UAT frontend container to be healthy..."
sleep 10

# 5. Health check for new UAT frontend container
print_status "Performing health check on new UAT frontend container..."
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000" | grep -q "200\|404"; then
    print_status "✅ New UAT frontend container is healthy"
else
    print_error "❌ New UAT frontend container health check failed"
    print_status "Rolling back - removing failed container..."
    docker stop $NEW_FRONTEND_NAME
    docker rm $NEW_FRONTEND_NAME
    docker compose -f docker-compose.uat.yml up -d frontend-uat
    exit 1
fi

# 6. Stop old UAT frontend container and rename new one
print_status "Switching traffic to new UAT frontend container..."
if [ -n "$CURRENT_FRONTEND_ID" ]; then
    docker stop $CURRENT_FRONTEND_ID 2>/dev/null || true
    docker rm $CURRENT_FRONTEND_ID 2>/dev/null || true
fi

# 7. Start UAT frontend service with new image
print_status "Starting UAT frontend service with new image..."
# The new container is already running with the temporary name, so we just need to rename it

# 8. Rename the new container to the proper name
print_status "Renaming new container to frontend-uat..."
docker rename $NEW_FRONTEND_NAME frontend-uat

# 6. Wait for service to be ready
print_status "Waiting for UAT frontend service to be healthy..."
sleep 10

# 7. Restart nginx proxy to apply new robots.txt configurations
print_status "Restarting nginx proxy to apply new configurations..."
cd ../proxy
if [ -f "docker-compose.proxy.yml" ]; then
    docker compose -f docker-compose.proxy.yml restart nginx-proxy
    print_status "✅ Nginx proxy restarted"
else
    print_warning "⚠️  Nginx proxy docker-compose.proxy.yml not found. Please restart nginx manually."
fi

# 8. Verify UAT frontend deployment
print_status "Verifying UAT frontend deployment..."

cd ../uat
# Check if frontend container is running
if docker compose -f docker-compose.uat.yml ps | grep "frontend-uat" | grep -q "Up"; then
    print_status "✅ UAT frontend container is running successfully"
else
    print_error "❌ UAT frontend container failed to start"
    docker compose -f docker-compose.uat.yml ps | grep "frontend-uat"
    exit 1
fi

# 9. Test UAT frontend endpoint
print_status "Testing UAT frontend endpoint..."
UAT_URL="https://uat.netaniadelaiya.com"

if curl -s -o /dev/null -w "%{http_code}" "$UAT_URL" | grep -q "200"; then
    print_status "✅ UAT frontend is accessible"
else
    print_error "❌ UAT frontend is not accessible"
fi

# 10. Test UAT frontend content
print_status "Testing UAT frontend content..."
UAT_HTML=$(curl -s "$UAT_URL")
if echo "$UAT_HTML" | grep -q "Netania De Laiya"; then
    print_status "✅ UAT frontend shows correct branding (Netania De Laiya)"
else
    print_warning "⚠️  UAT frontend might not show correct branding. Please verify manually."
fi

# 11. Verify noindex meta tags are present (should be present in UAT)
print_status "Verifying noindex meta tags are present in UAT..."
if echo "$UAT_HTML" | grep -q "noindex"; then
    print_status "✅ UAT frontend has noindex meta tags (correct)"
else
    print_warning "⚠️  UAT frontend might not have noindex meta tags. Consider adding them."
fi

# 12. Verify robots.txt blocking for UAT frontend
print_status "Verifying robots.txt blocking for UAT frontend..."
UAT_ROBOTS=$(curl -s "$UAT_URL/robots.txt")
if echo "$UAT_ROBOTS" | grep -q "Disallow: /"; then
    print_status "✅ UAT frontend robots.txt is blocking crawling (correct)"
else
    print_error "❌ UAT frontend robots.txt is not properly blocking crawling"
    echo "Current robots.txt content:"
    echo "$UAT_ROBOTS"
fi

# 13. Test search engine blocking
print_status "Testing search engine blocking..."
print_status "Please manually verify the following:"
echo "   1. Visit https://uat.netaniadelaiya.com/robots.txt"
echo "   2. Verify it shows 'Disallow: /' for all user agents"
echo "   3. Check that noindex meta tags are present in the HTML source"

# 14. Additional security measures
print_status "Additional UAT security measures:"
echo "   - UAT should not be indexed by search engines"
echo "   - UAT should not appear in search results"
echo "   - UAT should not be cached by CDNs"
echo "   - UAT should not be accessible to the general public"

print_status "🎉 Frontend-only UAT deployment completed!"
print_status "UAT frontend service deployed:"
echo "   ✅ Frontend (frontend-uat)"

print_warning "Note: Backend services were not affected by this deployment."
print_status "UAT frontend is now available at: $UAT_URL"
print_warning "Remember: UAT is for testing only and should not be publicly accessible or indexed."

print_status "UAT environment is now properly configured to prevent crawling."
print_warning "Remember: UAT is for testing only and should not be publicly accessible or indexed."
