#!/bin/bash

# Verify remain field functionality
echo "=== Verifying remain field functionality ==="

# Set test parameters
API_KEY="test_remain_verify_$(date +%s)"
MODEL="gpt-4"
KEY="$API_KEY:$MODEL"
BASE_URL="http://localhost:8080"

echo "Test parameters:"
echo "  API_KEY: $API_KEY"
echo "  MODEL: $MODEL"
echo "  KEY: $KEY"
echo "  BASE_URL: $BASE_URL"
echo

# Check if service is running
echo "Checking if service is running..."
if ! curl -s "$BASE_URL/health" > /dev/null 2>&1; then
    echo "ERROR: Service is not running. Please start the service first."
    echo "Run: ./start.sh"
    exit 1
fi
echo "✓ Service is running"
echo

# 1. Set rate limiting rule
echo "1. Setting rate limiting rule..."
RESPONSE=$(curl -s -X POST "$BASE_URL/v1/update_rule" \
  -H "Content-Type: application/json" \
  -d "{
    \"key\": \"$KEY\",
    \"rate_limit\": 10,
    \"burst\": 5
  }")

if echo "$RESPONSE" | jq -e '.status == "success"' > /dev/null 2>&1; then
    echo "✓ Rule set successfully"
else
    echo "✗ Failed to set rule: $RESPONSE"
    exit 1
fi
echo

# 2. Test first request
echo "2. Testing first request..."
RESPONSE=$(curl -s -X POST "$BASE_URL/v1/check_rate_limit" \
  -H "Content-Type: application/json" \
  -d "{
    \"key\": \"$KEY\"
  }")

echo "Response: $RESPONSE"

# Check if remain field exists
if echo "$RESPONSE" | jq -e '.remain' > /dev/null 2>&1; then
    echo "✓ remain field exists in response"
else
    echo "✗ remain field missing from response"
    exit 1
fi

ALLOWED=$(echo "$RESPONSE" | jq -r '.allowed')
REMAIN=$(echo "$RESPONSE" | jq -r '.remain')

echo "Allowed: $ALLOWED"
echo "Remain: $REMAIN"

if [ "$ALLOWED" = "true" ] && [ "$REMAIN" = "4" ]; then
    echo "✓ First request correct: allowed=true, remain=4"
else
    echo "✗ First request incorrect: allowed=$ALLOWED, remain=$REMAIN"
    exit 1
fi
echo

# 3. Test second request
echo "3. Testing second request..."
RESPONSE=$(curl -s -X POST "$BASE_URL/v1/check_rate_limit" \
  -H "Content-Type: application/json" \
  -d "{
    \"key\": \"$KEY\"
  }")

echo "Response: $RESPONSE"

ALLOWED=$(echo "$RESPONSE" | jq -r '.allowed')
REMAIN=$(echo "$RESPONSE" | jq -r '.remain')

echo "Allowed: $ALLOWED"
echo "Remain: $REMAIN"

if [ "$ALLOWED" = "true" ] && [ "$REMAIN" = "3" ]; then
    echo "✓ Second request correct: allowed=true, remain=3"
else
    echo "✗ Second request incorrect: allowed=$ALLOWED, remain=$REMAIN"
    exit 1
fi
echo

echo "=== Verification completed successfully ==="
echo "The remain field is working correctly!" 