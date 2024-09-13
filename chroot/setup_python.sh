#!/bin/bash

set -e  # エラーが発生した場合にスクリプトを停止する

# 必要なパッケージのチェックとインストール
echo "Checking for required packages..."

# 必要なパッケージのリスト
REQUIRED_PACKAGES="curl wget build-essential"

for pkg in $REQUIRED_PACKAGES; do
    if ! command -v $pkg &> /dev/null; then
        echo "$pkg not found. Installing..."
        sudo apt-get update
        sudo apt-get install -y $pkg
    else
        echo "$pkg is already installed."
    fi
done

# Python3 と pip3 のインストール
echo "Installing Python and pip..."
if ! command -v python3 &> /dev/null; then
    echo "Python3 not found. Installing..."
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip
else
    echo "Python3 is already installed."
fi

# virtualenv のインストール
echo "Installing virtualenv..."
if ! pip3 show virtualenv &> /dev/null; then
    sudo pip3 install virtualenv
else
    echo "virtualenv is already installed."
fi

# Python と pip のバージョン確認
echo "Verifying Python installation..."
python3 --version
pip3 --version

# 仮想環境の作成と確認
echo "Setting up a virtual environment..."
VENV_DIR="$HOME/myenv"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv $VENV_DIR
    echo "Virtual environment created at $VENV_DIR"
else
    echo "Virtual environment already exists at $VENV_DIR"
fi

# 仮想環境のアクティベート
echo "Activating virtual environment..."
source $VENV_DIR/bin/activate

# 仮想環境内での Python バージョン確認
echo "Python version inside virtual environment:"
python --version

# スクリプトの終了メッセージ
echo "Python setup completed successfully."
