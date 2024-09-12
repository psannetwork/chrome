#!/bin/bash

set -e  

echo "Checking for required packages..."

REQUIRED_PACKAGES="curl bash"

for pkg in $REQUIRED_PACKAGES; do
    if ! command -v $pkg &> /dev/null; then
        echo "$pkg not found. Installing..."
        sudo apt-get update
        sudo apt-get install -y $pkg
    else
        echo "$pkg is already installed."
    fi
done

echo "Starting Node.js setup..."

echo "Installing nvm..."
if ! curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash; then
    echo "Error: Failed to download or install nvm."
    exit 1
fi

echo "Reloading shell configuration..."
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    \. "$NVM_DIR/nvm.sh"
else
    echo "Error: nvm installation script was not found."
    exit 1
fi

echo "Installing the latest version of Node.js..."
if ! nvm install node; then
    echo "Error: Failed to install Node.js."
    exit 1
fi

echo "Verifying installation..."
if ! node -v; then
    echo "Error: Node.js installation verification failed."
    exit 1
fi

if ! npm -v; then
    echo "Error: npm installation verification failed."
    exit 1
fi
source ~/.bashrc
npm install -g npm
npm install -g pm2

echo "Node.js setup completed successfully."
