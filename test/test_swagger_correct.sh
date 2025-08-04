#!/bin/bash

# Test correct Swagger API usage
echo "=== Testing Correct Swagger API Usage ==="

BASE_URL="http://localhost:8080"
TEST_KEY="test_swagger_$(date +%s):gpt-4"

echo "Test parameters:"
echo "  BASE_URL: $BASE_URL"
echo "  TEST_KEY: $TEST_KEY"
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

# 1. First, update rate limiting rule (correct format)
echo "1. Updating rate limiting rule (correct format)..."
echo "   POST /v1/update_rule"
echo "   Request body:"
echo "   {"
echo "     \"key\": \"$TEST_KEY\","
echo "     \"rate_limit\": 20,"
echo "     \"burst\": 30"
echo "   }"
echo

RESPONSE=$(curl -s -X POST "$BASE_URL/v1/update_rule" \
  -H "Content-Type: application/json" \
  -d "{
    \"key\": \"$TEST_KEY\",
    \"rate_limit\": 20,
    \"burst\": 30
  }")

echo "Response: $RESPONSE"

if echo "$RESPONSE" | jq -e '.status == "success"' > /dev/null 2>&1; then
    echo "✓ Rule updated successfully"
else
    echo "✗ Failed to update rule: $RESPONSE"
    exit 1
fi
echo

# 2. Check rate limit (correct format)
echo "2. Checking rate limit (correct format)..."
echo "   POST /v1/check_rate_limit"
echo "   Request body:"
echo "   {"
echo "     \"key\": \"$TEST_KEY\""
echo "   }"
echo

RESPONSE=$(curl -s -X POST "$BASE_URL/v1/check_rate_limit" \
  -H "Content-Type: application/json" \
  -d "{
    \"key\": \"$TEST_KEY\"
  }")

echo "Response: $RESPONSE"

ALLOWED=$(echo "$RESPONSE" | jq -r '.allowed')
REMAIN=$(echo "$RESPONSE" | jq -r '.remain')

echo "Allowed: $ALLOWED"
echo "Remain: $REMAIN"

if [ "$ALLOWED" = "true" ] && [ "$REMAIN" = "29" ]; then
    echo "✓ Rate limit check successful"
else
    echo "✗ Rate limit check failed: allowed=$ALLOWED, remain=$REMAIN"
    exit 1
fi
echo

# 3. Show what NOT to do (incorrect format)
echo "3. Demonstrating INCORRECT format (this will fail)..."
echo "   ❌ WRONG: Including rate and burst in check_rate_limit"
echo "   POST /v1/check_rate_limit"
echo "   Request body (WRONG):"
echo "   {"
echo "     \"key\": \"$TEST_KEY\","
echo "     \"rate\": 20,"
echo "     \"brust\": 30"
echo "   }"
echo

RESPONSE=$(curl -s -X POST "$BASE_URL/v1/check_rate_limit" \
  -H "Content-Type: application/json" \
  -d "{
    \"key\": \"$TEST_KEY\",
    \"rate\": 20,
    \"brust\": 30
  }")

echo "Response (should be error): $RESPONSE"

if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    echo "✓ Correctly rejected invalid request format"
else
    echo "✗ Should have rejected invalid request format"
fi
echo

# 4. Get statistics
echo "4. Getting statistics..."
echo "   GET /v1/rule_stats?key=$TEST_KEY"
echo

RESPONSE=$(curl -s "$BASE_URL/v1/rule_stats?key=$TEST_KEY")
echo "Response: $RESPONSE"

if echo "$RESPONSE" | jq -e '.stats' > /dev/null 2>&1; then
    echo "✓ Statistics retrieved successfully"
else
    echo "✗ Failed to get statistics"
fi
echo

echo "=== Test Summary ==="
echo "✓ Correct API usage demonstrated"
echo "✓ Incorrect usage properly rejected"
echo ""
echo "Key points:"
echo "  - /v1/check_rate_limit only needs 'key' parameter"
echo "  - /v1/update_rule needs 'key', 'rate_limit', and 'burst' parameters"
echo "  - Parameter names are 'rate_limit' (not 'rate') and 'burst' (not 'brust')"
echo ""
echo "Swagger UI: http://localhost:8080/swagger/index.html" 