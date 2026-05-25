#!/bin/bash
# Phase 2 Cache Integration Tests
# Requires a running llama-server instance with a model loaded

SERVER_URL="${SERVER_URL:-http://localhost:8080}"
MODEL_PATH="${MODEL_PATH:-models/test-model.gguf}"

echo "=== Phase 2 Cache Integration Tests ==="
echo "Server URL: $SERVER_URL"
echo ""

# Function to make HTTP request and check response
test_endpoint() {
    local method=$1
    local endpoint=$2
    local expected_status=$3
    local description=$4
    
    echo "Test: $description"
    echo "  $method $endpoint"
    
    response=$(curl -s -w "\n%{http_code}" -X "$method" "$SERVER_URL$endpoint")
    status_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | head -n -1)
    
    if [ "$status_code" = "$expected_status" ]; then
        echo "  ✓ Status: $status_code (expected $expected_status)"
        echo "  Response: $(echo "$body" | head -c 100)..."
        return 0
    else
        echo "  ✗ Status: $status_code (expected $expected_status)"
        echo "  Response: $body"
        return 1
    fi
}

# Test 1: Health endpoint keeps the upstream response shape
echo ""
echo "--- Test 1: Health Endpoint ---"
test_endpoint GET "/health" 200 "Health check should return 200"

# Test 2: Dedicated cache stats endpoint is not registered
echo ""
echo "--- Test 2: No Dedicated Cache Stats Endpoint ---"
test_endpoint GET "/cache/stats" 404 "Cache stats endpoint should not be registered"

# Test 3: Cache behavior with actual requests
echo ""
echo "--- Test 3: Cache Save/Load Behavior ---"
echo "Sending completion request to populate cache..."

curl -s -X POST "$SERVER_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "test",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Hello, how are you?"}
    ],
    "max_tokens": 50
  }' > /dev/null

echo "  First request sent (cache miss expected)"

# Check cache metrics after first request
echo ""
echo "Cache metrics after first request:"
curl -s "$SERVER_URL/metrics" | grep 'llamacpp_cache_'

# Send similar request (should hit cache)
echo ""
echo "Sending similar request (cache hit expected)..."

curl -s -X POST "$SERVER_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "test",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Hello, how are you today?"}
    ],
    "max_tokens": 50
  }' > /dev/null

echo ""
echo "Cache metrics after second request:"
curl -s "$SERVER_URL/metrics" | grep 'llamacpp_cache_'

# Test 4: Verify cache metrics are present
echo ""
echo "--- Test 4: Cache Metrics Validation ---"
metrics=$(curl -s "$SERVER_URL/metrics")

if echo "$metrics" | grep -q 'llamacpp_cache_entries{mode="hybrid"}'; then
    echo "  ✓ Hybrid cache metrics active"
else
    echo "  ✗ Expected hybrid cache metrics"
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo "Integration tests completed."
echo "Review output above for any failures."
echo ""
echo "To run with different model:"
echo "  MODEL_PATH=path/to/model.gguf $0"
echo ""
echo "To test against different server:"
echo "  SERVER_URL=http://other-server:8080 $0"
