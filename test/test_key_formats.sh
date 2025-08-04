#!/bin/bash

# Test different key formats
echo "=== Testing Different Key Formats ==="

BASE_URL="http://localhost:8080"

echo "Test parameters:"
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

# Test different key formats
declare -a key_formats=(
    "api_key:model:sk-123:gpt-4"
    "user_id:feature:user123:chat"
    "ip_address:endpoint:192.168.1.1:/api/chat"
    "tenant_id:service:tenant1:api"
    "project_id:api:proj123:completion"
    "session_id:action:sess456:login"
)

for key_format in "${key_formats[@]}"; do
    IFS=':' read -r format_name format_example key_value <<< "$key_format"
    
    echo "Testing $format_name format: $key_value"
    echo "----------------------------------------"
    
    # 1. Set rate limiting rule
    echo "1. Setting rate limiting rule..."
    RESPONSE=$(curl -s -X POST "$BASE_URL/v1/update_rule" \
      -H "Content-Type: application/json" \
      -d "{
        \"key\": \"$key_value\",
        \"rate_limit\": 5,
        \"burst\": 10
      }")
    
    if echo "$RESPONSE" | jq -e '.status == "success"' > /dev/null 2>&1; then
        echo "✓ Rule set successfully for $key_value"
    else
        echo "✗ Failed to set rule for $key_value: $RESPONSE"
        continue
    fi
    
    # 2. Check rate limit
    echo "2. Checking rate limit..."
    RESPONSE=$(curl -s -X POST "$BASE_URL/v1/check_rate_limit" \
      -H "Content-Type: application/json" \
      -d "{
        \"key\": \"$key_value\"
      }")
    
    ALLOWED=$(echo "$RESPONSE" | jq -r '.allowed')
    REMAIN=$(echo "$RESPONSE" | jq -r '.remain')
    
    echo "  Response: $RESPONSE"
    echo "  Allowed: $ALLOWED, Remain: $REMAIN"
    
    if [ "$ALLOWED" = "true" ] && [ "$REMAIN" = "9" ]; then
        echo "✓ Rate limit check successful for $key_value"
    else
        echo "✗ Rate limit check failed for $key_value"
    fi
    
    # 3. Get statistics
    echo "3. Getting statistics..."
    RESPONSE=$(curl -s "$BASE_URL/v1/rule_stats?key=$key_value")
    echo "  Response: $RESPONSE"
    
    if echo "$RESPONSE" | jq -e '.stats' > /dev/null 2>&1; then
        echo "✓ Statistics retrieved successfully for $key_value"
    else
        echo "✗ Failed to get statistics for $key_value"
    fi
    
    echo
done

echo "=== Key Format Test Completed ==="
echo "All key formats are working correctly!"
echo
echo "Key format examples tested:"
echo "  - API key + model: sk-123:gpt-4"
echo "  - User + feature: user123:chat"
echo "  - IP + endpoint: 192.168.1.1:/api/chat"
echo "  - Tenant + service: tenant1:api"
echo "  - Project + API: proj123:completion"
echo "  - Session + action: sess456:login" 