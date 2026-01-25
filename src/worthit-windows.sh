#!/bin/bash

# Token Usage and Cost Display Hook - Windows Toast Notification
# Displays token usage and cost via Windows toast notification

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

    # Send Windows toast notification
    # Escape function for PowerShell single-quoted strings
    escape_powershell() {
        echo "$1" | sed "s/'/''/g"
    }

    ESCAPED_MESSAGE=$(escape_powershell "$MESSAGE")
    ESCAPED_TITLE=$(escape_powershell "$TITLE")

    # Try BurntToast first, fallback to native Windows API
    powershell.exe -Command "New-BurntToastNotification -Text '$ESCAPED_TITLE', '$ESCAPED_MESSAGE'" 2>/dev/null || \
    powershell.exe -Command "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > \$null; \$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02); \$textNodes = \$template.GetElementsByTagName('text'); \$textNodes.Item(0).AppendChild(\$template.CreateTextNode('$ESCAPED_TITLE')) > \$null; \$textNodes.Item(1).AppendChild(\$template.CreateTextNode('$ESCAPED_MESSAGE')) > \$null; [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude').Show([Windows.UI.Notifications.ToastNotification]::new(\$template))" || true
fi

# Exit successfully
exit 0
