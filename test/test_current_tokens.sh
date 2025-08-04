#!/bin/bash

# Test current_tokens fix
echo "=== Testing current_tokens fix ==="

# Set test parameters
API_KEY="test_api_key_$(date +%s)"
MODEL="gpt-4"
KEY="$API_KEY:$MODEL"
BASE_URL="http://localhost:8080"

echo "Test parameters:"
echo "  API_KEY: $API_KEY"
echo "  MODEL: $MODEL"
echo "  KEY: $KEY"
echo "  BASE_URL: $BASE_URL"
echo

# 1. Set rate limiting rule
echo "1. Setting rate limiting rule..."
curl -s -X POST "$BASE_URL/v1/update_rule" \
  -H "Content-Type: application/json" \
  -d "{
    \"key\": \"$KEY\",
    \"rate_limit\": 10,
    \"burst\": 50
  }" | jq .
echo

# 2. Check initial status
echo "2. Checking initial status..."
curl -s "$BASE_URL/v1/rule_stats?key=$KEY" | jq .
echo

# 3. Perform several rate limit checks
echo "3. Performing several rate limit checks..."
for i in {1..5}; do
  echo "  Check $i:"
  curl -s -X POST "$BASE_URL/v1/check_rate_limit" \
    -H "Content-Type: application/json" \
    -d "{
      \"key\": \"$KEY\"
    }" | jq .
  echo
done

# 4. Check status again
echo "4. Checking status again..."
curl -s "$BASE_URL/v1/rule_stats?key=$KEY" | jq .
echo

echo "=== Test completed ==="
echo "If current_tokens shows a specific number instead of 'unknown', the fix is successful!" 