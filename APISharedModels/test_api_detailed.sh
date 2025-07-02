#!/bin/bash

# ReuseBackup Server API Detailed Test Script
# シミュレータでReuseBackupServerアプリを起動してからこのスクリプトを実行してください

set +e  # Continue on errors for testing error cases

BASE_URL="http://localhost:8080"

echo "=== ReuseBackup Server API Detailed Test ==="
echo "Testing API at: $BASE_URL"
echo

# Helper function to check if jq is available
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo "Warning: jq is not installed. Output will not be formatted."
        echo "Install jq with: brew install jq"
        return 1
    fi
    return 0
}

# Helper function to format JSON output
format_json() {
    if check_jq; then
        jq '.'
    else
        cat
    fi
}

# Helper function to test HTTP status
test_status() {
    local expected_status=$1
    local actual_status=$2
    local test_name=$3
    
    if [ "$actual_status" = "$expected_status" ]; then
        echo "✅ $test_name: Expected $expected_status, got $actual_status"
        return 0
    else
        echo "❌ $test_name: Expected $expected_status, got $actual_status"
        return 1
    fi
}

pass_count=0
fail_count=0

# Function to increment counters
pass_test() { ((pass_count++)); }
fail_test() { ((fail_count++)); }

echo "=== POSITIVE TEST CASES ==="
echo

# Test 1: Server Status Check
echo "1. Server Status Check:"
echo "GET $BASE_URL/api/status"
echo "---"
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/status" -H "Accept: application/json")
body=$(echo "$response" | head -n -1)
status_code=$(echo "$response" | tail -n 1)

echo "$body" | format_json
if test_status "200" "$status_code" "Status endpoint"; then
    pass_test
else
    fail_test
fi
echo

# Test 2: Valid Message Send
echo "2. Valid Message Send:"
current_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "POST $BASE_URL/api/message"
echo "---"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/message" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "{
        \"message\": \"Valid test message\",
        \"timestamp\": \"$current_timestamp\"
    }")
body=$(echo "$response" | head -n -1)
status_code=$(echo "$response" | tail -n 1)

echo "$body" | format_json
if test_status "200" "$status_code" "Valid message"; then
    pass_test
else
    fail_test
fi
echo

# Test 3: Japanese Message
echo "3. Japanese Message Send:"
echo "POST $BASE_URL/api/message"
echo "---"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/message" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "{
        \"message\": \"こんにちは、日本語メッセージです\",
        \"timestamp\": \"$current_timestamp\"
    }")
body=$(echo "$response" | head -n -1)
status_code=$(echo "$response" | tail -n 1)

echo "$body" | format_json
if test_status "200" "$status_code" "Japanese message"; then
    pass_test
else
    fail_test
fi
echo

echo "=== NEGATIVE TEST CASES ==="
echo

# Test 4: Invalid JSON
echo "4. Invalid JSON Format:"
echo "POST $BASE_URL/api/message (Invalid JSON)"
echo "---"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/message" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d '{
        "message": "Invalid JSON"
        "timestamp": "'$current_timestamp'"
    }')
body=$(echo "$response" | head -n -1)
status_code=$(echo "$response" | tail -n 1)

echo "$body" | format_json
if test_status "400" "$status_code" "Invalid JSON"; then
    pass_test
else
    fail_test
fi
echo

# Test 5: Missing Required Field (message)
echo "5. Missing Required Field:"
echo "POST $BASE_URL/api/message (Missing message field)"
echo "---"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/message" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "{
        \"timestamp\": \"$current_timestamp\"
    }")
body=$(echo "$response" | head -n -1)
status_code=$(echo "$response" | tail -n 1)

echo "$body" | format_json
if test_status "400" "$status_code" "Missing message field"; then
    pass_test
else
    fail_test
fi
echo

# Test 6: Missing Required Field (timestamp)
echo "6. Missing Timestamp Field:"
echo "POST $BASE_URL/api/message (Missing timestamp field)"
echo "---"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/message" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d '{
        "message": "Missing timestamp test"
    }')
body=$(echo "$response" | head -n -1)
status_code=$(echo "$response" | tail -n 1)

echo "$body" | format_json
if test_status "400" "$status_code" "Missing timestamp field"; then
    pass_test
else
    fail_test
fi
echo

# Test 7: Invalid Timestamp Format
echo "7. Invalid Timestamp Format:"
echo "POST $BASE_URL/api/message (Invalid ISO8601 format)"
echo "---"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/message" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d '{
        "message": "Invalid timestamp test",
        "timestamp": "2025/07/02 14:55:00"
    }')
body=$(echo "$response" | head -n -1)
status_code=$(echo "$response" | tail -n 1)

echo "$body" | format_json
if test_status "400" "$status_code" "Invalid timestamp format"; then
    pass_test
else
    fail_test
fi
echo

# Test 8: Method Not Allowed - GET
echo "8. Method Not Allowed (GET /api/message):"
echo "GET $BASE_URL/api/message (Not allowed)"
echo "---"
response=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/api/message" \
    -H "Accept: application/json")
body=$(echo "$response" | head -n -1)
status_code=$(echo "$response" | tail -n 1)

echo "$body"
if test_status "405" "$status_code" "GET method not allowed"; then
    pass_test
else
    fail_test
fi
echo

# Test 9: Method Not Allowed - DELETE
echo "9. Method Not Allowed (DELETE /api/message):"
echo "DELETE $BASE_URL/api/message (Not allowed)"
echo "---"
response=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/api/message" \
    -H "Accept: application/json")
body=$(echo "$response" | head -n -1)
status_code=$(echo "$response" | tail -n 1)

echo "$body"
if test_status "405" "$status_code" "DELETE method not allowed"; then
    pass_test
else
    fail_test
fi
echo

# Test 10: Long Message (Edge case)
echo "10. Long Message Test:"
long_message=$(printf 'a%.0s' {1..999})  # 999 characters (within 1000 limit)
echo "POST $BASE_URL/api/message (999 char message)"
echo "---"
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/message" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "{
        \"message\": \"$long_message\",
        \"timestamp\": \"$current_timestamp\"
    }")
body=$(echo "$response" | head -n -1)
status_code=$(echo "$response" | tail -n 1)

echo "$body" | format_json
if test_status "200" "$status_code" "Long message (999 chars)"; then
    pass_test
else
    fail_test
fi
echo

# Test Summary
echo "=== TEST SUMMARY ==="
total_tests=$((pass_count + fail_count))
echo "Total tests: $total_tests"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo

if [ $fail_count -eq 0 ]; then
    echo "🎉 All tests passed!"
    exit 0
else
    echo "❌ Some tests failed. Please check the server implementation."
    exit 1
fi