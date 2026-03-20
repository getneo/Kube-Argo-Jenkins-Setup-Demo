#!/bin/bash

# Demo Application Test Script
# Usage: ./test-demo-app.sh [BASE_URL]
# Example: ./test-demo-app.sh http://localhost:8080

set -e

BASE_URL="${1:-http://localhost:8080}"
FAILED_TESTS=0
PASSED_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_test() {
    echo -e "${YELLOW}Test $1: $2${NC}"
}

print_success() {
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED_TESTS++))
}

print_failure() {
    echo -e "${RED}✗ FAILED: $1${NC}"
    ((FAILED_TESTS++))
}

# Function to test endpoint
test_endpoint() {
    local test_num=$1
    local test_name=$2
    local method=$3
    local endpoint=$4
    local data=$5
    local expected_status=${6:-200}

    print_test "$test_num" "$test_name"

    if [ -z "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$endpoint")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" -eq "$expected_status" ]; then
        echo "$body" | jq . 2>/dev/null || echo "$body"
        print_success
    else
        print_failure "Expected status $expected_status, got $http_code"
        echo "$body"
    fi

    echo ""
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq is not installed. JSON output will not be formatted.${NC}"
    echo -e "${YELLOW}Install with: brew install jq (macOS) or apt-get install jq (Linux)${NC}\n"
fi

# Check if server is reachable
print_header "Checking Server Availability"
echo "Testing connection to: $BASE_URL"

if curl -s --connect-timeout 5 "$BASE_URL/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Server is reachable${NC}\n"
else
    echo -e "${RED}✗ Cannot connect to server at $BASE_URL${NC}"
    echo -e "${RED}Please ensure the application is running.${NC}\n"
    exit 1
fi

# Run tests
print_header "Running API Tests"

# Test 1: Home endpoint
test_endpoint "1" "Home Endpoint (GET /)" "GET" "/"

# Test 2: Health endpoint
test_endpoint "2" "Health Endpoint (GET /health)" "GET" "/health"

# Test 3: Liveness probe
test_endpoint "3" "Liveness Probe (GET /health/live)" "GET" "/health/live"

# Test 4: Readiness probe
test_endpoint "4" "Readiness Probe (GET /health/ready)" "GET" "/health/ready"

# Test 5: Info endpoint
test_endpoint "5" "Info Endpoint (GET /api/info)" "GET" "/api/info"

# Test 6: Version endpoint
test_endpoint "6" "Version Endpoint (GET /api/version)" "GET" "/api/version"

# Test 7: Echo endpoint with valid JSON
test_endpoint "7" "Echo Endpoint (POST /api/echo)" "POST" "/api/echo" \
    '{"message":"Test message from script"}'

# Test 8: Echo endpoint with empty message
test_endpoint "8" "Echo Endpoint - Empty Message" "POST" "/api/echo" \
    '{"message":""}' 400

# Test 9: Echo endpoint with invalid JSON
print_test "9" "Echo Endpoint - Invalid JSON"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/echo" \
    -H "Content-Type: application/json" \
    -d 'invalid json')
http_code=$(echo "$response" | tail -n1)
if [ "$http_code" -eq 400 ]; then
    print_success
else
    print_failure "Expected status 400, got $http_code"
fi
echo ""

# Test 10: Metrics endpoint
print_test "10" "Metrics Endpoint (GET /metrics)"
metrics=$(curl -s "$BASE_URL/metrics")
if echo "$metrics" | grep -q "go_goroutines"; then
    echo "$metrics" | head -20
    echo "... (truncated)"
    print_success
else
    print_failure "Metrics endpoint did not return expected Prometheus metrics"
fi
echo ""

# Test 11: 404 Not Found
test_endpoint "11" "404 Not Found (GET /nonexistent)" "GET" "/nonexistent" "" 404

# Test 12: Request ID header
print_test "12" "Request ID Header"
request_id=$(curl -s -I "$BASE_URL/" | grep -i "X-Request-ID" | cut -d' ' -f2 | tr -d '\r')
if [ -n "$request_id" ]; then
    echo "Request ID: $request_id"
    print_success
else
    print_failure "X-Request-ID header not found"
fi
echo ""

# Test 13: CORS headers
print_test "13" "CORS Headers"
cors_header=$(curl -s -I "$BASE_URL/" | grep -i "Access-Control-Allow-Origin" | cut -d' ' -f2 | tr -d '\r')
if [ "$cors_header" = "*" ]; then
    echo "CORS header: $cors_header"
    print_success
else
    print_failure "CORS header not found or incorrect"
fi
echo ""

# Performance test (optional)
print_header "Performance Test (Optional)"
echo "Running 100 requests to test response time..."

if command -v ab &> /dev/null; then
    ab -n 100 -c 10 -q "$BASE_URL/" 2>&1 | grep -E "Requests per second|Time per request"
    echo ""
elif command -v hey &> /dev/null; then
    hey -n 100 -c 10 -q "$BASE_URL/" 2>&1 | grep -E "Requests/sec|Average"
    echo ""
else
    echo -e "${YELLOW}Performance testing tools not found.${NC}"
    echo -e "${YELLOW}Install 'ab' (apache-bench) or 'hey' for performance testing.${NC}"
    echo -e "${YELLOW}  macOS: brew install hey${NC}"
    echo -e "${YELLOW}  Linux: apt-get install apache2-utils${NC}\n"
fi

# Summary
print_header "Test Summary"
total_tests=$((PASSED_TESTS + FAILED_TESTS))
echo -e "Total Tests: $total_tests"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}\n"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}\n"
    exit 0
else
    echo -e "${RED}Some tests failed. Please check the output above.${NC}\n"
    exit 1
fi

# Made with Bob
