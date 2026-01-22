# Manual Installation Guide

This guide covers manual installation of Worthit for users who prefer manual setup or when the automatic installer doesn't work.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Windows/WSL Installation](#windowswsl-installation)
- [macOS Installation](#macos-installation)
- [Linux Installation](#linux-installation)
- [Verifying Installation](#verifying-installation)
- [Troubleshooting](#troubleshooting)

## Prerequisites

All platforms require:
- Python 3.6 or higher
- Claude CLI installed and configured
- `curl` or `wget` for downloading scripts

## Windows/WSL Installation

### Step 1: Download the Script

```bash
mkdir -p ~/.claude/hooks
curl -fsSL https://raw.githubusercontent.com/dukbong/worthit/main/src/worthit-windows.sh \
  -o ~/.claude/hooks/worthit.sh
chmod +x ~/.claude/hooks/worthit.sh
```

### Step 2: Configure Claude Settings

Create or edit `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/home/YOUR_USERNAME/.claude/hooks/worthit.sh"
          }
        ]
      }
    ]
  }
}
```

Replace `YOUR_USERNAME` with your actual WSL username.

### Step 3: Verify PowerShell Access

Test PowerShell from WSL:

```bash
powershell.exe -Command "Write-Host 'PowerShell works!'"
```

If this doesn't work, ensure PowerShell is in your WSL PATH.

### Optional: Install BurntToast

For better notifications, install BurntToast in PowerShell (Windows side):

```powershell
Install-Module -Name BurntToast -Scope CurrentUser
```

## macOS Installation

### Step 1: Download the Script

```bash
mkdir -p ~/.claude/hooks
curl -fsSL https://raw.githubusercontent.com/dukbong/worthit/main/src/worthit-macos.sh \
  -o ~/.claude/hooks/worthit.sh
chmod +x ~/.claude/hooks/worthit.sh
```

### Step 2: Configure Claude Settings

Create or edit `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/YOUR_USERNAME/.claude/hooks/worthit.sh"
          }
        ]
      }
    ]
  }
}
```

Replace `YOUR_USERNAME` with your actual macOS username.

### Step 3: Enable Terminal Notifications

1. Open **System Preferences** (or **System Settings** on macOS 13+)
2. Go to **Notifications**
3. Find **Terminal** (or your terminal app)
4. Enable **Allow notifications**

### Step 4: Test Notifications

```bash
osascript -e 'display notification "Test" with title "Worthit Test"'
```

You should see a notification appear.

## Linux Installation

### Step 1: Install Dependencies

Most Linux distributions have `notify-send` pre-installed. If not:

```bash
# Ubuntu/Debian
sudo apt-get install libnotify-bin

# Fedora
sudo dnf install libnotify

# Arch Linux
sudo pacman -S libnotify

# openSUSE
sudo zypper install libnotify-tools
```

### Step 2: Download the Script

```bash
mkdir -p ~/.claude/hooks
curl -fsSL https://raw.githubusercontent.com/dukbong/worthit/main/src/worthit-linux.sh \
  -o ~/.claude/hooks/worthit.sh
chmod +x ~/.claude/hooks/worthit.sh
```

### Step 3: Configure Claude Settings

Create or edit `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/home/YOUR_USERNAME/.claude/hooks/worthit.sh"
          }
        ]
      }
    ]
  }
}
```

Replace `YOUR_USERNAME` with your actual Linux username.

### Step 4: Test Notifications

```bash
notify-send "Worthit Test" "This is a test notification"
```

You should see a desktop notification.

## Verifying Installation

After installation, verify the setup:

### 1. Check Script Exists

```bash
ls -la ~/.claude/hooks/worthit.sh
```

Should show the file with execute permissions (`-rwxr-xr-x`).

### 2. Check Settings File

```bash
cat ~/.claude/settings.json
```

Should contain the hook configuration.

### 3. Test with Sample Transcript

```bash
# Download test transcript
curl -fsSL https://raw.githubusercontent.com/dukbong/worthit/main/tests/test-transcript.jsonl \
  -o /tmp/test-transcript.jsonl

# Test the hook
export HOOK_INPUT='{"transcript_path": "/tmp/test-transcript.jsonl"}'
echo "$HOOK_INPUT" | ~/.claude/hooks/worthit.sh
```

You should see a notification with:
- Title: "Sonnet 4.5 Claude Usage"
- Message: "In: 1,500 | Out: 500 | Cost: $0.0120"

### 4. Test with Actual Claude CLI

Run any Claude command:

```bash
claude "What is 2+2?"
```

You should see a notification after Claude responds.

## Troubleshooting

### Hook Not Triggering

**Check Claude CLI version:**
```bash
claude --version
```

Hooks require Claude CLI v0.3.0 or later.

**Verify hook registration:**
```bash
cat ~/.claude/settings.json | grep -A 5 "Stop"
```

### Python Errors

**Check Python version:**
```bash
python3 --version
```

Must be 3.6 or higher.

**Test Python script independently:**
```bash
python3 ~/.claude/hooks/worthit.sh
```

### Notification Issues

**Windows/WSL:**
- Verify PowerShell works: `powershell.exe -Command "Get-Host"`
- Check Windows notification settings
- Try installing BurntToast

**macOS:**
- Grant notification permissions to Terminal
- Test osascript: `osascript -e 'display notification "test"'`

**Linux:**
- Ensure you're in a graphical session
- Check D-Bus: `echo $DBUS_SESSION_BUS_ADDRESS`
- Test notify-send: `notify-send "test"`

### Settings File Issues

If your `settings.json` is malformed, Claude CLI may not load it.

**Backup and reset:**
```bash
cp ~/.claude/settings.json ~/.claude/settings.json.backup
echo '{}' > ~/.claude/settings.json
```

Then manually add the hook configuration.

**Validate JSON:**
```bash
python3 -m json.tool ~/.claude/settings.json
```

### Permission Errors

Ensure the script is executable:
```bash
chmod +x ~/.claude/hooks/worthit.sh
```

### Path Issues

Use absolute paths in `settings.json`. Relative paths like `~/` may not work.

**Find your absolute path:**
```bash
echo "$HOME/.claude/hooks/worthit.sh"
```

Use this full path in `settings.json`.

## Advanced Configuration

### Custom Hook Location

You can install the hook anywhere. Just update `settings.json` with the correct path:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/custom/path/to/worthit.sh"
          }
        ]
      }
    ]
  }
}
```

### Multiple Hooks

You can have multiple Stop hooks. Worthit will run alongside them:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {"type": "command", "command": "/path/to/hook1.sh"},
          {"type": "command", "command": "/path/to/worthit.sh"},
          {"type": "command", "command": "/path/to/hook3.sh"}
        ]
      }
    ]
  }
}
```

### Conditional Hooks

Use matchers to run hooks only for specific patterns:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "project-*",
        "hooks": [
          {"type": "command", "command": "/path/to/worthit.sh"}
        ]
      }
    ]
  }
}
```

This runs Worthit only for projects matching `project-*`.

## Getting Help

If you're still having issues:

1. Check the [main README](../README.md) troubleshooting section
2. Open an issue on [GitHub](https://github.com/dukbong/worthit/issues)
3. Include:
   - Your platform (Windows/WSL, macOS, Linux)
   - Python version (`python3 --version`)
   - Claude CLI version (`claude --version`)
   - Error messages or unexpected behavior

---

**Need automatic installation?** See the main [README](../README.md) for the one-line installer.
