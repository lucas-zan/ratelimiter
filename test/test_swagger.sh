#!/bin/bash

# Test Swagger functionality
echo "=== Testing Swagger functionality ==="

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

# 1. Test Swagger JSON endpoint
echo "1. Testing Swagger JSON endpoint..."
RESPONSE=$(curl -s "$BASE_URL/swagger/doc.json")
if echo "$RESPONSE" | jq -e '.swagger' > /dev/null 2>&1; then
    echo "✓ Swagger JSON endpoint is working"
    echo "  Swagger version: $(echo "$RESPONSE" | jq -r '.swagger')"
    echo "  API title: $(echo "$RESPONSE" | jq -r '.info.title')"
    echo "  API version: $(echo "$RESPONSE" | jq -r '.info.version')"
else
    echo "✗ Swagger JSON endpoint is not working"
    echo "  Response: $RESPONSE"
    exit 1
fi
echo

# 2. Test Swagger HTML endpoint
echo "2. Testing Swagger HTML endpoint..."
RESPONSE=$(curl -s "$BASE_URL/swagger/index.html")
if echo "$RESPONSE" | grep -q "swagger-ui" > /dev/null 2>&1; then
    echo "✓ Swagger HTML endpoint is working"
else
    echo "✗ Swagger HTML endpoint is not working"
    echo "  Response preview: $(echo "$RESPONSE" | head -5)"
    exit 1
fi
echo

# 3. Check API endpoints in Swagger
echo "3. Checking API endpoints in Swagger..."
SWAGGER_JSON=$(curl -s "$BASE_URL/swagger/doc.json")
ENDPOINTS=$(echo "$SWAGGER_JSON" | jq -r '.paths | keys[]' | sort)

echo "Available endpoints in Swagger:"
for endpoint in $ENDPOINTS; do
    echo "  $endpoint"
done

# Check if all expected endpoints are present
EXPECTED_ENDPOINTS=(
    "/v1/check_rate_limit"
    "/v1/update_rule"
    "/v1/stats"
    "/v1/rule_stats"
    "/health"
)

echo
echo "Checking for expected endpoints:"
for expected in "${EXPECTED_ENDPOINTS[@]}"; do
    if echo "$ENDPOINTS" | grep -q "^$expected$"; then
        echo "  ✓ $expected"
    else
        echo "  ✗ $expected (missing)"
    fi
done
echo

# 4. Test API documentation endpoint
echo "4. Testing API documentation endpoint..."
RESPONSE=$(curl -s "$BASE_URL/")
if echo "$RESPONSE" | jq -e '.endpoints' > /dev/null 2>&1; then
    echo "✓ API documentation endpoint is working"
    echo "  Service: $(echo "$RESPONSE" | jq -r '.service')"
    echo "  Version: $(echo "$RESPONSE" | jq -r '.version')"
else
    echo "✗ API documentation endpoint is not working"
    echo "  Response: $RESPONSE"
fi
echo

echo "=== Swagger test completed successfully ==="
echo "You can now access Swagger UI at: http://localhost:8080/swagger/index.html"
echo "Swagger JSON at: http://localhost:8080/swagger/doc.json" 