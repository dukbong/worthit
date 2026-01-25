#!/usr/bin/env python3
"""
Unit tests for input validation and sanitization functions.

These tests verify that the security measures in worthit scripts
properly reject malicious inputs and sanitize outputs.
"""

import unittest
import os
import sys
import re

# Copy the functions from the script for testing
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

def sanitize_transcript_path(transcript_path):
    """Sanitize path to prevent traversal attacks"""
    # Reject dangerous patterns
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


class TestHookInputValidation(unittest.TestCase):
    """Test hook input validation"""

    def test_valid_input(self):
        """Should accept valid dict with transcript_path"""
        hook_input = {'transcript_path': '/tmp/test.jsonl'}
        result = validate_hook_input(hook_input)
        self.assertEqual(result, '/tmp/test.jsonl')

    def test_reject_non_dict(self):
        """Should reject non-dict input"""
        with self.assertRaises(ValueError) as cm:
            validate_hook_input("not a dict")
        self.assertIn("must be a dict", str(cm.exception))

    def test_reject_missing_transcript_path(self):
        """Should reject dict without transcript_path"""
        with self.assertRaises(ValueError) as cm:
            validate_hook_input({})
        self.assertIn("Missing transcript_path", str(cm.exception))

    def test_reject_non_string_path(self):
        """Should reject non-string transcript_path"""
        with self.assertRaises(ValueError) as cm:
            validate_hook_input({'transcript_path': 123})
        self.assertIn("must be string", str(cm.exception))


class TestPathSanitization(unittest.TestCase):
    """Test path sanitization against traversal attacks"""

    def test_reject_parent_directory(self):
        """Should reject paths with ../"""
        with self.assertRaises(ValueError):
            sanitize_transcript_path("../../etc/passwd")

    def test_reject_home_directory(self):
        """Should reject paths with ~"""
        with self.assertRaises(ValueError):
            sanitize_transcript_path("~/test.jsonl")

    def test_reject_command_substitution_dollar(self):
        """Should reject paths with $ (variable expansion)"""
        with self.assertRaises(ValueError):
            sanitize_transcript_path("$HOME/test.jsonl")

    def test_reject_command_substitution_backtick(self):
        """Should reject paths with backticks"""
        with self.assertRaises(ValueError):
            sanitize_transcript_path("`whoami`.jsonl")

    def test_reject_directory(self):
        """Should reject directory paths"""
        # Create a temp directory
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            with self.assertRaises(ValueError) as cm:
                sanitize_transcript_path(tmpdir)
            self.assertIn("not a regular file", str(cm.exception))

    def test_accept_valid_path(self):
        """Should accept valid file paths"""
        # Create a temp file
        import tempfile
        with tempfile.NamedTemporaryFile(delete=False, suffix='.jsonl') as f:
            temp_path = f.name

        try:
            result = sanitize_transcript_path(temp_path)
            self.assertTrue(os.path.isabs(result))
            self.assertTrue(os.path.exists(result))
        finally:
            os.unlink(temp_path)


class TestOutputSanitization(unittest.TestCase):
    """Test output sanitization for shell safety"""

    def test_remove_pipes(self):
        """Should replace pipe characters"""
        result = sanitize_output("In: 100 | Out: 50")
        self.assertNotIn('|', result)
        self.assertIn('/', result)  # Replaced with /

    def test_remove_backticks(self):
        """Should remove backticks"""
        result = sanitize_output("Test `command` injection")
        self.assertNotIn('`', result)

    def test_remove_dollar_signs(self):
        """Should remove dollar signs"""
        result = sanitize_output("Cost: $10.50")
        # First $ should be removed, second is part of number
        self.assertEqual(result.count('$'), 0)

    def test_remove_newlines(self):
        """Should replace newlines with spaces"""
        result = sanitize_output("Line 1\nLine 2")
        self.assertNotIn('\n', result)
        self.assertIn(' ', result)

    def test_remove_carriage_returns(self):
        """Should replace carriage returns with spaces"""
        result = sanitize_output("Line 1\rLine 2")
        self.assertNotIn('\r', result)
        self.assertIn(' ', result)

    def test_handle_empty_input(self):
        """Should handle empty or None input"""
        self.assertEqual(sanitize_output(""), "")
        self.assertEqual(sanitize_output(None), "")

    def test_safe_text_unchanged(self):
        """Should not modify safe text"""
        safe_text = "Normal text 123 abc"
        result = sanitize_output(safe_text)
        self.assertEqual(result, safe_text)


if __name__ == '__main__':
    # Run tests with verbose output
    unittest.main(verbosity=2)
