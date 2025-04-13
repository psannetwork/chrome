set -e

# Define variables
UBUNTU_ROOT="ubuntu-root"
UBUNTU_TARBALL="focal-base-amd64.tar.gz"
UBUNTU_URL="https://cdimage.ubuntu.com/ubuntu-base/focal/daily/20250411/${UBUNTU_TARBALL}"
# Function to download a file using wget or curl
download_file() {
    if command -v wget > /dev/null 2>&1; then
        echo "Using wget to download ${UBUNTU_TARBALL}..."
        wget "${UBUNTU_URL}" -O "${UBUNTU_TARBALL}"
    elif command -v curl > /dev/null 2>&1; then
        echo "wget not found, using curl to download ${UBUNTU_TARBALL}..."
        curl -L "${UBUNTU_URL}" -o "${UBUNTU_TARBALL}"
    else
        echo "Error: Neither wget nor curl is installed. Please install one and try again."
        exit 1
    fi
}

# Check if the Ubuntu environment directory exists
if [ -d "${UBUNTU_ROOT}" ]; then
    echo "Ubuntu environment exists. Entering the environment..."
else
    echo "Ubuntu environment not found. Creating it now..."

    # Download the Ubuntu tarball if it hasn't been downloaded
    if [ ! -f "${UBUNTU_TARBALL}" ]; then
        download_file
    else
        echo "${UBUNTU_TARBALL} already exists. Skipping download."
    fi

    # Create the Ubuntu root directory and extract the tarball
    mkdir -p "${UBUNTU_ROOT}"
    echo "Extracting ${UBUNTU_TARBALL} into ${UBUNTU_ROOT}..."
    tar -xzf "${UBUNTU_TARBALL}" -C "${UBUNTU_ROOT}"

    # Configure DNS
    echo "Setting up DNS to 8.8.8.8..."
    echo "nameserver 8.8.8.8" > "${UBUNTU_ROOT}/etc/resolv.conf"
fi

# Check if a user is set up
if [ ! -f "${UBUNTU_ROOT}/etc/passwd" ] || ! grep -q "^[^:]*:[^:]*:[0-9]\+:" "${UBUNTU_ROOT}/etc/passwd"; then
    echo "No user found in Ubuntu. Creating a new user..."
    read -p "Enter username: " UBUNTU_USER
    read -s -p "Enter password: " UBUNTU_PASS
    echo

    # Create user in chroot environment
    mkdir -p "${UBUNTU_ROOT}/home/${UBUNTU_USER}"
    echo "${UBUNTU_USER}:$(echo "${UBUNTU_PASS}" | openssl passwd -6 -stdin):1000:1000:User,,,:/home/${UBUNTU_USER}:/bin/bash" >> "${UBUNTU_ROOT}/etc/passwd"
    echo "${UBUNTU_USER}:x:1000:1000::/home/${UBUNTU_USER}:/bin/bash" >> "${UBUNTU_ROOT}/etc/passwd"
    echo "${UBUNTU_USER}:!:19117:0:99999:7:::" >> "${UBUNTU_ROOT}/etc/shadow"
    echo "${UBUNTU_USER} ALL=(ALL) NOPASSWD: ALL" >> "${UBUNTU_ROOT}/etc/sudoers"

    echo "User ${UBUNTU_USER} created successfully!"
fi

# Start the Ubuntu environment using proot
echo "Starting Ubuntu environment using proot..."
./proot -0 --rootfs="${UBUNTU_ROOT}" -w / -b /proc:/proc -b /sys:/sys -b /dev:/dev env PATH=/bin:/usr/bin:/sbin:/usr/sbin /bin/bash
