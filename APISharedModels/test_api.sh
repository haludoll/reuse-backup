#!/bin/bash

# ReuseBackup Server API Basic Test Script
# シミュレータでReuseBackupServerアプリを起動してからこのスクリプトを実行してください

set -e

BASE_URL="http://localhost:8080"

echo "=== ReuseBackup Server API Basic Test ==="
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

# Test 1: Server Status Check
echo "1. Server Status Check:"
echo "GET $BASE_URL/api/status"
echo "---"
if curl -s -X GET "$BASE_URL/api/status" \
    -H "Accept: application/json" | format_json; then
    echo "✅ Status check successful"
else
    echo "❌ Status check failed"
    exit 1
fi
echo

# Test 2: Send Test Message
echo "2. Send Test Message:"
current_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "POST $BASE_URL/api/message"
echo "---"
if curl -s -X POST "$BASE_URL/api/message" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "{
        \"message\": \"Test message from curl script\",
        \"timestamp\": \"$current_timestamp\"
    }" | format_json; then
    echo "✅ Message send successful"
else
    echo "❌ Message send failed"
    exit 1
fi
echo

# Test 3: Send Japanese Message
echo "3. Send Japanese Message:"
echo "POST $BASE_URL/api/message"
echo "---"
if curl -s -X POST "$BASE_URL/api/message" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d '{
        "message": "こんにちは、テストメッセージです",
        "timestamp": "'$current_timestamp'"
    }' | format_json; then
    echo "✅ Japanese message send successful"
else
    echo "❌ Japanese message send failed"
    exit 1
fi
echo

# Test 4: Connection Test Message (OpenAPI example)
echo "4. Connection Test Message:"
echo "POST $BASE_URL/api/message"
echo "---"
if curl -s -X POST "$BASE_URL/api/message" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d '{
        "message": "Connection test",
        "timestamp": "'$current_timestamp'"
    }' | format_json; then
    echo "✅ Connection test successful"
else
    echo "❌ Connection test failed"
    exit 1
fi
echo

echo "🎉 All basic tests completed successfully!"
echo
echo "Note: For more comprehensive testing including error cases,"
echo "run: ./test_api_detailed.sh"