#!/bin/bash

# Worthit Installer
# Automatically detects platform and installs the appropriate script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# GitHub repository info
GITHUB_RAW_URL="https://raw.githubusercontent.com/dukbong/worthit/main"

# Installation paths
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
INSTALL_PATH="$HOOKS_DIR/worthit.sh"

# Print colored message
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect platform
detect_platform() {
    local os="$(uname -s)"
    local kernel="$(uname -r)"

    case "$os" in
        Linux*)
            if [[ "$kernel" == *"microsoft"* ]] || [[ "$kernel" == *"WSL"* ]]; then
                echo "windows"
            else
                echo "linux"
            fi
            ;;
        Darwin*)
            echo "macos"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Check if Python 3 is available
check_python3() {
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed. Please install Python 3 first."
        exit 1
    fi
}

# Check if curl is available
check_curl() {
    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed. Please install curl first."
        exit 1
    fi
}

# Check if Claude CLI is installed
check_claude() {
    if [ ! -d "$CLAUDE_DIR" ]; then
        print_warn "Claude directory not found at $CLAUDE_DIR"
        print_warn "Make sure Claude CLI is installed before running this script."
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Create directories if they don't exist
create_directories() {
    mkdir -p "$HOOKS_DIR"
    print_info "Created hooks directory at $HOOKS_DIR"
}

# Download script for detected platform
download_script() {
    local platform=$1
    local script_name="worthit-${platform}.sh"
    local download_url="${GITHUB_RAW_URL}/src/${script_name}"

    print_info "Detected platform: $platform"
    print_info "Downloading script from $download_url"

    if curl -fsSL "$download_url" -o "$INSTALL_PATH"; then
        chmod +x "$INSTALL_PATH"
        print_info "Script installed successfully at $INSTALL_PATH"
    else
        print_error "Failed to download script from $download_url"
        exit 1
    fi
}

# Update Claude settings.json to add hook
update_settings() {
    print_info "Updating Claude settings..."

    # Check if settings.json exists
    if [ ! -f "$SETTINGS_FILE" ]; then
        print_info "Creating new settings.json file..."
        echo '{}' > "$SETTINGS_FILE"
    fi

    # Backup settings file
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup"
    print_info "Created backup at ${SETTINGS_FILE}.backup"

    # Update settings using Python
    python3 - <<EOF
import json
import os
import sys

settings_file = os.path.expanduser('$SETTINGS_FILE')
hook_path = os.path.expanduser('$INSTALL_PATH')

try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    settings = {}

# Initialize hooks structure if not present
if 'hooks' not in settings:
    settings['hooks'] = {}

if 'Stop' not in settings['hooks']:
    settings['hooks']['Stop'] = []

# Check if worthit hook already exists
hook_exists = False
for hook_entry in settings['hooks']['Stop']:
    if isinstance(hook_entry, dict):
        hooks_list = hook_entry.get('hooks', [])
        for hook in hooks_list:
            if isinstance(hook, dict) and hook.get('command') == hook_path:
                hook_exists = True
                break

# Add hook if it doesn't exist
if not hook_exists:
    settings['hooks']['Stop'].append({
        'matcher': '*',
        'hooks': [{'type': 'command', 'command': hook_path}]
    })
    print('Hook added to settings')
else:
    print('Hook already exists in settings')

# Save updated settings
with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)

sys.exit(0)
EOF

    if [ $? -eq 0 ]; then
        print_info "Settings updated successfully"
    else
        print_error "Failed to update settings"
        print_warn "Restoring backup..."
        mv "${SETTINGS_FILE}.backup" "$SETTINGS_FILE"
        exit 1
    fi
}

# Platform-specific requirements
print_requirements() {
    local platform=$1

    echo ""
    print_info "Installation complete!"
    echo ""
    echo "Platform-specific requirements:"
    echo ""

    case "$platform" in
        windows)
            echo "  - WSL2 with Windows 10/11"
            echo "  - PowerShell (should be available by default)"
            echo ""
            echo "Optional: Install BurntToast for better notifications"
            echo "  Run in PowerShell: Install-Module -Name BurntToast"
            ;;
        macos)
            echo "  - macOS 10.10 or later"
            echo "  - Terminal app with notification permissions"
            echo ""
            echo "Make sure Terminal has notification permissions:"
            echo "  System Preferences > Notifications > Terminal"
            ;;
        linux)
            echo "  - Desktop environment with notification support"
            echo "  - libnotify (notify-send) - usually pre-installed"
            echo ""
            echo "If notify-send is not available, install it:"
            echo "  Ubuntu/Debian: sudo apt-get install libnotify-bin"
            echo "  Fedora: sudo dnf install libnotify"
            echo "  Arch: sudo pacman -S libnotify"
            ;;
    esac

    echo ""
    print_info "Usage: Run any Claude CLI command and see usage notifications!"
    echo ""
}

# Main installation flow
main() {
    echo "================================================"
    echo "  Worthit - Claude Usage Cost Notifier"
    echo "================================================"
    echo ""

    # Check dependencies
    check_python3
    check_curl
    check_claude

    # Detect platform
    PLATFORM=$(detect_platform)

    if [ "$PLATFORM" = "unknown" ]; then
        print_error "Unsupported platform: $(uname -s)"
        print_error "Supported platforms: Linux, macOS, Windows/WSL"
        exit 1
    fi

    # Install
    create_directories
    download_script "$PLATFORM"
    update_settings
    print_requirements "$PLATFORM"

    echo "================================================"
}

# Run main installation
main
