# Security Documentation

This document describes Worthit's security architecture, threat model, and the measures taken to protect users from potential vulnerabilities.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Security Measures](#security-measures)
- [Threat Model](#threat-model)
- [Security Testing](#security-testing)
- [Reporting Security Issues](#reporting-security-issues)
- [Security Recommendations](#security-recommendations)

## Architecture Overview

### Data Flow

```
┌─────────────┐
│ Claude CLI  │
└──────┬──────┘
       │ Generates transcript
       │ (JSONL file)
       ▼
┌─────────────────┐
│ User Interaction│
└──────┬──────────┘
       │ "Stop" hook triggered
       │
       ▼
┌──────────────────────┐
│ Worthit Hook Script  │
│  (Platform-specific) │
└──────┬───────────────┘
       │ Reads transcript path
       │ from hook input (JSON)
       │
       ▼
┌──────────────────┐
│ Python Processor │ ← Input Validation
└──────┬───────────┘   ← Path Sanitization
       │               ← Output Sanitization
       ▼
┌──────────────────┐
│ Token Counting & │
│ Cost Calculation │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Bash Formatter   │ ← Shell Escaping
└──────┬───────────┘
       │
       ▼
┌──────────────────────┐
│ Native Notification  │
│ (notify-send/        │
│  osascript/          │
│  PowerShell)         │
└──────────────────────┘
```

### Key Security Boundaries

1. **Input Boundary**: Hook input JSON from Claude CLI
2. **File System Boundary**: Transcript file reading
3. **Shell Boundary**: Bash variable expansion and command execution
4. **Notification Boundary**: Platform-specific notification APIs

## Security Measures

### 1. Input Validation

**Location**: Python section in each platform script

#### JSON Schema Validation

```python
def validate_hook_input(hook_input):
    """Validate hook input structure and types"""
    if not isinstance(hook_input, dict):
        raise ValueError("Hook input must be a dict")

    transcript_path = hook_input.get('transcript_path')
    if not transcript_path:
        raise ValueError("Missing transcript_path")

    if not isinstance(transcript_path, str):
        raise ValueError("transcript_path must be string")

    return transcript_path
```

**Protects against**:
- Malformed JSON
- Type confusion attacks
- Missing required fields

### 2. Path Sanitization

**Location**: `sanitize_transcript_path()` function

#### Dangerous Pattern Rejection

```python
def sanitize_transcript_path(transcript_path):
    """Sanitize path to prevent traversal attacks"""
    dangerous = [r'\.\.', r'~', r'\$', r'`']
    for pattern in dangerous:
        if re.search(pattern, transcript_path):
            raise ValueError(f"Invalid path: contains {pattern}")

    # Resolve to absolute path
    abs_path = os.path.abspath(os.path.expanduser(transcript_path))

    # Verify it's a regular file
    if os.path.exists(abs_path):
        if not os.path.isfile(abs_path):
            raise ValueError("Path is not a regular file")

    return abs_path
```

**Protects against**:
- Path traversal attacks (`../../etc/passwd`)
- Home directory expansion (`~/sensitive`)
- Shell variable expansion (`$HOME/file`)
- Command substitution (`` `whoami` ``, `$(whoami)`)
- Directory reading

### 3. Output Sanitization

**Location**: `sanitize_output()` function

```python
def sanitize_output(text):
    """Sanitize text for shell output"""
    if not text:
        return ""

    safe = text.replace('\n', ' ')
    safe = safe.replace('\r', ' ')
    safe = safe.replace('`', '')
    safe = safe.replace('$', '')
    safe = safe.replace('|', '/')

    return safe
```

**Protects against**:
- Command injection via backticks
- Variable expansion via dollar signs
- Pipe redirection
- Newline injection

### 4. Shell Escaping

#### macOS (osascript)

```bash
escape_applescript() {
    echo "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g'
}

ESCAPED_MESSAGE=$(escape_applescript "$MESSAGE")
ESCAPED_TITLE=$(escape_applescript "$TITLE")

osascript -e "display notification \"$ESCAPED_MESSAGE\" with title \"$ESCAPED_TITLE\" sound name \"Glass\""
```

**Protects against**: AppleScript injection via quotes and backslashes

#### Windows (PowerShell)

```bash
escape_powershell() {
    echo "$1" | sed "s/'/''/g"
}

ESCAPED_MESSAGE=$(escape_powershell "$MESSAGE")
ESCAPED_TITLE=$(escape_powershell "$TITLE")

powershell.exe -Command "New-BurntToastNotification -Text '$ESCAPED_TITLE', '$ESCAPED_MESSAGE'"
```

**Protects against**: PowerShell injection via single quote escaping

#### Linux (notify-send)

```bash
notify-send "$(printf '%s' "$TITLE")" "$(printf '%s' "$MESSAGE")" \
    --icon=dialog-information --urgency=low
```

**Protects against**: Shell expansion via printf safe printing

### 5. Safe Delimiter

**Implementation**: ASCII Unit Separator (`\x1F`) instead of pipe (`|`)

```python
SEPARATOR = '\x1F'  # ASCII Unit Separator
print(f"{tokens_in}{SEPARATOR}{tokens_out}{SEPARATOR}{cost}{SEPARATOR}{model}")
```

```bash
SEPARATOR=$'\x1F'
INPUT_TOKENS=$(echo "$RESULT" | cut -d"$SEPARATOR" -f1)
```

**Protects against**: Data containing pipes breaking parsing

## Threat Model

### In Scope

We protect against the following threats:

#### 1. Path Traversal Attacks

**Scenario**: Malicious actor provides crafted transcript path
```json
{"transcript_path": "../../etc/passwd"}
```

**Mitigation**: Pattern rejection + absolute path resolution

**Test**: `tests/integration/test_full_flow.sh`

#### 2. Command Injection

**Scenario**: Malicious actor injects shell commands
```json
{"transcript_path": "$(rm -rf ~).jsonl"}
{"transcript_path": "`whoami`.jsonl"}
```

**Mitigation**: Dangerous character rejection + sanitization

**Test**: `tests/integration/test_full_flow.sh`

#### 3. Shell Escaping Bypass

**Scenario**: Special characters in notification message break shell escaping
```
Message: Test `command` injection
Message: Cost: $100 | Out: $(whoami)
```

**Mitigation**: Output sanitization + platform-specific escaping

**Test**: `tests/unit/test_sanitization.py`

#### 4. Type Confusion

**Scenario**: Non-string values cause unexpected behavior
```json
{"transcript_path": 123}
{"transcript_path": ["array", "of", "values"]}
```

**Mitigation**: Type validation in `validate_hook_input()`

**Test**: `tests/integration/test_full_flow.sh`

### Out of Scope

The following are **not** in our threat model (handled elsewhere):

- **Claude CLI security**: We trust Claude CLI to provide safe hook inputs
- **OS-level vulnerabilities**: Platform notification APIs (osascript, PowerShell, notify-send)
- **File system permissions**: We assume proper file permissions on transcript files
- **Network attacks**: Worthit operates entirely offline (no network access)

### Assumptions

We assume:
1. Claude CLI itself is not compromised
2. The user's system has not been compromised
3. File system permissions are properly configured
4. Platform notification systems are secure

## Security Testing

### Test Coverage

We have comprehensive tests for all security measures:

#### 1. Unit Tests

**File**: `tests/unit/test_sanitization.py`

Tests:
- ✅ Input validation (JSON schema)
- ✅ Path sanitization (traversal prevention)
- ✅ Output sanitization (shell safety)

**Run**: `python3 tests/unit/test_sanitization.py`

#### 2. Integration Tests

**File**: `tests/integration/test_full_flow.sh`

Tests:
- ✅ Path traversal attacks (should fail)
- ✅ Command injection attempts (should fail)
- ✅ Malformed JSON (should fail)
- ✅ Normal operation (should succeed)

**Run**: `tests/integration/test_full_flow.sh`

#### 3. CI/CD Tests

**File**: `.github/workflows/test.yml`

Automated tests run on every:
- Push to main/develop
- Pull request
- Manual trigger

Includes:
- Security tests (path traversal, command injection)
- Unit tests (sanitization, pricing)
- Integration tests (full flow)

### Running Tests Locally

```bash
# All tests
./tests/integration/test_full_flow.sh

# Unit tests only
python3 tests/unit/test_sanitization.py
python3 tests/unit/test_pricing.py

# Specific security test
echo '{"transcript_path": "../../etc/passwd"}' | src/worthit-linux.sh
# Should fail (exit code != 0)
```

## Reporting Security Issues

### How to Report

**DO NOT** open a public GitHub Issue for security vulnerabilities.

Instead, use one of these methods:

#### 1. GitHub Security Advisories (Preferred)

1. Go to: https://github.com/dukbong/worthit/security/advisories/new
2. Fill out the advisory form
3. Include all relevant details (see below)

#### 2. Private Email

Email the maintainer directly (see GitHub profile for contact info)

### What to Include

Please provide:

- **Description**: Clear explanation of the vulnerability
- **Steps to reproduce**: Exact commands or inputs to trigger it
- **Impact**: What an attacker could achieve
- **Affected versions**: Which versions are vulnerable
- **Suggested fix**: (Optional) How you think it should be fixed
- **PoC**: (Optional) Proof of concept code

**Example report**:
```
**Vulnerability**: Command injection in notification title

**Steps to reproduce**:
1. Create transcript with malicious model name
2. Run worthit hook
3. Observe command execution

**Impact**: Arbitrary command execution with user privileges

**Affected versions**: v1.0.0 and earlier

**Suggested fix**: Sanitize model name before display
```

### Response Timeline

- **Acknowledgment**: Within 24 hours
- **Initial assessment**: Within 72 hours
- **Fix development**: Within 7 days (for critical issues)
- **Public disclosure**: After fix is released + 7 day grace period

### Severity Levels

We use the following severity classifications:

| Severity | Description | Example | Response Time |
|----------|-------------|---------|---------------|
| **Critical** | Remote code execution, privilege escalation | RCE via hook input | 24-48 hours |
| **High** | Information disclosure, DoS | Path traversal to /etc/passwd | 3-7 days |
| **Medium** | Limited impact, requires user action | XSS in notification | 7-14 days |
| **Low** | Theoretical, difficult to exploit | Timing attack | 14-30 days |

## Security Recommendations

### For Users

1. **Keep Worthit Updated**
   ```bash
   # Check for updates regularly
   cd ~/.claude/hooks
   git pull origin main
   ```

2. **Review Code Before Running**
   - Worthit is open source - review the code
   - Check Git commits before updating
   - Verify scripts haven't been tampered with

3. **Use Official Installation Only**
   ```bash
   # Use official installer
   curl -fsSL https://raw.githubusercontent.com/dukbong/worthit/main/install.sh | bash

   # DO NOT use third-party installers
   ```

4. **Monitor for Anomalies**
   - Unexpected notifications
   - Unusual file access patterns
   - Performance degradation

5. **Report Issues**
   - Found something suspicious? Report it
   - See "Reporting Security Issues" above

### For Developers

1. **Input Validation**
   - Always validate input types and structure
   - Reject unexpected or malformed input
   - Use allowlists, not denylists when possible

2. **Output Sanitization**
   - Escape all output before shell execution
   - Remove or encode dangerous characters
   - Use safe delimiters (not user-controlled)

3. **Defense in Depth**
   - Multiple layers of protection
   - Input validation + path sanitization + output escaping
   - Fail securely (reject on error, don't continue)

4. **Testing**
   - Test all security measures
   - Include adversarial test cases
   - Automate security tests in CI/CD

5. **Code Review**
   - All changes reviewed before merge
   - Security-focused review for critical paths
   - Consider threat model during review

## Security Audit History

| Date | Auditor | Scope | Findings | Status |
|------|---------|-------|----------|--------|
| 2025-01-25 | Internal | Full codebase | 4 vulnerabilities fixed | ✅ Resolved |

### 2025-01-25 Audit Findings

**Auditor**: Internal security review
**Scope**: All platform scripts, test coverage

**Findings**:

1. **CRITICAL**: Command injection via osascript (macOS)
   - **Status**: ✅ Fixed (added `escape_applescript()`)
   - **Commit**: Added in this security update

2. **CRITICAL**: Command injection via PowerShell (Windows)
   - **Status**: ✅ Fixed (added `escape_powershell()`)
   - **Commit**: Added in this security update

3. **HIGH**: Path traversal vulnerability
   - **Status**: ✅ Fixed (added `sanitize_transcript_path()`)
   - **Commit**: Added in this security update

4. **MEDIUM**: Insufficient input validation
   - **Status**: ✅ Fixed (added `validate_hook_input()`)
   - **Commit**: Added in this security update

**Recommendations implemented**:
- ✅ Comprehensive test suite
- ✅ Security documentation (this file)
- ✅ CI/CD security tests
- ✅ Safe delimiter (ASCII Unit Separator)

## Security Best Practices

### Principle of Least Privilege

Worthit operates with minimal permissions:
- ✅ Reads only transcript files (no write access)
- ✅ No network access
- ✅ No system modification
- ✅ No privilege escalation

### Fail Securely

On any error or validation failure:
- ✅ Script exits immediately (no partial execution)
- ✅ No error messages displayed to user (fail silently)
- ✅ No fallback to unsafe behavior

### Defense in Depth

Multiple security layers:
1. Input validation (reject malformed data)
2. Path sanitization (prevent traversal)
3. Output sanitization (remove dangerous characters)
4. Shell escaping (platform-specific)
5. Safe delimiters (non-user-controlled)

## Contact

- **Security issues**: [GitHub Security Advisories](https://github.com/dukbong/worthit/security/advisories/new)
- **General questions**: [GitHub Discussions](https://github.com/dukbong/worthit/discussions)
- **Public issues**: [GitHub Issues](https://github.com/dukbong/worthit/issues)

## Acknowledgments

We thank the security researchers and contributors who help keep Worthit secure.

---

**Last updated**: January 25, 2025
**Document version**: 1.0.0
**Next review**: February 25, 2025
