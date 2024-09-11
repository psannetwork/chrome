#!/bin/bash

set -e  # エラーが発生した場合にスクリプトを停止する

# スクリプトの開始メッセージ
echo "Starting Node.js setup..."

# nvmのインストール
echo "Installing nvm..."
if ! curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash; then
    echo "Error: Failed to download or install nvm."
    exit 1
fi

# シェル設定ファイルの再読み込み
echo "Reloading shell configuration..."
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    \. "$NVM_DIR/nvm.sh"
else
    echo "Error: nvm installation script was not found."
    exit 1
fi

# Node.jsのインストール
echo "Installing the latest version of Node.js..."
if ! nvm install node; then
    echo "Error: Failed to install Node.js."
    exit 1
fi

# インストール確認
echo "Verifying installation..."
if ! node -v; then
    echo "Error: Node.js installation verification failed."
    exit 1
fi

if ! npm -v; then
    echo "Error: npm installation verification failed."
    exit 1
fi

# スクリプトの終了メッセージ
echo "Node.js setup completed successfully."
