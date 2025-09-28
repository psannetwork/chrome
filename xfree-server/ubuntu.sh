#!/bin/bash
set -euo pipefail

# ------------------------------
# 変数定義
# ------------------------------
UBUNTU_ROOT="ubuntu-root"
UBUNTU_TARBALL="focal-base-amd64.tar.gz"
UBUNTU_URL="https://cdimage.ubuntu.com/ubuntu-base/focal/daily/20250411/${UBUNTU_TARBALL}"
PROOT_BIN="./proot"

# ------------------------------
# ファイルダウンロード関数
# ------------------------------
download_file() {
    local retries=3
    local count=0
    while [ $count -lt $retries ]; do
        if command -v wget > /dev/null 2>&1; then
            echo "Downloading ${UBUNTU_TARBALL} using wget..."
            wget -O "${UBUNTU_TARBALL}" "${UBUNTU_URL}" && return 0
        elif command -v curl > /dev/null 2>&1; then
            echo "Downloading ${UBUNTU_TARBALL} using curl..."
            curl -L -o "${UBUNTU_TARBALL}" "${UBUNTU_URL}" && return 0
        else
            echo "Error: Neither wget nor curl is installed."
            exit 1
        fi
        count=$((count+1))
        echo "Download failed. Retrying ($count/$retries)..."
        sleep 2
    done
    echo "Failed to download ${UBUNTU_TARBALL} after ${retries} attempts."
    exit 1
}

# ------------------------------
# Ubuntu 環境作成
# ------------------------------
if [ -d "${UBUNTU_ROOT}" ]; then
    echo "Ubuntu environment exists. Skipping creation."
else
    echo "Ubuntu environment not found. Creating..."

    [ -f "${UBUNTU_TARBALL}" ] || download_file

    mkdir -p "${UBUNTU_ROOT}"
    echo "Extracting ${UBUNTU_TARBALL}..."
    if ! tar -xzf "${UBUNTU_TARBALL}" -C "${UBUNTU_ROOT}"; then
        echo "Error: Failed to extract ${UBUNTU_TARBALL}."
        exit 1
    fi

    # DNS 設定
    echo "Setting DNS to 8.8.8.8..."
    if ! echo "nameserver 8.8.8.8" > "${UBUNTU_ROOT}/etc/resolv.conf"; then
        echo "Error: Failed to set DNS."
        exit 1
    fi
fi

# ------------------------------
# ユーザー作成（存在する場合はスキップ）
# ------------------------------
if ! grep -q "1000:" "${UBUNTU_ROOT}/etc/passwd"; then
    echo "Creating new user in Ubuntu..."
    read -p "Enter username: " UBUNTU_USER
    read -s -p "Enter password: " UBUNTU_PASS
    echo

    mkdir -p "${UBUNTU_ROOT}/home/${UBUNTU_USER}"

    HASHED_PASS=$(openssl passwd -6 <<<"${UBUNTU_PASS}")

    cat <<EOF >> "${UBUNTU_ROOT}/etc/passwd"
${UBUNTU_USER}:x:1000:1000::/home/${UBUNTU_USER}:/bin/bash
EOF

    cat <<EOF >> "${UBUNTU_ROOT}/etc/shadow"
${UBUNTU_USER}:${HASHED_PASS}:0:0:99999:7:::
EOF

    echo "${UBUNTU_USER} ALL=(ALL) NOPASSWD: ALL" >> "${UBUNTU_ROOT}/etc/sudoers"

    echo "User ${UBUNTU_USER} created successfully!"
else
    echo "User already exists. Skipping creation."
fi

# ------------------------------
# proot 実行前チェック
# ------------------------------
if [ ! -x "${PROOT_BIN}" ]; then
    echo "Error: proot binary not found or not executable at ${PROOT_BIN}."
    exit 1
fi

# ------------------------------
# Ubuntu 環境起動
# ------------------------------
echo "Starting Ubuntu environment using proot..."
exec "${PROOT_BIN}" -0 \
    --rootfs="${UBUNTU_ROOT}" \
    -w / \
    -b /proc:/proc \
    -b /sys:/sys \
    -b /dev:/dev \
    env PATH=/bin:/usr/bin:/sbin:/usr/sbin /bin/bash
