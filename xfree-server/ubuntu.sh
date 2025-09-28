#!/bin/bash
set -euo pipefail

# ------------------------------
# 変数定義
# ------------------------------
UBUNTU_ROOT="ubuntu-root"
UBUNTU_TARBALL="focal-base-amd64.tar.gz"
UBUNTU_URL="https://cdimage.ubuntu.com/ubuntu-base/focal/daily/20250925/${UBUNTU_TARBALL}"
PROOT_BIN="./proot"
PROOT_URL="https://proot.gitlab.io/proot/bin/proot"

# ------------------------------
# ファイルダウンロード関数
# ------------------------------
download_file() {
    local url=$1
    local output=$2
    local retries=3
    local count=0
    while [ $count -lt $retries ]; do
        if command -v wget > /dev/null 2>&1; then
            echo "Downloading ${output} using wget..."
            wget -O "${output}" "${url}" && return 0
        elif command -v curl > /dev/null 2>&1; then
            echo "Downloading ${output} using curl..."
            curl -L -o "${output}" "${url}" && return 0
        else
            echo "Error: Neither wget nor curl is installed."
            exit 1
        fi
        count=$((count+1))
        echo "Download failed. Retrying ($count/3)..."
        sleep 2
    done
    echo "Failed to download ${output} after 3 attempts."
    exit 1
}

# ------------------------------
# proot バイナリ確認・ダウンロード
# ------------------------------
if [ ! -x "${PROOT_BIN}" ]; then
    echo "proot binary not found. Downloading..."
    download_file "${PROOT_URL}" "${PROOT_BIN}"
    chmod +x "${PROOT_BIN}"
    echo "proot downloaded and made executable."
fi

# ------------------------------
# Ubuntu 環境作成
# ------------------------------
if [ -d "${UBUNTU_ROOT}" ]; then
    echo "Ubuntu environment exists. Skipping creation."
else
    echo "Ubuntu environment not found. Creating..."
    [ -f "${UBUNTU_TARBALL}" ] || download_file "${UBUNTU_URL}" "${UBUNTU_TARBALL}"

    mkdir -p "${UBUNTU_ROOT}"
    echo "Extracting ${UBUNTU_TARBALL}..."
    tar -xzf "${UBUNTU_TARBALL}" -C "${UBUNTU_ROOT}"

    echo "Setting DNS to 8.8.8.8..."
    echo "nameserver 8.8.8.8" > "${UBUNTU_ROOT}/etc/resolv.conf"
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
