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

def get_pricing(model):
    """Get pricing information based on model"""
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
        transcript_path = hook_input.get('transcript_path')

        if not transcript_path or not os.path.exists(transcript_path):
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
                totals['output'] += usage.get('output_tokens', 0)
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

        # Output in format: "total_in_tokens|total_out_tokens|cost|model"
        print(f"{format_number(total_in)}|{format_number(total_out)}|{format_cost(cost)}|{format_model_name(model)}")

    except Exception:
        # Gracefully handle errors without output
        pass

if __name__ == "__main__":
    main()

PYTHON_SCRIPT
)

# Check if Python script returned a result
if [ -n "$RESULT" ]; then
    # Parse input tokens, output tokens, cost, and model
    INPUT_TOKENS=$(echo "$RESULT" | cut -d'|' -f1)
    OUTPUT_TOKENS=$(echo "$RESULT" | cut -d'|' -f2)
    COST=$(echo "$RESULT" | cut -d'|' -f3)
    MODEL=$(echo "$RESULT" | cut -d'|' -f4)

    # Create notification message and title
    MESSAGE="In: $INPUT_TOKENS | Out: $OUTPUT_TOKENS | Cost: $COST"
    TITLE="$MODEL Claude Usage"

    # Send Linux desktop notification
    # Try notify-send first (most common)
    if command -v notify-send &> /dev/null; then
        notify-send "$TITLE" "$MESSAGE" --icon=dialog-information --urgency=low 2>/dev/null
    else
        # Fallback: zenity or terminal output
        if command -v zenity &> /dev/null; then
            zenity --info --title="$TITLE" --text="$MESSAGE" --timeout=5 2>/dev/null &
        else
            # Last resort: terminal output
            echo "[$TITLE] $MESSAGE" >&2
        fi
    fi
fi
