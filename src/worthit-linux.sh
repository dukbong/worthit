#!/bin/bash

# Token Usage and Cost Display Hook - Linux Desktop Notification
# Displays token usage and cost via Linux desktop notification (notify-send)

# Save stdin to preserve it
HOOK_INPUT=$(cat)

# Get script directory to locate worthit_core.py
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run Python core module to calculate tokens and cost
RESULT=$(python3 "$SCRIPT_DIR/worthit_core.py" "$HOOK_INPUT")
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
