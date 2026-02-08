#!/bin/bash
set -e

echo "Starting dependency installation..."

# 1. Install Homebrew
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing..."
    # Run as user 'umesh' since we are in a root shell via osascript
    if [ "$(id -u)" -eq 0 ]; then
        echo "Running as root, dropping privileges to umesh..."
        # Change ownership of the script to umesh so we can read it? actually we just run commands
        sudo -u umesh /bin/bash -c "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    else
        /bin/bash -c "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    fi
    
    # Attempt to add to path for current session (Apple Silicon default)
    if [ -f "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "Homebrew is already installed."
fi

# 2. Install Flutter
if ! command -v flutter &> /dev/null; then
    echo "Flutter not found. Installing via Homebrew..."
    if [ "$(id -u)" -eq 0 ]; then
        # We need the full path to brew if it wasn't added to PATH for root
        # Try common paths
        BREW_CMD="/opt/homebrew/bin/brew"
        if [ ! -f "$BREW_CMD" ]; then BREW_CMD="/usr/local/bin/brew"; fi
        
        sudo -u umesh "$BREW_CMD" install --cask flutter
    else
        brew install --cask flutter
    fi
else
    echo "Flutter is already installed."
fi

echo " Installation complete!"
echo "Please restart your terminal or run 'source ~/.zshrc' to ensure Flutter is in your PATH."
