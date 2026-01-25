#!/bin/bash

# Token Usage and Cost Display Hook - Linux Desktop Notification
# Displays token usage and cost via Linux desktop notification (notify-send)

# Save stdin to temp file to preserve it before heredoc
HOOK_INPUT=$(cat)

# Run Python script to calculate tokens and cost, output as "tokens|cost"
RESULT=$(python3 - "$HOOK_INPUT" <<'PYTHON_SCRIPT'
import json
import sys
import os
import re

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

def get_pricing(model):
    """
    Get pricing information based on model.

    Pricing source: https://www.anthropic.com/pricing
    Last verified: 2025-01-25

    Note: Hardcoded because Claude CLI transcripts don't include costs.
    """
    model_lower = model.lower() if model else ""

    # Claude Opus 4.5 pricing
    if "opus" in model_lower:
        return {
            "input": 0.000005,
            "output": 0.000025,
            "cache_write": 0.00000625,
            "cache_read": 0.0000005
        }

    # Claude Haiku 4.5 pricing
    if "haiku" in model_lower:
        return {
            "input": 0.000001,
            "output": 0.000005,
            "cache_write": 0.00000125,
            "cache_read": 0.0000001
        }

    # Claude Sonnet 4.5 pricing (default)
    return {
        "input": 0.000003,
        "output": 0.000015,
        "cache_write": 0.00000375,
        "cache_read": 0.0000003
    }

def estimate_output_tokens(message):
    """
    Estimate output tokens from actual content length.

    This is a workaround for Claude CLI transcript recording
    incorrect output_tokens (often 1-2 instead of 100s).
    """
    total = 0.0

    for block in message.get('content', []):
        block_type = block.get('type')

        if block_type == 'text':
            text = block.get('text', '')
            # Average: ~3 chars per token (mixed Korean/English)
            total += len(text) / 3.0

        elif block_type == 'thinking':
            thinking = block.get('thinking', '')
            # Thinking blocks: same ratio
            total += len(thinking) / 3.0

        elif block_type == 'tool_use':
            # Tool use blocks: tool name + parameters
            # Typically 50-200 tokens depending on complexity
            tool_name = block.get('name', '')
            tool_input = block.get('input', {})

            # Tool name overhead: ~20 tokens for XML structure
            total += 20

            # Tool parameters: estimate from JSON length
            import json
            input_json = json.dumps(tool_input)
            # Parameters in XML: roughly 1 token per 3 chars
            total += len(input_json) / 3.0

    return int(total) if total > 0 else 0

def calculate_cost(totals, pricing):
    """Calculate total cost based on token usage and pricing"""
    cost = (
        totals['input'] * pricing['input'] +
        totals['output'] * pricing['output'] +
        totals['cache_write'] * pricing['cache_write'] +
        totals['cache_read'] * pricing['cache_read']
    )
    return cost

def format_number(num):
    """Format number with comma separators"""
    return "{:,}".format(num)

def format_cost(cost):
    """Format cost with appropriate precision"""
    if cost < 0.0001:
        return f"${cost:.6f}"
    else:
        return f"${cost:.4f}"

def format_model_name(model):
    """Format model name for display"""
    if not model:
        return "Mystery Model"
    model = sanitize_output(str(model))
    model_lower = model.lower()
    if "opus" in model_lower:
        return "Opus 4.5"
    elif "haiku" in model_lower:
        return "Haiku 4.5"
    elif "sonnet" in model_lower:
        return "Sonnet 4.5"
    else:
        return "Mystery Model"

def main():
    try:
        # Read hook input from command line argument
        if len(sys.argv) < 2:
            return

        hook_input = json.loads(sys.argv[1])
        transcript_path = validate_hook_input(hook_input)
        transcript_path = sanitize_transcript_path(transcript_path)

        if not os.path.exists(transcript_path):
            # Silently exit if no transcript
            return

        # Parse transcript
        messages = []
        with open(transcript_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        messages.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue

        # Find current turn's assistant messages (in reverse order)
        assistant_messages = []
        for msg in reversed(messages):
            msg_type = msg.get('type')
            if msg_type == 'assistant':
                assistant_messages.append(msg)
            elif msg_type == 'user':
                # Stop at first user message
                break

        if not assistant_messages:
            # No assistant messages in current turn
            return

        # Sum tokens from current turn
        totals = {
            'input': 0,
            'output': 0,
            'cache_read': 0,
            'cache_write': 0
        }
        model = None

        for msg in assistant_messages:
            message = msg.get('message', {})
            if message.get('role') == 'assistant':
                usage = message.get('usage', {})
                if not model:
                    model = message.get('model', 'unknown')

                totals['input'] += usage.get('input_tokens', 0)

                # Fix: Use estimated output tokens instead of transcript value
                # Transcript often records 1-2 instead of actual 100s of tokens
                estimated_output = estimate_output_tokens(message)
                totals['output'] += estimated_output

                totals['cache_read'] += usage.get('cache_read_input_tokens', 0)
                totals['cache_write'] += usage.get('cache_creation_input_tokens', 0)

        # Calculate total tokens and cost
        total_tokens = sum(totals.values())

        if total_tokens == 0:
            # No tokens used
            return

        pricing = get_pricing(model)
        cost = calculate_cost(totals, pricing)

        # Calculate aggregated token counts for display
        total_in = totals['input'] + totals['cache_read'] + totals['cache_write']
        total_out = totals['output']

        # Output in format: "total_in_tokens<SEP>total_out_tokens<SEP>cost<SEP>model"
        # Using ASCII Unit Separator for safe parsing
        SEPARATOR = '\x1F'
        print(f"{format_number(total_in)}{SEPARATOR}{format_number(total_out)}{SEPARATOR}{format_cost(cost)}{SEPARATOR}{format_model_name(model)}")

    except ValueError as e:
        # Security validation failed - exit with error code
        sys.exit(1)
    except Exception:
        # Other errors - gracefully handle without output
        pass

if __name__ == "__main__":
    main()

PYTHON_SCRIPT
)
PYTHON_EXIT_CODE=$?

# If Python validation failed, exit with error
if [ $PYTHON_EXIT_CODE -ne 0 ]; then
    exit $PYTHON_EXIT_CODE
fi

# Check if Python script returned a result
if [ -n "$RESULT" ]; then
    # Parse input tokens, output tokens, cost, and model using ASCII Unit Separator
    SEPARATOR=$'\x1F'
    INPUT_TOKENS=$(echo "$RESULT" | cut -d"$SEPARATOR" -f1)
    OUTPUT_TOKENS=$(echo "$RESULT" | cut -d"$SEPARATOR" -f2)
    COST=$(echo "$RESULT" | cut -d"$SEPARATOR" -f3)
    MODEL=$(echo "$RESULT" | cut -d"$SEPARATOR" -f4)

    # Create notification message and title
    MESSAGE="In: $INPUT_TOKENS | Out: $OUTPUT_TOKENS | Cost: $COST"
    TITLE="$MODEL Claude Usage"

    # Send Linux desktop notification
    # Try notify-send first (most common)
    if command -v notify-send &> /dev/null; then
        notify-send "$(printf '%s' "$TITLE")" "$(printf '%s' "$MESSAGE")" \
            --icon=dialog-information --urgency=low 2>/dev/null || true
    else
        # Fallback: zenity or terminal output
        if command -v zenity &> /dev/null; then
            (zenity --info --title="$TITLE" --text="$MESSAGE" --timeout=5 2>/dev/null &) || true
        else
            # Last resort: terminal output
            echo "[$TITLE] $MESSAGE" >&2 || true
        fi
    fi
fi

# Exit successfully
exit 0
