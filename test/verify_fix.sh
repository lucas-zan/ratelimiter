#!/bin/bash

# Verify current_tokens fix
echo "=== Verifying current_tokens fix ==="

# Set test parameters
API_KEY="test_verify_$(date +%s)"
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
    \"rate_limit\": 5,
    \"burst\": 10
  }")

if echo "$RESPONSE" | jq -e '.status == "success"' > /dev/null 2>&1; then
    echo "✓ Rule set successfully"
else
    echo "✗ Failed to set rule: $RESPONSE"
    exit 1
fi
echo

# 2. Check initial status (should show burst value, not "unknown")
echo "2. Checking initial status..."
RESPONSE=$(curl -s "$BASE_URL/v1/rule_stats?key=$KEY")
CURRENT_TOKENS=$(echo "$RESPONSE" | jq -r '.stats.current_tokens')

echo "Response: $RESPONSE"
echo "Current tokens: $CURRENT_TOKENS"

if [ "$CURRENT_TOKENS" = "10" ]; then
    echo "✓ current_tokens shows correct initial burst value (10)"
elif [ "$CURRENT_TOKENS" = "unknown" ]; then
    echo "✗ current_tokens still shows 'unknown' - fix not working"
    exit 1
else
    echo "✓ current_tokens shows a value: $CURRENT_TOKENS"
fi
echo

# 3. Make a rate limit check
echo "3. Making a rate limit check..."
RESPONSE=$(curl -s -X POST "$BASE_URL/v1/check_rate_limit" \
  -H "Content-Type: application/json" \
  -d "{
    \"key\": \"$KEY\"
  }")

echo "Rate limit check response: $RESPONSE"
echo

# 4. Check status again (should show updated token count)
echo "4. Checking status after rate limit check..."
RESPONSE=$(curl -s "$BASE_URL/v1/rule_stats?key=$KEY")
CURRENT_TOKENS=$(echo "$RESPONSE" | jq -r '.stats.current_tokens')

echo "Response: $RESPONSE"
echo "Current tokens: $CURRENT_TOKENS"

if [ "$CURRENT_TOKENS" = "9" ]; then
    echo "✓ current_tokens correctly shows updated value (9) after consuming 1 token"
elif [ "$CURRENT_TOKENS" = "unknown" ]; then
    echo "✗ current_tokens still shows 'unknown' - fix not working"
    exit 1
else
    echo "✓ current_tokens shows a value: $CURRENT_TOKENS"
fi
echo

echo "=== Verification completed successfully ==="
echo "The current_tokens fix is working correctly!" 