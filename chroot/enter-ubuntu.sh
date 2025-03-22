#!/bin/bash
clear
function error_exit {
    echo "$1" >&2
    exit 1
}

CHROOT_DIR="/usr/local/ubuntu-focal-arm64"
if [ ! -d "$CHROOT_DIR" ]; then
    echo "Directory $CHROOT_DIR does not exist. Creating it..."
    sudo mkdir -p "$CHROOT_DIR" || { echo "Failed to create directory $CHROOT_DIR"; exit 1; }
    echo "Directory $CHROOT_DIR created successfully."
else
    echo "Directory $CHROOT_DIR already exists. No action taken."
fi

function get_rootfs_url {
    if [ "$(uname -m)" = "x86_64" ]; then
        echo "http://cdimage.ubuntu.com/ubuntu-base/focal/daily/20250322/focal-base-amd64.tar.gz"
    elif [ "$(uname -m)" = "aarch64" ]; then
        echo "http://cdimage.ubuntu.com/ubuntu-base/focal/daily/20250322/focal-base-arm64.tar.gz"
    else
        error_exit "Unsupported architecture: $(uname -m)"
    fi
}

function check_disk_space {
    local dir=$1
    local required_space_mb=$2
    local available_space_mb=$(df "$dir" | awk 'NR==2 {print $4}')

    available_space_mb=$((available_space_mb / 1024))

    if [ "$available_space_mb" -lt "$required_space_mb" ]; then
        echo "Insufficient disk space in $dir. Required: ${required_space_mb}MB, Available: ${available_space_mb}MB."
        return 1
    fi
    return 0
}

function setup_chroot {
    echo "Setting up chroot environment..."

    ROOTFS_URL=$(get_rootfs_url)

    if ! check_disk_space "$CHROOT_DIR" 2048; then
        error_exit "Insufficient disk space in $CHROOT_DIR."
    fi

    if [ -d "$CHROOT_DIR" ]; then
        echo "Chroot directory exists. Checking if it is broken..."
        if [ ! -x "$CHROOT_DIR/bin/bash" ]; then
            echo "Chroot directory appears to be broken. Removing it."
            sudo rm -rf "$CHROOT_DIR"
        else
            echo "Chroot directory is intact. Skipping setup."
            return
        fi
    fi

    echo "Downloading and extracting root filesystem..."
    sudo mkdir -p "$CHROOT_DIR"
    curl -L "$ROOTFS_URL" | sudo tar -xz -C "$CHROOT_DIR" || error_exit "Failed to download or extract root filesystem."

    sudo mount --bind /dev "$CHROOT_DIR/dev" || error_exit "Failed to mount /dev."
    sudo mount --bind /proc "$CHROOT_DIR/proc" || error_exit "Failed to mount /proc."
    sudo mount --bind /sys "$CHROOT_DIR/sys" || error_exit "Failed to mount /sys."
    sudo cp /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf" || error_exit "Failed to copy resolv.conf."

    echo "Setting up chroot environment..."
    sudo chroot "$CHROOT_DIR" /bin/bash <<EOF
apt-get update
apt-get install -y sudo curl
curl -Ls https://raw.githubusercontent.com/hirotomoki12345/chrome/main/chroot/setup_nodejs.sh -o setup_nodejs.sh
curl -Ls https://raw.githubusercontent.com/hirotomoki12345/chrome/main/chroot/setup_packages.sh -o setup_packages.sh
sudo bash setup_nodejs.sh
sudo bash setup_packages.sh
EOF
}

function add_user {
    echo "Adding user 'psan' to chroot environment..."

    sudo chroot "$CHROOT_DIR" /bin/bash <<EOF
useradd -m -s /bin/bash psan

echo "psan:psan" | chpasswd

echo "psan ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
EOF
}

function configure_auto_login {
    echo "Configuring auto-login for user 'psan'..."

    sudo mkdir -p "$CHROOT_DIR/etc/init.d"
    sudo bash -c "cat > $CHROOT_DIR/etc/init.d/auto-login.sh" <<EOF
#!/bin/bash
if [ ! -x /bin/login ]; then
    echo "/bin/login not found in chroot. Please check the root filesystem setup." >&2
    exit 1
fi

echo "1:2345:respawn:/sbin/agetty --autologin psan --noclear tty1" >> /etc/inittab
EOF

    sudo chmod +x "$CHROOT_DIR/etc/init.d/auto-login.sh"

    sudo chroot "$CHROOT_DIR" /etc/init.d/auto-login.sh || error_exit "Failed to run auto-login script inside chroot."
}
function set_cmds {
curl -Ls https://raw.githubusercontent.com/hirotomoki12345/chrome/main/chroot/set -o setup
mv setup $CHROOT_DIR/usr/local/bin
}
function enter_chroot {
    echo "Entering chroot environment at $CHROOT_DIR..."
    
    sudo mount --bind /dev "$CHROOT_DIR/dev" || error_exit "Failed to mount /dev."
    sudo mount --bind /proc "$CHROOT_DIR/proc" || error_exit "Failed to mount /proc."
    sudo mount --bind /sys "$CHROOT_DIR/sys" || error_exit "Failed to mount /sys."

    sudo chroot "$CHROOT_DIR" /bin/bash -c 'login' || error_exit "Failed to enter chroot environment."

    echo "Cleaning up..."
    sudo umount "$CHROOT_DIR/dev" || echo "Failed to unmount /dev."
    sudo umount "$CHROOT_DIR/proc" || echo "Failed to unmount /proc."
    sudo umount "$CHROOT_DIR/sys" || echo "Failed to unmount /sys."
}

if [ -d "$CHROOT_DIR" ] && [ -x "$CHROOT_DIR/bin/bash" ]; then
    echo "Chroot directory exists and is intact. Skipping setup."
else
    setup_chroot
fi

add_user
configure_auto_login
enter_chroot
