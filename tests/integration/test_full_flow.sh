#!/bin/bash
set +e  # Don't exit on error - we want to run all tests

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

test_case() {
    local name="$1"
    local script="$2"
    local input="$3"
    local expected="$4"  # "success" or "failure"

    echo -n "Testing: $name ... "

    # Use a subshell to properly capture exit codes
    local exit_code
    (echo "$input" | "$script" > /dev/null 2>&1)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        if [ "$expected" = "success" ]; then
            echo -e "${GREEN}PASS${NC}"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}FAIL${NC} (expected failure but succeeded)"
            ((FAILED++))
            return 1
        fi
    else
        if [ "$expected" = "failure" ]; then
            echo -e "${GREEN}PASS${NC}"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}FAIL${NC} (expected success but failed with exit code $exit_code)"
            ((FAILED++))
            return 1
        fi
    fi
}

echo -e "${YELLOW}Running Worthit Security and Integration Tests${NC}"
echo "================================================"
echo

# Get absolute path to project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

# Test 1: Normal operation with valid transcript
echo -e "${YELLOW}[1] Normal Operation Tests${NC}"
test_case "Valid transcript (test-transcript.jsonl)" \
    "src/worthit-linux.sh" \
    '{"transcript_path": "tests/test-transcript.jsonl"}' \
    "success"

test_case "Valid transcript (opus-transcript.jsonl)" \
    "src/worthit-linux.sh" \
    '{"transcript_path": "tests/fixtures/opus-transcript.jsonl"}' \
    "success"

test_case "Valid transcript (haiku-transcript.jsonl)" \
    "src/worthit-linux.sh" \
    '{"transcript_path": "tests/fixtures/haiku-transcript.jsonl"}' \
    "success"

test_case "Valid transcript (large-transcript.jsonl)" \
    "src/worthit-linux.sh" \
    '{"transcript_path": "tests/fixtures/large-transcript.jsonl"}' \
    "success"

echo

# Test 2: Path traversal attacks (should fail)
echo -e "${YELLOW}[2] Path Traversal Attack Prevention${NC}"
test_case "Path traversal with ../" \
    "src/worthit-linux.sh" \
    '{"transcript_path": "../../etc/passwd"}' \
    "failure"

test_case "Path traversal with multiple ../" \
    "src/worthit-linux.sh" \
    '{"transcript_path": "../../../root/.bashrc"}' \
    "failure"

test_case "Path traversal with home ~" \
    "src/worthit-linux.sh" \
    '{"transcript_path": "~/../../etc/passwd"}' \
    "failure"

echo

# Test 3: Command injection attempts (should fail)
echo -e "${YELLOW}[3] Command Injection Prevention${NC}"
test_case "Command substitution \$()" \
    "src/worthit-linux.sh" \
    '{"transcript_path": "$(whoami).jsonl"}' \
    "failure"

test_case "Command substitution backticks" \
    "src/worthit-linux.sh" \
    '{"transcript_path": "`whoami`.jsonl"}' \
    "failure"

test_case "Shell variable expansion" \
    "src/worthit-linux.sh" \
    '{"transcript_path": "$HOME/test.jsonl"}' \
    "failure"

echo

# Test 4: Malformed JSON (should fail)
echo -e "${YELLOW}[4] JSON Validation${NC}"
test_case "Malformed JSON" \
    "src/worthit-linux.sh" \
    'not valid json' \
    "failure"

test_case "Empty JSON object" \
    "src/worthit-linux.sh" \
    '{}' \
    "failure"

test_case "Missing transcript_path field" \
    "src/worthit-linux.sh" \
    '{"other_field": "value"}' \
    "failure"

test_case "Wrong type for transcript_path" \
    "src/worthit-linux.sh" \
    '{"transcript_path": 123}' \
    "failure"

echo

# Test 5: Non-existent files (should exit gracefully without notification)
echo -e "${YELLOW}[5] File Existence Handling${NC}"
test_case "Non-existent file (graceful exit)" \
    "src/worthit-linux.sh" \
    '{"transcript_path": "/tmp/nonexistent-file-12345.jsonl"}' \
    "success"

echo

# Summary
echo "================================================"
echo -e "${YELLOW}Test Summary${NC}"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
