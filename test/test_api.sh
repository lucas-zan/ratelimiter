#!/bin/bash

# API test script
BASE_URL="http://localhost:8080"

echo "=== Rate Limiter Service API Test ==="

# 1. Health check
echo "1. Health check"
curl -s "$BASE_URL/health" | jq .

# 2. Update rate limiting rule
echo -e "\n2. Update rate limiting rule"
curl -s -X POST "$BASE_URL/v1/update_rule" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "test_key_1:gpt-4",
    "rate_limit": 5,
    "burst": 10
  }' | jq .

# 3. Check rate limit status
echo -e "\n3. Check rate limit status"
for i in {1..15}; do
  echo "Request $i:"
  RESPONSE=$(curl -s -X POST "$BASE_URL/v1/check_rate_limit" \
    -H "Content-Type: application/json" \
    -d '{
      "key": "test_key_1:gpt-4"
    }')
  echo "$RESPONSE" | jq .
  
  # Extract and display remain value
  REMAIN=$(echo "$RESPONSE" | jq -r '.remain')
  ALLOWED=$(echo "$RESPONSE" | jq -r '.allowed')
  echo "  Allowed: $ALLOWED, Remaining tokens: $REMAIN"
  
  sleep 0.2
done

# 4. Get monitoring statistics
echo -e "\n4. Get monitoring statistics"
curl -s "$BASE_URL/v1/stats" | jq .

# 5. Get specific rule statistics
echo -e "\n5. Get specific rule statistics"
curl -s "$BASE_URL/v1/rule_stats?key=test_key_1:gpt-4" | jq .

echo -e "\n=== Test completed ===" 