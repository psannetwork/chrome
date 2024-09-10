#!/bin/bash

# 関数: エラーメッセージを表示して終了
function error_exit {
    echo "$1" >&2
    exit 1
}

# Chroot環境のディレクトリを設定
CHROOT_DIR="/srv/chroot/ubuntu-focal-arm64"
ALTERNATE_CHROOT_DIR="/usr/local/ubuntu-focal-arm64"

# RootfsのURLを設定（ARM64とx86_64のURLを自動で選択する）
function get_rootfs_url {
    if [ "$(uname -m)" = "x86_64" ]; then
        echo "http://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.1-base-amd64.tar.gz"
    elif [ "$(uname -m)" = "aarch64" ]; then
        echo "http://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.1-base-arm64.tar.gz"
    else
        error_exit "Unsupported architecture: $(uname -m)"
    fi
}

# ディスク容量をチェックする関数
function check_disk_space {
    local dir=$1
    local required_space_mb=$2
    local available_space_mb=$(df "$dir" | awk 'NR==2 {print $4}')

    # MB単位に変換
    available_space_mb=$((available_space_mb / 1024))

    if [ "$available_space_mb" -lt "$required_space_mb" ]; then
        echo "Insufficient disk space in $dir. Required: ${required_space_mb}MB, Available: ${available_space_mb}MB."
        return 1
    fi
    return 0
}

# Rootfsをダウンロードして展開する
function setup_chroot {
    echo "Setting up chroot environment..."

    # RootfsのURLを取得
    ROOTFS_URL=$(get_rootfs_url)

    # ディスク容量をチェック（例えば2GB必要）
    if ! check_disk_space "$CHROOT_DIR" 2048; then
        echo "Switching to alternate directory due to insufficient space."
        CHROOT_DIR="$ALTERNATE_CHROOT_DIR"
    fi

    # Chrootディレクトリが存在する場合は削除
    if [ -d "$CHROOT_DIR" ]; then
        echo "Chroot directory exists. Checking if it is broken..."
        # 簡単なチェックとして、/bin/bash が存在するか確認
        if [ ! -x "$CHROOT_DIR/bin/bash" ]; then
            echo "Chroot directory appears to be broken. Removing it."
            sudo rm -rf "$CHROOT_DIR"
        else
            echo "Chroot directory is intact. Skipping setup."
            return
        fi
    fi

    # Rootfsをダウンロードして展開
    echo "Downloading and extracting root filesystem..."
    sudo mkdir -p "$CHROOT_DIR"
    curl -L "$ROOTFS_URL" | sudo tar -xz -C "$CHROOT_DIR" || error_exit "Failed to download or extract root filesystem."

    # 必要なファイルシステムのマウント
    sudo mount --bind /dev "$CHROOT_DIR/dev" || error_exit "Failed to mount /dev."
    sudo mount --bind /proc "$CHROOT_DIR/proc" || error_exit "Failed to mount /proc."
    sudo mount --bind /sys "$CHROOT_DIR/sys" || error_exit "Failed to mount /sys."
    sudo cp /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf" || error_exit "Failed to copy resolv.conf."

    # Chroot内での初期設定
    echo "Setting up chroot environment..."
    sudo chroot "$CHROOT_DIR" /bin/bash <<EOF
apt-get update
apt-get install -y sudo
EOF
}

# Chroot環境内でユーザーを追加
function add_user {
    echo "Adding user 'psan' to chroot environment..."

    sudo chroot "$CHROOT_DIR" /bin/bash <<EOF
# ユーザーの追加
useradd -m -s /bin/bash psan

# パスワードの設定
echo "psan:psan" | chpasswd

# sudoの設定
echo "psan ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
EOF
}

# 自動ログインを設定（systemd なし）
function configure_auto_login {
    echo "Configuring auto-login for user 'psan'..."

    sudo mkdir -p "$CHROOT_DIR/etc/init.d"
    sudo bash -c "cat > $CHROOT_DIR/etc/init.d/auto-login.sh" <<EOF
#!/bin/bash
# スクリプト: 自動ログインを設定
if [ ! -x /bin/login ]; then
    echo "/bin/login not found in chroot. Please check the root filesystem setup." >&2
    exit 1
fi

# /etc/inittab に自動ログインの設定を追加
echo "1:2345:respawn:/sbin/agetty --autologin psan --noclear tty1" >> /etc/inittab
EOF

    sudo chmod +x "$CHROOT_DIR/etc/init.d/auto-login.sh"

    # Chroot環境内で自動ログインスクリプトを実行
    sudo chroot "$CHROOT_DIR" /etc/init.d/auto-login.sh || error_exit "Failed to run auto-login script inside chroot."
}

# Chroot環境に入る
function enter_chroot {
    echo "Entering chroot environment at $CHROOT_DIR..."
    
    # 必要なファイルシステムをマウントしてからシェルを実行
    sudo mount --bind /dev "$CHROOT_DIR/dev" || error_exit "Failed to mount /dev."
    sudo mount --bind /proc "$CHROOT_DIR/proc" || error_exit "Failed to mount /proc."
    sudo mount --bind /sys "$CHROOT_DIR/sys" || error_exit "Failed to mount /sys."

    # Chroot内でシェルを実行し、自動でloginコマンドを起動
    sudo chroot "$CHROOT_DIR" /bin/bash -c 'login' || error_exit "Failed to enter chroot environment."

    # Chrootから出た後の後処理
    echo "Cleaning up..."
    sudo umount "$CHROOT_DIR/dev" || echo "Failed to unmount /dev."
    sudo umount "$CHROOT_DIR/proc" || echo "Failed to unmount /proc."
    sudo umount "$CHROOT_DIR/sys" || echo "Failed to unmount /sys."
}

# Main
if [ -d "$CHROOT_DIR" ] && [ -x "$CHROOT_DIR/bin/bash" ]; then
    echo "Chroot directory exists and is intact. Skipping setup."
else
    setup_chroot
fi

add_user
configure_auto_login
enter_chroot
