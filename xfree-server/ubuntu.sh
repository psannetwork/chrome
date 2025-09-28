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
    echo "Downloading ${output}..."
    if command -v wget > /dev/null 2>&1; then
        wget -c -O "${output}" "${url}"
    elif command -v curl > /dev/null 2>&1; then
        curl -C - -L -o "${output}" "${url}"
    else
        echo "Error: Neither wget nor curl is installed."
        exit 1
    fi

    # ダウンロードが壊れていないか確認
    if ! gzip -t "${output}" >/dev/null 2>&1; then
        echo "Error: Downloaded file ${output} is corrupted. Please try again."
        exit 1
    fi
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
    if ! tar -xzf "${UBUNTU_TARBALL}" -C "${UBUNTU_ROOT}"; then
        echo "Error: Failed to extract ${UBUNTU_TARBALL}."
        exit 1
    fi

    echo "Setting DNS to 8.8.8.8..."
    echo "nameserver 8.8.8.8" > "${UBUNTU_ROOT}/etc/resolv.conf"
fi

# ------------------------------
# ユーザー作成（存在する場合はスキップ）
# ------------------------------
if ! grep -q "1000:" "${UBUNTU_ROOT}/etc/passwd"; then
    echo "Creating new user in Ubuntu..."
    read -p "Enter username: " UBUNTU_USER

    mkdir -p "${UBUNTU_ROOT}/home/${UBUNTU_USER}"

    # shadow のパスワードは無効化（後で proot 内で passwd で設定）
    cat <<EOF >> "${UBUNTU_ROOT}/etc/passwd"
${UBUNTU_USER}:x:1000:1000::/home/${UBUNTU_USER}:/bin/bash
EOF

    cat <<EOF >> "${UBUNTU_ROOT}/etc/shadow"
${UBUNTU_USER}:*:0:0:99999:7:::
EOF

    echo "${UBUNTU_USER} ALL=(ALL) NOPASSWD: ALL" >> "${UBUNTU_ROOT}/etc/sudoers"

    echo "User ${UBUNTU_USER} created successfully!"
    echo "Note: Password is disabled. Please run 'passwd ${UBUNTU_USER}' inside Ubuntu to set a password."
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
