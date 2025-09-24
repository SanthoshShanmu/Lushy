#!/bin/bash

echo "Testing Lushy Backend API Endpoints..."

# Test if server is running
echo "1. Testing basic connectivity..."
if curl -s -f http://localhost:5001/health > /dev/null 2>&1; then
    echo "✅ Server is running"
else
    echo "❌ Server is not running or not accessible"
    exit 1
fi

# Test usage-entries endpoint
echo "2. Testing usage-entries endpoint..."
USAGE_RESPONSE=$(curl -s -w "%{http_code}" -X POST \
    "http://localhost:5001/api/users/test-user-id/products/test-product-id/usage-entries" \
    -H "Content-Type: application/json" \
    -d '{"usageType": "check_in", "usageAmount": 1}' \
    2>/dev/null)

if [[ "$USAGE_RESPONSE" == *"201"* ]]; then
    echo "✅ Usage entries endpoint working"
elif [[ "$USAGE_RESPONSE" == *"404"* ]]; then
    echo "❌ Usage entries endpoint returns 404 - route not found"
elif [[ "$USAGE_RESPONSE" == *"401"* ]]; then
    echo "⚠️  Usage entries endpoint requires authentication"
else
    echo "❌ Usage entries endpoint failed with response: $USAGE_RESPONSE"
fi

# Test journey-events endpoint
echo "3. Testing journey-events endpoint..."
JOURNEY_RESPONSE=$(curl -s -w "%{http_code}" -X POST \
    "http://localhost:5001/api/users/test-user-id/products/test-product-id/journey-events" \
    -H "Content-Type: application/json" \
    -d '{"eventType": "usage", "text": "Test event"}' \
    2>/dev/null)

if [[ "$JOURNEY_RESPONSE" == *"201"* ]]; then
    echo "✅ Journey events endpoint working"
elif [[ "$JOURNEY_RESPONSE" == *"404"* ]]; then
    echo "❌ Journey events endpoint returns 404 - route not found"
elif [[ "$JOURNEY_RESPONSE" == *"401"* ]]; then
    echo "⚠️  Journey events endpoint requires authentication"
else
    echo "❌ Journey events endpoint failed with response: $JOURNEY_RESPONSE"
fi

echo "Testing complete!"